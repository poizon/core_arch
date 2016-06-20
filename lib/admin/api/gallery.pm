package admin::api::gallery;

use Dancer ':syntax';
use Helpers;

use File::Path qw/rmtree make_path/;
use Encode;

use Dancer::Plugin::REST;
prepare_serializer_for_format;
prefix '/admin/api/gallery';

# Set album cover
put '/album/:id.:format' => sub {
	my $in = params;

	my $data = validator($in, "gallery_album_form_update.pl");
	$data->{valid}
		or return to_json {
			error  => loc('Ошибка'),
			fields => $data->{result}
		};
	my $params = $data->{result};

	quick_update(
		'gallery_albums', {
			album_id => $params->{id},
			site_id  => vars->{site}->{site_id}
		}, {
			cover_id => $params->{cover_id},
			title    => $params->{title}
		}
	);

	status_ok { result => 'ok' };
};

# Delete album
del '/album/:id.:format' => sub {
	my $in = params;

	my $data = validator($in, "id_field.pl");
	$data->{valid}
		or return to_json {
			error  => loc('Ошибка'),
			fields => $data->{result}
		};
	my $params = $data->{result};
	rmtree "$Bin/../public/gallery/" . vars->{site}->{dir} . "/$params->{id}";
	quick_delete(
		'gallery_albums', {
			album_id => $params->{id},
			site_id  => vars->{site}->{site_id}
		}
	);
	status_ok { result => 'ok' };
};

# Photo CRUD
get '/album/:id/photos.html' => sub {
	my $in = params;

	my $data = validator($in, 'id_field.pl');
	$data->{valid}
		or return to_json {
			error  => loc('Ошибка'),
			fields => $data->{result}
		};
	my $params = $data->{result};

	my $album_id = $params->{id} == 0 ? undef : $params->{id};
	my @photos = quick_select(
		'gallery_photos', {
			album_id => $album_id,
			site_id  => vars->{site}->{site_id}
		},{
			order_by => 'sort',
		}
	);

	my $album = quick_select(
		'gallery_albums', {
			album_id => $album_id,
			site_id  => vars->{site}->{site_id}
		}
	);

	$album ||= { album_id => 0 };

	template 'admin/gallery/list', {
		photos   => \@photos,
		album    => $album
	}, {
		layout => undef
	};
};

# Add photo to the album
post '/album/:id/photo.:format' => sub {
	my $in   = params;
	my $file = upload('file');

	my $data = validator($in, 'gallery_photo_form_create.pl');
	$data->{valid}
		or return to_json {
			error  => loc('Ошибка'),
			fields => $data->{result}
		};

	#Check limit size
	if (!allow_upload($file->{size})) {
		status 500;
		content_type 'text/plain';
		return loc("Вы превысили допустимый объем хранящихся файлов");
	}

	my $params = $data->{result};

	# Copy photo to server
	my $path = "$Bin/../public/gallery/" . vars->{site}->{dir} . '/' . $params->{id};
	make_path $path unless -e $path;

	my $filename = $file->{filename};
	encode('utf8', $filename);

	$filename = pick_filename($filename, $path) if -e "$path/$filename";
	$file->copy_to("$path/$filename");

	quick_insert(
		'gallery_photos', {
			album_id => $params->{id} == 0 ? undef : $params->{id},
			hidden   => 0,
			filename => $filename,
			site_id  => vars->{site}->{site_id}
		}
	);
	my $photo_id = last_insert_id();

	status_created { result => 'ok', id => $photo_id };
};

# Update photo
put '/album/:album_id/photo/:id.:format' => sub {
	my $in = params;

	my $data = validator($in, 'gallery_photo_form_update.pl');
	$data->{valid}
		or return to_json {
			error  => loc('Ошибка'),
			fields => $data->{result}
		};
	my $params = $data->{result};

	quick_update(
		'gallery_photos', {
			photo_id => $params->{id},
			site_id  => vars->{site}->{site_id}
		}, {
			title => $params->{title}
		}
	);

	status_ok { result => 'ok' };
};

# Delete album
del '/album/:album_id/photo/:id.:format' => sub {
	my $in = params;

	my $data = validator($in, 'id_field.pl');
	$data->{valid}
		or return to_json {
			error  => loc('Ошибка'),
			fields => $data->{result}
		};
	my $params = $data->{result};

	my $photo = quick_select(
		'gallery_photos', { 
			photo_id => $params->{id}, 
			site_id  => vars->{site}->{site_id} 
		}
	);
	return to_json { error  => loc('Ошибка') } unless $photo;
	
	my $album_id = defined $photo->{album_id} ? $photo->{album_id} : 0;
	my $path	 = "$Bin/../public/gallery/" . vars->{site}->{dir} . '/' . $album_id;

	unlink "$path/$photo->{filename}";
	quick_delete(
		'gallery_photos', {
			photo_id => $params->{id},
			site_id  => vars->{site}->{site_id}
		}
	);

	status_ok { result => 'ok' };
};

### Create album

post '/album/create.:format' => sub {
	my $in   = params;
	my $data = validator($in, 'gallery_album_form_create.pl');
	$data->{valid}
		or return to_json {
			error  => loc('Ошибка'),
			fields => $data->{result}
		};
	my $params = $data->{result};

	my $album = quick_select(
		'gallery_albums', {
			title   => $params->{title},
			site_id => vars->{site}->{site_id}
		}
	);

	return to_json { error => loc('Такое имя уже существует') }
		if defined $album;

	quick_insert('gallery_albums', {
		site_id  => vars->{site}->{site_id},
		title    => $params->{title},
		cover_id => 0,
		hidden   => 0
	});
	my $album_id = last_insert_id();

	# Create folder for the album
	my $album_dir = vars->{site}->{dir} . "/" . $album_id;
	make_path("$Bin/../public/gallery/$album_dir");

	status_created { result => 'ok' };
};

post '/album/sort.:format' => sub {
	my $in   = params;
	my $data = validator($in, 'gallery_album_form_sort.pl');
	$data->{valid}
		or return to_json {
			error  => loc('Ошибка'),
			fields => $data->{result}
		};
	my $params = $data->{result};

	my $priority = 0;
	for my $id (@{ $params->{ids} }) {
		quick_update(
			'gallery_photos', {
				photo_id => $id,
				site_id  => vars->{site}->{site_id}
			}, {
				sort => $priority++,
			}
		);
	}

	status_ok { result => 'ok' };
};

true;

