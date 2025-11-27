#!/usr/bin/perl
package Everything::AccessLog;
use strict;

use Everything::HTML;

use POSIX qw(strftime);
use vars qw(@columns $logfilename $hostname);
BEGIN {
    @columns = qw( tsin ttaken token url user node type ip code server referrer ua );
    $hostname = `hostname`;
    $hostname =~ s/[^a-z0-9.]//g;
    $logfilename = "/tmp/pm-access-$hostname.log";
};

sub log_request {
    my ($req) = @_;
    my %info = map { $_ => '-' } @columns;
    my $start = time;
    $info{token} = join ".", $$, 1000 + int rand(9000); # pseudo-session for every request pair
    $info{tsin} = strftime '%Y%m%d %H:%M:%S',gmtime($start);
    $info{ip} = $ENV{REMOTE_ADDR};
    $info{ua} = $ENV{HTTP_USER_AGENT};
    $info{server} = $hostname;
    $info{referrer} = $ENV{HTTP_REFERER};
    $info{url} = $ENV{REQUEST_URI};

    open my $outfile, ">>", $logfilename
        or die "$logfilename: $!";
    {
        my $stdout= select $outfile;
        $|= 1;
        select $stdout;
    }
    print $outfile join( "\t", @info{@columns} ), "\n";

    eval{ $req->(); };

    if ($@) {
        $info{code} = 500;
    } else {
        $info{code} = 200;
    };
    $info{ttaken} = time - $start;
    $info{user} = $Everything::HTML::USER->{node_id} || "-";

    if (ref $Everything::HTML::GNODE) {
        $info{node} = $Everything::HTML::GNODE->{node_id};
        $info{type} = $Everything::HTML::GNODE->{type}->{node_id};
    };
    print $outfile join( "\t", @info{@columns} ), "\n";
};


1;
