package admin::settings;

use Dancer ':syntax';
use Helpers;

prefix '/admin/settings';

### General

get '/' => sub {
	template '/admin/settings/index', {
		title => loc("Основное")
	};
};

post '/' => sub {
	quick_update(
		'sites', {
			site_id => vars->{site}->{site_id},
		}, {
			title          => params->{title},
			subtitle       => params->{subtitle},
			sharing_widget => params->{sharing_widget},
			disable        => params->{disable}
		}
	);
	session theme => params->{theme} if params->{theme};
	redirect '/admin/settings';
};

### Redirect

get '/redirect' => sub {
	my @redirects = quick_select(
		"redirects", {
			site_id  => vars->{site}->{site_id}
		}, {
			order_by => { desc => 'redirect_id' }
		}
	);
	template '/admin/settings/redirect', {
		title     => loc("Переадресация"),
		redirects => \@redirects
	};
};

post '/redirect/delete/:id' => sub {
	quick_delete(
		"redirects", {
			site_id     => vars->{site}->{site_id},
			redirect_id => params->{id}
		}
	);
	redirect '/admin/settings/redirect';
};

post '/redirect' => sub {
	return redirect '/admin/settings/redirect'
		unless vars->{site}->{premium};
	quick_insert(
		"redirects", {
			site_id     => vars->{site}->{site_id},
			source      => params->{source},
			destination => params->{destination}
		}
	);
	redirect '/admin/settings/redirect';
};

### Favicon

get '/favicon' => sub {
	template 'admin/settings/favicon', {
		title => loc('Favicon')
	};
};

post '/favicon' => sub {
	my $filename = params->{filename};
	if (!$filename) {
		$filename = '';
	} elsif ($filename && $filename =~ /\.(ico)|(png)|(gif)$/) {
		$filename = "/files/" . vars->{site}->{dir} . "/$filename";
	} else {
		return to_json { result => 'error' };
	}
	quick_update(
		'sites', {
			site_id => vars->{site}->{site_id},
		}, {
			favicon => $filename,
		}
	);
	return to_json { result => 'ok' };
};

### SEO

get '/seo' => sub {
	template 'admin/settings/seo', {
		title => loc('SEO')
	};
};

post '/seo' => sub {
	my $params = {
		meta_header      => params->{header},
		meta_description => params->{description},
		meta_keywords    => params->{keywords},
		noindex          => params->{noindex} || 0,
	};

	$params->{robots} = params->{robots} if vars->{site}->{premium};

	quick_update('sites', { site_id => vars->{site}->{site_id} }, $params);
	redirect '/admin/settings/seo';
};

### Statistics

get '/statistics' => sub {
	template 'admin/settings/statistics', {
		title => loc('Статистика')
	};
};

post '/statistics' => sub {
	quick_update(
		'sites', {
			site_id => vars->{site}->{site_id}
		}, {
			stat_ga_key   => params->{stat_ga_key},
			stat_ym_key   => params->{stat_ym_key},
			stat_tracking => params->{custom_tracking_code}
		}
	);
	redirect '/admin/settings/statistics';
};

# CSS

get '/css' => sub {
	template 'admin/settings/css', {
		title => 'CSS'
	};
};

### HTML

get '/html' => sub {
	return redirect '/admin/settings' if !config->{compatibility};
	template 'admin/settings/html', {
		title => 'HTML',
		meta  => quick_select("sites_meta", { site_id => vars->{site}->{site_id} }) // undef
	};
};

### Advertisement

get '/advertisement/:area' => sub {
	template 'admin/settings/ads', {
		title => loc('Реклама'),
		area  => params->{area},
		meta  => quick_select("sites_meta", { site_id => vars->{site}->{site_id} }) // undef
	};
};

any '/advertisement' => sub {
	forward '/admin/settings/advertisement/header' if request->method eq 'GET';
	my $params = params;
	if ( quick_lookup("sites_meta", { site_id => vars->{site}->{site_id} }, "option_id") ) {
		quick_update('sites_meta', { site_id => vars->{site}->{site_id} }, $params);
	} else {
		$params->{site_id} = vars->{site}->{site_id};
		quick_insert('sites_meta', $params);
	}
	redirect request->referer;
};

true;
