package Everything::Password;
#
# Everything::Password - Database connection shim for PerlMonks
#
# This module provides the connectDB() function expected by NodeBase.pm.
# In the original PerlMonks, this likely just held plain-text credentials.
# This version reads from JSON configuration for the dev environment.
#

use strict;
use warnings;
use DBI;

# Try to load JSON, fall back to simple parsing if not available
my $HAS_JSON = eval { require JSON; 1 };

sub connectDB {
    my ($dbname) = @_;

    # Get configuration
    my $config = _load_config();

    my $host = $config->{database}{host} || $ENV{PM_DBHOST} || 'localhost';
    my $port = $config->{database}{port} || $ENV{PM_DBPORT} || 3306;
    my $user = $config->{database}{user} || 'pmuser';
    my $pass = $config->{database}{password} || 'pmpass';

    # Note: NodeBase.pm maps 'perlmonks' -> 'perlmonk_ebase' (production name)
    # before calling this function. We override with our config name.
    my $name = $config->{database}{name} || 'perlmonks';

    my $dsn = "DBI:mysql:database=$name;host=$host;port=$port";

    my $dbh = DBI->connect($dsn, $user, $pass, {
        RaiseError => 1,
        PrintError => 0,
        AutoCommit => 1,
        mysql_enable_utf8mb4 => 1,
        mysql_auto_reconnect => 1,
        # For MySQL 8.0+ compatibility with caching_sha2_password
        mysql_get_server_pubkey => 1,
    });

    die "Could not connect to database: $DBI::errstr" unless $dbh;

    return $dbh;
}

sub _load_config {
    my $env = $ENV{PM_ENVIRONMENT} || 'development';
    my $config_file = "/var/everything/etc/$env.json";

    # Return defaults if config file doesn't exist
    unless (-f $config_file) {
        return {
            database => {
                host => $ENV{PM_DBHOST} || 'localhost',
                port => $ENV{PM_DBPORT} || 3306,
                user => 'pmuser',
                password => 'pmpass',
                name => 'perlmonks',
            }
        };
    }

    # Read config file
    open my $fh, '<', $config_file or do {
        warn "Cannot read config file $config_file: $!";
        return { database => {} };
    };

    my $content = do { local $/; <$fh> };
    close $fh;

    # Parse JSON
    if ($HAS_JSON) {
        return JSON::decode_json($content);
    } else {
        # Fallback: very basic JSON parsing for database config
        my $config = { database => {} };

        if ($content =~ /"host"\s*:\s*"([^"]+)"/) {
            $config->{database}{host} = $1;
        }
        if ($content =~ /"port"\s*:\s*(\d+)/) {
            $config->{database}{port} = $1;
        }
        if ($content =~ /"user"\s*:\s*"([^"]+)"/) {
            $config->{database}{user} = $1;
        }
        if ($content =~ /"password"\s*:\s*"([^"]*)"/) {
            $config->{database}{password} = $1;
        }
        if ($content =~ /"name"\s*:\s*"([^"]+)"/) {
            $config->{database}{name} = $1;
        }

        return $config;
    }
}

1;

__END__

=head1 NAME

Everything::Password - Database connection module for PerlMonks

=head1 SYNOPSIS

    use Everything::Password;
    my $dbh = Everything::Password::connectDB('perlmonks');

=head1 DESCRIPTION

This module provides the database connection function expected by
Everything::NodeBase. It reads configuration from JSON files or
environment variables.

=head1 CONFIGURATION

Configuration is read from /var/everything/etc/$PM_ENVIRONMENT.json

Environment variables:
  PM_ENVIRONMENT - development, production, etc. (default: development)
  PM_DBHOST - Database host (overrides config)
  PM_DBPORT - Database port (overrides config)

=cut
