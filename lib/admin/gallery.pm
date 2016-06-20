package admin::gallery;

use Dancer ':syntax';
use Helpers;

prefix '/admin/gallery';

### Index page, gallery list
get '/' => sub {
	my $albums = sql_select(qq{
		SELECT a.album_id, a.title, COUNT(p.album_id) count, size
		FROM gallery_albums a
		LEFT JOIN gallery_photos p USING (album_id)
		WHERE a.site_id = ?
		GROUP BY a.album_id
		ORDER BY a.album_id
	}, vars->{site}->{site_id});

	template 'admin/gallery/index', {
		albums => $albums,
		album  => { album_id => 0 }, # default root album
		title  => loc("Галерея")
	};
};

### Album page
get '/album/:album_id' => sub {
	template 'admin/gallery/index', {
		album  => _get_album(params->{album_id}),
		albums => [ quick_select('gallery_albums', { site_id  => vars->{site}->{site_id} }) ],
		title  => loc("Галерея")
	};
};

### Settings page
get '/album/:id/settings' => sub {
	template 'admin/gallery/settings', {
		album => _get_album(params->{id}),
		title => loc("Галерея")
	};
};

post '/album/:id/settings' => sub {
	my $in = params;

	my $album  = _get_album($in->{id});
	my $data   = validator($in, "gallery_album_form_update.pl");
	my $params = $data->{result} and $data->{valid}
		or return template 'admin/gallery/settings', {
			title => loc('Галерея'),
			album => $album,
			    p => $data->{result},
		};

	quick_update(
		'gallery_albums', {
			album_id => $params->{id},
			site_id  => vars->{site}->{site_id}
		}, {
			title 		=> $params->{title} 		|| $album->{title},
			size  		=> $params->{size} 		 	|| $album->{size},
			per_page  	=> $params->{per_page}  	|| $album->{per_page},
		},  
	);
	
	redirect '/admin/gallery/album/' . params->{id};
};

sub _get_album {
	my $id = shift;
	return quick_select(
		'gallery_albums', {
			album_id => $id,
			site_id  => vars->{site}->{site_id}
		}
	);
}

true;
