# cpanfile for PerlMonks
#
# This file defines Perl dependencies for the PerlMonks development environment.
# Dependencies will be installed via cpanm in the Docker build.
#
# Unlike E2, we don't have a pre-built vendor cache, so dependencies are
# installed directly from CPAN and cached in Docker layers.
#

# Core database connectivity
requires 'DBI', '>= 1.643';
requires 'DBD::mysql', '>= 4.050';

# JSON configuration parsing
requires 'JSON', '>= 4.0';

# Utility modules used in ecore
requires 'Data::Dumper';
requires 'Digest::MD5';
requires 'MIME::Base64';
requires 'Time::HiRes';
requires 'POSIX';
requires 'Storable';

# CGI and web handling
requires 'CGI';
requires 'CGI::Carp';

# HTML handling
requires 'HTML::Entities';
requires 'URI::Escape';

# For import tool only (in Docker DB container)
# requires 'DBD::SQLite';  # Installed via apt in pmdb container
