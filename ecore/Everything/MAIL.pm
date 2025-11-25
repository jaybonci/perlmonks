package Everything::MAIL;

############################################################
#
#	Everything::MAIL.pm
#
############################################################

use strict;
use Everything;
use MIME::Lite;

sub BEGIN {
	use Exporter ();
	use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@ISA=qw(Exporter);
	@EXPORT=qw(
			node2mail
			mail2node);
}

# Note: added third parameter to allow override from address when sending mail
#
#
sub node2mail {
	my ($addr, $node,$fromoverride) = @_;
	my @addresses = (ref $addr eq "ARRAY") ? @$addr:($addr);
	my ($user) = $DB->getNodeWhere({node_id => $$node{author_user}},
		$DB->getType("user"));
	my $subject = $$node{title};
	my $body = $$node{doctext};

	my $SETTING = getNode('mail settings', 'setting');
	my ($mailserver, $from, $reply_to);
	if ($SETTING) {
		my $MAILSTUFF = getVars $SETTING;
		$mailserver = $$MAILSTUFF{mailServer};
                $from=$fromoverride;
		$from ||= $$MAILSTUFF{systemMailFrom};
		$reply_to = $$MAILSTUFF{systemMailReplyTo};
	} else {
		$mailserver = "localhost";
		$from = "root\@localhost";
	}
        $reply_to //= $from;

        MIME::Lite->new(
            From => $from,
            To   => $addr,
            "Reply-To" => $reply_to,
            Subject => $subject,
            Data    => $body,
        )->send('smtp');
    return 0;
}

sub mail2node
{
	my ($file) = @_;
	my @filez = (ref $file eq "ARRAY") ? @$file:($file);
	use Mail::Address;
	my $line = '';
	my ($from, $to, $subject, $body);
	foreach(@filez)
	{
		open FILE,"<$_" or die 'suck!\n';
		until($line =~ /^Subject\: /)
		{
			$line=<FILE>;
			if($line =~ /^From\:/)       
			{ 
				my ($addr) = Mail::Address->parse($line);
				$from = $addr->address;
			}
			if($line =~ /^To\:/)  
			{
				my ($addr) = Mail::Address->parse($line);
				$to = $addr->address;
			}
			if($line =~ /^Subject\: (.*?)/)
			{ print "hya!\n"; $subject = $1; }
			print "blah: $line" if ($line);
		}
		while(<FILE>)
		{
			my $body .= $_;
		}
		my ($user) = $DB->getNodeWhere({email=>$to},
			$DB->getType("user"));
		my $node;
		%$node = { author_user => getId($user),
			from_address => $from,
			doctext => $body};
        $DB->insertNode($subject, $DB->getType("mail"), -1, $node);
	}
}
1;

