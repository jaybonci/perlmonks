package DBIx::MySQLite;
use 5.006;
use strict;
use warnings;
use DBD::SQLite;

use POSIX qw (strftime);
use Time::Local;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw(
	add_all_functions
	add_string_functions
	add_datetime_functions
	add_regexp_functions
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(

);

our $VERSION = '0.1';

################################################################################

sub format_datetime {
	$_[0] =~ s{\%i}{\%M};
	return POSIX::strftime (@_);
}

################################################################################

sub parse_datetime {
	my ($s) = @_;
	$s =~ s{[^\d]}{}g;
	$s =~ /(\d\d\d\d)(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/
	    or die "Malformed timestamp $s";
	if ($2 == 0) {
		#print STDERR "Weird timestamp '$s' (" . __FILE__ . ")\n";
		return (1,0,0,1,1,70);
	};
	return ($6, $5, $4 , $3, $2 - 1, $1 - 1900);
}


################################################################################

sub add_all_functions {
	add_string_functions   (@_);
	add_datetime_functions (@_);
	add_regexp_functions   (@_);
};

################################################################################

sub add_string_functions {

	my $db = shift;

	$db -> func ('REPLACE', 3, sub {
		my ($s, $from, $to) = @_;
		$s =~ s{$from}{$to}g;
		return $s;
	}, 'create_function');

	$db -> func ('SUBSTRING', 3, sub {
		my ($s, $idx, $len) = @_;
		return substr $s, $idx, $len;
	}, 'create_function');

};

################################################################################

sub add_regexp_functions {

	my $db = shift;

	$db -> func ('REGEXP', 2, sub {
		my ($re,$str) = @_;
		return $str =~ m{$re};
	}, 'create_function');


};

################################################################################

use vars '%translate_strftime';
BEGIN {
    %translate_strftime = (
        'i' => '%S',
        'T' => '%H:%M:%S',
        '%' => '%',
    );
};

sub add_datetime_functions {

	my $db = shift;

	$db -> func ('NOW', 0, sub {
		return POSIX::strftime ('%Y-%m-%d %H:%M:%S', gmtime (time));
	}, 'create_function');

	$db -> func ('FROM_UNIXTIME', 1, sub {
		return POSIX::strftime ('%Y-%m-%d %H:%M:%S', gmtime($_[0]));
	}, 'create_function');

	$db -> func ('MYSQL_TIMESTAMP', 0, sub {
		return POSIX::strftime ('%Y%m%d%H%M%S', gmtime (time));
	}, 'create_function');

	$db -> func ('DATE_FORMAT', 2, sub {
	    my $fmt = $_[1];
	    $fmt =~ s/%(.)/exists $translate_strftime{$1} ? $translate_strftime{$1} : "%".$1/ge;
	    return format_datetime ($fmt, parse_datetime ($_[0]));
	}, 'create_function');

	$db -> func ('UNIX_TIMESTAMP', 1, sub {
	    my ($S,$M,$H,$d,$m,$y) = parse_datetime($_[0]);
	    #print STDERR "$_[0] => $S:$M:$H $d-$m-$y (" . __FILE__ . ")\n";
	    return timegm($S,$M,$H,$d,$m,$y+1900);
	}, 'create_function');

};

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

DBIx::MySQLite - MySQL compatibility functions for DBD::SQLite.

=head1 SYNOPSIS

  use DBI;
  use DBIx::MySQLite 'add_all_functions';

  my $db = DBI -> connect ("dbi:SQLite:dbname=sql.ite","","", {RaiseError => 1});

  DBIx::MySQLite::add_string_functions   ($db);
  DBIx::MySQLite::add_datetime_functions ($db);

  # or simply

  add_all_functions ($db);

  $db -> do ('UPDATE syslog SET dt = REPLACE(NOW(), '200', '175'...

=head1 ABSTRACT

  MySQL compatibility functions for DBD::SQLite.

=head1 DESCRIPTION

DBD::SQLite is a set of callback function definitions making it look more or less like MySQL. As of version 0.1, just a very basic set is available, patches are very welcome.

=over

=item NOW()

Current timestamp, in format 'YYYY-MM-DD hh:mm:ss'.

=item DATE_FORMAT()

Only %Y, %m, %d, %H, %i and %S patterns are guaranteed, other may work (see POSIX::strftime).

=item REPLACE()

=item SUBSTRING()

=back

=head1 SEE ALSO

DBD::SQLite.

=head1 AUTHOR

D. E. Ovsyanko, E<lt>do@eludia.ruE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2004 by D. E. Ovsyanko

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut