package Everything::VoteSecret;

use Digest::MD5 qw(md5_base64);

use vars qw( $VERSION $secret );
$VERSION= 1.000;
$secret = '-'; # XXX Change when going public!

sub votingMagic
{
    my $checksum= $secret . (getId($NODE)+getId($USER)) . $USER->{title};
    return md5_base64($checksum);
}

1;
