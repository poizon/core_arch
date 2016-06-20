package admin::files;

use Dancer ':syntax';
use Helpers;

prefix '/admin/files';

### Files list

get '/' => sub {
	my $root_folder = "$Bin/../public/files/" . vars->{site}->{dir};
	make_path($root_folder) unless -e $root_folder;

	opendir(my $dh, $root_folder);
	my @folders = grep { -d "$root_folder/$_" && $_ ne '.' &&  $_ ne '..' } readdir $dh;
	closedir $dh;

	template 'admin/files/index', {
		folder  => params->{folder} || 'root',
		folders => \@folders,
		title   => loc("Файлы")
	};
};

### Settings

get '/settings' => sub {
	template 'admin/files/settings', {
		folder => params->{folder_name},
		title  => loc("Файлы")
	};
};

# Rename folder
post '/settings' => sub {
	my $in   = params;
	my $data = validator($in, 'folder_form_update.pl');

	$data->{valid}
		or return template 'admin/files/settings', {
			folder => $data->{result}->{folder_name},
			p      => $data->{result}
		};
	my $params = $data->{result};

	my $root = "$Bin/../public/files/" . vars->{site}->{dir};
	move("$root/$params->{folder_name}", "$root/$params->{new_folder_name}");

	#redirect '/admin/files/settings?folder_name=' . $params->{new_folder_name};
	redirect '/admin/files';
};

true;
