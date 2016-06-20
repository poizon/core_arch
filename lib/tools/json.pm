package tools::json;

use Dancer ':syntax';
use File::Slurp::Tiny 'read_file';
use FindBin qw/$Bin $RealBin/;

use Exporter();
use base 'Exporter';
our @EXPORT = qw/load_json/;

sub load_json {
	my $file = shift;
	my $path = $RealBin . '/../' . $file; # NOTE: we expect $RealBin is .../bin/ here
	return undef unless -f $path;
	my $json = read_file($path);
	return $json ? from_json($json, { utf8 => 1 }) : undef;
}

1;