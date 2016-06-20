package admin::api::store::products;

use Dancer ':syntax';
use Helpers;

use Dancer::Plugin::REST;

prepare_serializer_for_format;
prefix '/admin/api/store/products';

del '/item/:id.:format' => sub {
	my $in   = params;
	my $data = validator($in, 'id_field.pl');

	$data->{valid}
		or return to_json {
			error  => loc('Ошибка'),
			fields => $data->{result}
		};
	my $p = $data->{result};

	my $item = quick_select(
		'store_item', {
			item_id => $p->{id},
			site_id => vars->{site}->{site_id},
		}
	);

	_unlink_item_photo_files($item->{item_id}, $item->{cover}) if $item;

	quick_delete(
		'store_item', {
			site_id => vars->{site}->{site_id},
			item_id => $p->{id}
		}
	);

	status_ok { result => 'ok' };
};

del '/categories/items/:item_id/photo/:id.:format' => sub {
	my $photo = _get_item_photo(params->{id});

	if (!$photo) {
		status 'forbidden';
		return to_json {
			error => 'Forbidden'
		}
	};

	quick_delete('store_item_photo', { photo_id => params->{id} });

	unlink _build_path("/$photo->{filename}");

	status_ok { result => 'ok' };
};

put '/categories/items/:item_id/photo/:id.:format' => sub {
	my $in = params;

	my $data = validator($in, 'store_item_photo_form_update.pl');
	$data->{valid}
		or return to_json {
			error  => loc('Ошибка'),
			fields => $data->{result}
		};
	my $params = $data->{result};

	quick_select(
		'store_item', {
			item_id => $params->{item_id},
			site_id => vars->{site}->{site_id},
	})
		or return to_json {
			error  => loc('Ошибка'),
			fields => {},
		};

	quick_update(
		'store_item_photo', {
			photo_id => $params->{id},
			item_id  => $params->{item_id},
		}, {
			title => $params->{title}
		}
	);

	status_ok { result => 'ok' };
};

post '/categories/items/:item_id/photo/:id/hide.:format' => sub {
	my $in = params;

	my $data = validator($in, 'store_item_photo_form_update.pl');
	$data->{valid}
		or return to_json {
			error  => loc('Ошибка'),
			fields => $data->{result}
		};
	my $params = $data->{result};

	quick_select(
		'store_item', {
			item_id => $params->{item_id},
			site_id => vars->{site}->{site_id},
	})
		or return to_json {
			error  => loc('Ошибка'),
			fields => {},
		};

	quick_update(
		'store_item_photo', {
			photo_id => $params->{id},
			item_id  => $params->{item_id},
		}, {
			hidden => 1
		}
	);

	status_ok { result => 'ok' };
};

post '/categories/items/:item_id/photo/:id/show.:format' => sub {
	my $in = params;

	my $data = validator($in, 'store_item_photo_form_update.pl');
	$data->{valid}
		 or return to_json {
			error  => loc('Ошибка'),
			fields => $data->{result}
		};
	my $params = $data->{result};

	quick_select(
		'store_item', {
			item_id => $params->{item_id},
			site_id => vars->{site}->{site_id},
	})
		or return to_json {
			error  => loc('Ошибка'),
			fields => {},
		};

	quick_update(
		'store_item_photo', {
			photo_id => $params->{id},
			item_id  => $params->{item_id},
		}, {
			hidden => 0
		}
	);

	status_ok { result => 'ok' };
};

get '/categories/items/:id/photo.html' => sub {
	my @photo = quick_select(
		'store_item_photo', {
			item_id => params->{id}
		}
	);

	template 'admin/store/products/photo', {
		item_photo  => \@photo,
		#category_id => params->{category_id},
		item_id	 => params->{id}

	}, {
		layout => undef
	};
};

post '/categories/items/:id/photo.json' => sub {
	my $in   = params;
	my $file = upload('file');
	my $data = validator($in, 'store_item_photo_form_create.pl');

	if (!$data->{valid}) {
		status 500;
		return loc($data->{result}->{err_file});
	}

	#Check limit size
	if (!allow_upload($file->{size})) {
		status 500;
		return loc("Вы превысили допустимый объем хранящихся файлов");
	}
	
	my $params   = $data->{result};
	my $filename = $file->{filename};
	$file->copy_to( _build_path("/$filename") );

	quick_insert(
		'store_item_photo', {
			item_id  => $params->{id},
			filename => $filename,
			hidden   => 0
		}
	);
	my $photo_id = last_insert_id();

	status_created { result => 'ok', id => $photo_id };
};

sub _get_item_photo {
	my $id = shift;
	return sql_row(qq{
		SELECT ph.filename, ph.photo_id
		FROM store_item_photo ph
		JOIN store_item i ON i.item_id = ph.item_id
		WHERE ph.photo_id = ? AND i.site_id = ?
	}, $id, vars->{site}->{site_id});
}

sub _build_path {
	my $suffix = shift || "";
	return "$Bin/../public/store/" . vars->{site}->{dir} . $suffix;
}

sub _unlink_item_photo_files {
	my ($item_id, $cover) = @_;
	unlink _build_path("/$cover") if $cover;
	my @photos = quick_select('store_item_photo', { item_id => $item_id } );
	unlink _build_path("/$_->{filename}") for @photos;
}

true;
