#!/usr/bin/perl
#
# seeds.pl - Set up development database with usable test data
#
# This script is run after the SQLite import to set passwords and
# other development-specific settings.
#
# Usage: perl seeds.pl [--database=perlmonks] [--user=root] [--host=localhost]
#

use strict;
use warnings;
use DBI;
use Getopt::Long;

my $database = "perlmonks";
my $db_user = "root";
my $db_pass = "";
my $db_host = "localhost";
my $db_port = 3306;

# Development password for all seeded users
my $dev_password = "blah";

GetOptions(
    "database=s" => \$database,
    "user=s"     => \$db_user,
    "password=s" => \$db_pass,
    "host=s"     => \$db_host,
    "port=i"     => \$db_port,
);

print "PerlMonks Development Database Seeding\n";
print "======================================\n";

my $dbh = DBI->connect(
    "DBI:mysql:database=$database;host=$db_host;port=$db_port",
    $db_user, $db_pass,
    { RaiseError => 1, PrintError => 0, mysql_enable_utf8mb4 => 1 }
) or die "Cannot connect to database: $DBI::errstr\n";

#
# Set passwords for key users
# The passwd field stores plaintext passwords in PerlMonks
#
my @users_to_seed = (
    # node_id, username, description
    [113, 'root', 'Super admin'],
    [112, 'qauser', 'QA test user'],
    [979, 'vroom', 'Original PM creator'],
);

print "\nSetting passwords (password: '$dev_password')...\n";

my $update_sth = $dbh->prepare(
    "UPDATE user SET passwd = ? WHERE user_id = ?"
);

for my $user (@users_to_seed) {
    my ($user_id, $nick, $desc) = @$user;

    # Verify user exists
    my ($exists) = $dbh->selectrow_array(
        "SELECT nick FROM user WHERE user_id = ?",
        {}, $user_id
    );

    if ($exists) {
        $update_sth->execute($dev_password, $user_id);
        print "  [$user_id] $nick ($desc) - password set\n";
    } else {
        print "  [$user_id] $nick - NOT FOUND, skipping\n";
    }
}

#
# Verify guest_user setting exists
#
print "\nChecking system settings...\n";

my ($guest_user) = $dbh->selectrow_array(
    "SELECT node_id FROM node WHERE title = 'Guest User' AND type_nodetype = 15"
);

if ($guest_user) {
    print "  Guest User node_id: $guest_user\n";
} else {
    print "  WARNING: Guest User not found\n";
}

#
# Show user counts
#
my ($user_count) = $dbh->selectrow_array(
    "SELECT COUNT(*) FROM user"
);
my ($node_count) = $dbh->selectrow_array(
    "SELECT COUNT(*) FROM node"
);

print "\nDatabase stats:\n";
print "  Users: $user_count\n";
print "  Nodes: $node_count\n";

print "\n======================================\n";
print "Seeding complete!\n";
print "\nYou can now login with:\n";
print "  Username: root\n";
print "  Password: $dev_password\n";
print "======================================\n";

$dbh->disconnect();
