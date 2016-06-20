package Helpers;

use Dancer ':syntax';

use Dancer::Plugin::Database;
use Dancer::Plugin::ValidateTiny;
use Dancer::Plugin::Email;
use Dancer::Plugin::EncodeID;

use Data::Pager;
use Digest::MD5;
use FindBin qw/$Bin/;
use File::Path qw/make_path/;
use File::Copy qw/move/;
use Encode qw/encode_utf8/;

use Text::Unidecode;
use File::Basename;
use Data::Dumper;
use File::Find qw/find/;

use tools::I18N;
use tools::templates;
use tools::json;

use Exporter();
use base 'Exporter';
our @EXPORT = qw(
	render_template params2hash pager to_url site_dir pick_filename allow_upload
	md5_hex loc validator email make_path move encode_id Dumper
	database last_insert_id sql sql_select sql_row
	quick_select quick_count quick_update quick_delete quick_lookup quick_insert
	$Bin $languages $currencies 
);

our $languages  = load_json('json/languages.json');
our $currencies = load_json('json/currencies.json');

# md5 (fixed to work with utf)
sub md5_hex {
	my $str = shift or return undef;
	return Digest::MD5::md5_hex(encode_utf8($str));
}

### Pagination. Returns Data::Pager object
# my $pager = pager($offset, $total)
sub pager {
	my $offset = shift || 0;
	my $limit  = shift || 0;
	my $page   = int(params->{page} // 1);

	my $pager = Data::Pager->new({
		current => $page,   # this is the current pager position
		perpage => 5,       # the pager consists of this number of links (defaults to 10)
		offset  => $offset, # this is the number of results (fetched from the DB for example) per result
		limit   => $limit,  # how far is the pager allowed
	});
	eval('');
	return $pager;
}

# _to_url converts any string to translit
sub to_url {
	my $str = unidecode(shift) or return;
	$str =~ s/\s+|-+/-/g;
	$str =~ s/^-+|-+$//g;
	$str =~ s/[^\/^\.^\w-]+//g;
	return lc $str;
}

# site_id to path e.g.:
#  100	  -> /1/0/0/100
#  35	  -> /0/3/5/35
#  536789 -> /5/3/6/536789
sub site_dir {
	my $site_id  = shift or return;
	my $length   = config->{subfolder_length} // 3;
	my $short_id = sprintf("%0" . $length . "d", substr($site_id, 0, $length));
	return join( "/", split('',  $short_id), $site_id );
}

# function helps to choose unique filename
sub pick_filename {
	my ($filename, $path) = @_;
	my $i = 1;
	my ($base_name, $dir_name, $ext) = fileparse $filename, '.[^\.]*';
	$filename = $base_name . "(" . $i++ . ")" . $ext while -e "$path/$filename";
	return $filename;
}

### build hash from the keys separated by a dot
# example: from "a.b.c" => "value" to { a => { b => { c => "value" } } }
sub params2hash {
	my $params = shift;
	my $result = {};
	for my $key (keys %$params) {
		my @splited = split(/\./, $key);
		my $tmp = $result;
		for (my $i = 0; $i < @splited; $i++) {
			$tmp->{$splited[$i]} = $params->{$key} if ($i + 1 == @splited);
			$tmp->{$splited[$i]} = {} unless exists $tmp->{$splited[$i]};
			$tmp = $tmp->{$splited[$i]};
		}
	}
	return $result;
}

### Check users storage size
sub allow_upload {
	return true if vars->{site}->{premium}; # unlimited storage for premium users 
	use constant STORAGE_LIMIT => 524288000; # 500MB = 500 * 1024 * 1024

	my $file_size = shift or return false;
	my $root_dir  = "$Bin/../public";
	my $user_dir  = vars->{site}->{dir};

	my $storage_size = 0;
	my @dirs = grep { -e } map { "$root_dir/$_/$user_dir" } qw/files gallery store/;

	find({ wanted => sub { $storage_size += -s if -f }, no_chdir => 1 }, @dirs);
	return $storage_size + $file_size <= STORAGE_LIMIT ? true : false;
}

### SQL

sub sql {
	my $sql = shift or return;
	my $sth = database->prepare($sql);
	$sth->execute(@_) if $sth;
	return $sth;
}

sub sql_select {
	my $sth = sql(@_);
	my $ref = $sth->fetchall_arrayref({}) || [];
	return $ref;
}

sub sql_row {
	my $ref = sql_select(@_);
	return $ref->[0] if $ref->[0];
	return undef;
}

sub quick_select   { return database->quick_select(@_); }
sub quick_count    { return database->quick_count(@_);  }
sub quick_update   { return database->quick_update(@_); }
sub quick_lookup   { return database->quick_lookup(@_); }
sub quick_insert   { return database->quick_insert(@_); }
sub quick_delete   { return database->quick_delete(@_); }
sub last_insert_id { return database->last_insert_id(undef, undef, undef, undef); }

true;
