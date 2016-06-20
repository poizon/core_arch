package admin::api::files;

use utf8;
use Dancer ':syntax';
use Helpers;
use Encode;

use File::Path qw/rmtree make_path/;
use File::Find::Rule;
use MIME::Base64;

use Dancer::Plugin::REST;
prepare_serializer_for_format;
prefix '/admin/api/files';

### Files CRUD

# get all files from subfolders (for WYSIWYG editor)
get '/images.json' => sub {
	my $path = "$Bin/../public";
	
	my @files = map { s/$path//; { url => decode( 'UTF-8', $_ ) } }
		File::Find::Rule->file()
			->name( qr/\.(png|gif|jpe?g)$/i )
			->in( $path . "/files/" . vars->{site}->{dir} );
	
	to_json \@files;
};

# get files list
get '/:folder.html' => sub {
	my $path  = "$Bin/../public/files/" . vars->{site}->{dir} . "/";
	   $path .= params->{folder} if params->{folder} ne 'root';
	
	opendir(my $dh, $path) or return loc("Ошибка");
	my @dir = sort { -M "$path/$a" <=> -M "$path/$b" } # sort by date
		grep ! -d "$path/$_",  # skip folders and . ..
		readdir $dh;
	closedir $dh;

	my @files = map {
		{
			name => $_,
			size => sprintf "%.2f", ( (stat "$path/$_")[7] || 0 ) / 1024
		}
	} @dir;

	template 'admin/files/list', {
		files  => \@files,
		folder => params->{folder}
	}, {
		layout => undef
	};
};

# upload file
post '/upload' => sub {
	my $in   = params;
	my $file = upload('file');
	my $data = validator({ filename => $file->{filename} }, 'file_form_create.pl');

	if (!$data->{valid}) {
		status 500;
		content_type 'text/plain';
		return loc($data->{result}->{err_filename});
	}
	
	#Check limit size
	if (! allow_upload($file->{size})) {
		status 500;
		content_type 'text/plain';
		return loc("Вы превысили допустимый объем хранящихся файлов");
	}

	my $file_path = "$Bin/../public/files/" . vars->{site}->{dir};
	$file_path   .= '/' . params->{folder} if (params->{folder} && params->{folder} ne 'root');

	make_path($file_path) unless -e $file_path;
	my $filename = $file->{filename};
	   $filename = pick_filename($filename, $file_path) if -e "$file_path/$filename";

	$file->copy_to("$file_path/$filename");

	return to_json {
		link => "/files/" . vars->{site}->{dir} . "/$filename",
	} if params->{uploader} && params->{uploader} eq 'editor';

	return to_json {
		files => [
			name => $filename,
			size => $file->{size},
		],
	};
};

# delete folder
del '/folder/:name.:format' => sub {
	my $in = params;
	return to_json { error => loc("Ошибка") } if params->{name} eq 'root';
	rmtree "$Bin/../public/files/" . vars->{site}->{dir} . '/' . $in->{name};
	status_ok { result => 'ok' };
};

# delete file
del '/:folder/:file.:format' => sub {
	my $in   = params;
	my $path = "$Bin/../public/files/" . vars->{site}->{dir};
	$path   .= '/' . $in->{folder} if $in->{folder} ne 'root';
	$path   .= '/' . $in->{file};

	return to_json { error => loc('Ошибка') } unless -e $path;

	if (-f $path) {
		unlink $path;
	} else {
		rmtree $path;
	}

	status_ok { result => 'ok' };
};

### Create folder

post '/folder/create.:format' => sub {
	my $in   = params;
	my $data = validator($in, 'folder_form_create.pl');

	$data->{valid}
		or return to_json {
			error  => loc('Имя должно содержать только латинские буквы или цифры'),
			fields => $data->{result},
		};
	my $params = $data->{result};

	my $root_folder = "$Bin/../public/files/" . vars->{site}->{dir};
	make_path("$Bin/../public/files", vars->{site}->{dir})
		unless -e $root_folder;

	my $dir_path = $root_folder . "/" . $params->{folder_name};
	! -e $dir_path or
		return to_json {
			error  => loc('Такое имя уже существует'),
			fields => $params
		};

	mkdir $dir_path;

	status_created { result => 'ok' };
};

post '/delete' => sub {
	my ( $filename ) = params->{src} =~ /\/([^\/]+?\.\w+)$/;
	return to_json { error => loc('Ошибка') } unless $filename;
	my $file = "$Bin/../public/files/" . vars->{site}->{dir} . "/$filename";

	return to_json { error => loc('Ошибка') } unless -e $file;
	unlink $file;
	return to_json { status => 'ok' };
};

true;
