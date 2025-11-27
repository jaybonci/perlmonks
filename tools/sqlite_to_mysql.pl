#!/usr/bin/perl
#
# sqlite_to_mysql.pl - Import PerlMonks SQLite dump into MySQL
#
# The SQLite dump is a converted MySQL dump, so:
# - Schema is already MySQL-compatible (minimal conversion needed)
# - node_ids are preserved - critical for hardcoded references
# - Data types map cleanly back to MySQL
#

use strict;
use warnings;
use DBI;
use Getopt::Long;

my $sqlite_file = "/var/everything/db/perlmonks.sqlite";
my $mysql_db = "perlmonks";
my $mysql_user = "root";
my $mysql_pass = "";
my $mysql_host = "localhost";
my $mysql_port = 3306;
my $verbose = 0;
my $dry_run = 0;

GetOptions(
    "sqlite=s"   => \$sqlite_file,
    "database=s" => \$mysql_db,
    "user=s"     => \$mysql_user,
    "password=s" => \$mysql_pass,
    "host=s"     => \$mysql_host,
    "port=i"     => \$mysql_port,
    "verbose"    => \$verbose,
    "dry-run"    => \$dry_run,
) or die "Usage: $0 [options]\n";

print "PerlMonks SQLite to MySQL Import\n";
print "================================\n";
print "SQLite: $sqlite_file\n";
print "MySQL:  $mysql_user\@$mysql_host:$mysql_port/$mysql_db\n";
print "\n";

# Connect to SQLite
print "Connecting to SQLite...\n";
my $sqlite = DBI->connect(
    "dbi:SQLite:dbname=$sqlite_file", "", "",
    {
        RaiseError => 1,
        PrintError => 0,
        sqlite_unicode => 1,
    }
) or die "Cannot connect to SQLite: $DBI::errstr\n";

# Connect to MySQL
print "Connecting to MySQL...\n";
my $mysql = DBI->connect(
    "DBI:mysql:database=$mysql_db;host=$mysql_host;port=$mysql_port",
    $mysql_user, $mysql_pass,
    {
        RaiseError => 1,
        PrintError => 0,
        mysql_enable_utf8mb4 => 1,
        mysql_auto_reconnect => 1,
    }
) or die "Cannot connect to MySQL: $DBI::errstr\n";

# Disable foreign key checks for import
$mysql->do("SET FOREIGN_KEY_CHECKS = 0");
$mysql->do("SET UNIQUE_CHECKS = 0");
$mysql->do("SET SESSION sql_mode = ''");

# Get list of tables from SQLite
my @tables = map { $_->[0] } @{$sqlite->selectall_arrayref(
    "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name"
)};

print "Found " . scalar(@tables) . " tables to import\n\n";

my $total_rows = 0;
my $start_time = time();

for my $table (@tables) {
    print "[$table] ";

    # Get CREATE TABLE from SQLite
    my ($sqlite_schema) = $sqlite->selectrow_array(
        "SELECT sql FROM sqlite_master WHERE type='table' AND name=?",
        {}, $table
    );

    unless ($sqlite_schema) {
        print "SKIP (no schema)\n";
        next;
    }

    # Convert schema to MySQL
    my $mysql_schema = convert_schema($sqlite_schema, $table);

    if ($dry_run) {
        print "DRY-RUN\n";
        print "  Schema: $mysql_schema\n" if $verbose;
        next;
    }

    # Create table in MySQL
    eval {
        $mysql->do("DROP TABLE IF EXISTS `$table`");
        $mysql->do($mysql_schema);
    };
    if ($@) {
        print "ERROR creating table: $@\n";
        print "  Schema was: $mysql_schema\n";
        next;
    }

    # Import data
    my $count = import_table_data($sqlite, $mysql, $table);
    $total_rows += $count;

    print "$count rows\n";
}

# Re-enable checks
$mysql->do("SET FOREIGN_KEY_CHECKS = 1");
$mysql->do("SET UNIQUE_CHECKS = 1");

my $elapsed = time() - $start_time;
print "\n";
print "================================\n";
print "Import complete!\n";
print "  Tables: " . scalar(@tables) . "\n";
print "  Rows:   $total_rows\n";
print "  Time:   ${elapsed}s\n";
print "================================\n";

$sqlite->disconnect();
$mysql->disconnect();

exit 0;

#
# Convert SQLite schema to MySQL
#
sub convert_schema {
    my ($sql, $table) = @_;

    # The SQLite dump is from MySQL, so schema is mostly compatible
    # Just need minor adjustments

    # Handle INTEGER PRIMARY KEY -> INT AUTO_INCREMENT
    # But be careful - SQLite uses INTEGER PRIMARY KEY for rowid alias
    $sql =~ s/`(\w+)`\s+INTEGER\s+PRIMARY\s+KEY\s+AUTOINCREMENT/`$1` INT NOT NULL AUTO_INCREMENT PRIMARY KEY/gi;
    $sql =~ s/`(\w+)`\s+INTEGER\s+PRIMARY\s+KEY(?!\s+AUTO)/`$1` INT NOT NULL PRIMARY KEY/gi;

    # INTEGER -> INT (but not INTEGER PRIMARY KEY which we handled above)
    $sql =~ s/\bINTEGER\b/INT/gi;

    # TEXT -> LONGTEXT for large content
    $sql =~ s/\bTEXT\b/LONGTEXT/gi;

    # BLOB -> LONGBLOB
    $sql =~ s/\bBLOB\b/LONGBLOB/gi;

    # Remove SQLite-specific syntax
    $sql =~ s/\s+AUTOINCREMENT//gi;  # MySQL uses AUTO_INCREMENT not AUTOINCREMENT
    $sql =~ s/\bIF NOT EXISTS\s+//gi;

    # Handle default values with quotes
    $sql =~ s/DEFAULT\s+''/DEFAULT ''/gi;

    # Add MySQL engine and charset if not present
    unless ($sql =~ /ENGINE\s*=/i) {
        $sql =~ s/\)\s*$/\) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci/;
    }

    return $sql;
}

#
# Import table data in batches
#
sub import_table_data {
    my ($sqlite, $mysql, $table) = @_;

    my $sth = $sqlite->prepare("SELECT * FROM `$table`");
    $sth->execute();

    my $columns = $sth->{NAME};
    return 0 unless $columns && @$columns;

    my $placeholders = join(",", ("?") x @$columns);
    my $col_list = join(",", map { "`$_`" } @$columns);
    my $insert_sql = "INSERT INTO `$table` ($col_list) VALUES ($placeholders)";

    my $insert_sth = $mysql->prepare($insert_sql);

    my $count = 0;
    my $batch_size = 1000;
    my $errors = 0;

    $mysql->begin_work;

    while (my $row = $sth->fetchrow_arrayref()) {
        eval {
            $insert_sth->execute(@$row);
        };
        if ($@) {
            $errors++;
            print STDERR "  Error inserting row in $table: $@\n" if $verbose;
        }
        $count++;

        if ($count % $batch_size == 0) {
            $mysql->commit;
            $mysql->begin_work;
            print "." if $count % 10000 == 0;
        }
    }

    $mysql->commit;

    print " ($errors errors)" if $errors > 0;
    return $count;
}
