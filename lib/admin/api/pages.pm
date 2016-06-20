package admin::api::pages;

use Dancer ':syntax';
use Helpers;

use Dancer::Plugin::REST;
prepare_serializer_for_format;
prefix '/admin/api';

# get pages list
get '/pages.:format' => sub {
	my @pages = quick_select(
		"pages", {
			site_id => vars->{site}->{site_id}
		}, {
			columns => [ qw/page_id title url/ ]
		}
	);
	status_ok { pages => \@pages };
};

post '/pages/folder/create.:format' => sub {
	quick_insert(
		'pages_folders', {
			site_id => vars->{site}->{site_id},
			title   => params->{title}
		}
	);
	my $folder_id = last_insert_id();
	status_created { result =>'ok', id => $folder_id };
};

post '/page/title-to-url.:format' => sub {
	return to_json {
		result => 'ok',
		url    => to_url(params->{title})
	};
};

any '/page/set-main/:id.:format' => sub {
	my $page = quick_select('pages', {
		page_id => params->{id},
		site_id => vars->{site}->{site_id},
	});

	quick_update('sites', {
		site_id => vars->{site}->{site_id},
	}, {
		default_page => $page->{url},
	}) if $page && $page->{url};

	status_ok { result => 'ok' };
};

true;
