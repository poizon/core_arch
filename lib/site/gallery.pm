package site::forms;

use Dancer ':syntax';
use Helpers;

prefix '/gallery';

get '/?' => sub {	
	my $albums = sql_select(qq{
		SELECT a.*, IF(p.photo_id, p.filename, 
			(SELECT filename 
			FROM gallery_photos 
			WHERE album_id = a.album_id AND hidden = 0 
			LIMIT 1)) cover
		FROM gallery_albums a LEFT JOIN gallery_photos p ON a.cover_id = p.photo_id
		WHERE a.site_id = ? AND a.hidden = 0
	}, vars->{site}->{site_id});

	my @unsorted = quick_select(
		'gallery_photos', {
			site_id  => vars->{site}->{site_id},
			album_id => undef,
			hidden   => 0
		}, {
			order_by => 'sort',
		}
	);

	render_template(
		'gallery/index', {
			title    => loc('Галерея'),
			albums   => $albums,
			unsorted => \@unsorted
		}
	);
};

get '/album/:album_id/?' => sub {
	my $criteria = { 
		site_id  => vars->{site}->{site_id},
		album_id => params->{album_id},
		hidden   => 0,
	};
	
	my $album = quick_select('gallery_albums', $criteria);
	status 404 unless $album;

	my $limit = $album->{per_page} // 10;
	my $total = quick_count('gallery_photos', $criteria);
	my $pager = pager($limit, $total);

	my @photos = quick_select(
		'gallery_photos', $criteria, {
			order_by => 'sort',
			limit    => $limit,
			offset   => $pager->from,
		}, 
	);

	render_template(
		'gallery/album', {
			title	=> $album->{title} || loc('Галерея'),
			photos	=> \@photos,
			album	=> $album,
			pager	=> $pager,
		}
	);
};

true;
