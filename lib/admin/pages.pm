package admin::pages;

use Dancer ':syntax';
use Helpers;

prefix '/admin/pages';

### Settings

get '/folder/:id/edit' => sub {
	my $folder = quick_lookup('pages_folders', {
		site_id   => vars->{site}->{site_id},
		folder_id => params->{id}
	}, 'title');

	template 'admin/pages/settings', {
		title  => loc('Страницы'),
		folder => $folder
	};
};

post '/folder/:id/edit' => sub {
	my $in = params;
	my $data = validator($in, 'page_folder_form_update.pl');

	$data->{valid}
		or return template 'admin/pages/settings', {
			title => loc('Страницы'),
			    p => $data->{result}
		};
	my $params = $data->{result};

	quick_update(
		'pages_folders', {
			site_id   => vars->{site}->{site_id},
			folder_id => $params->{id}
		}, {
			title => $params->{title}
		}
	);

	redirect '/admin/pages?folder_id=' . $params->{id};
};

### Create Page
any '/add' => sub {
	return redirect '/admin/pages/' unless _can_add_pages();

	return template 'admin/pages/add', { title => loc("Страницы") }
		if request->method eq 'GET';

	my $in = params;
	$in->{url} ||= to_url($in->{title});
	my $data = validator($in, 'page_form_create.pl');

	$data->{valid}
		or return template 'admin/pages/add', {
			title => loc("Страницы"),
			    p => $data->{result},
		};
	my $params = $data->{result};

	my $page_is_exists = quick_lookup(
		'pages', {
			site_id => vars->{site}->{site_id},
			url     => $params->{url}
		},
		'page_id'
	);
	if ($page_is_exists) {
		$params->{err_url} = loc('Такой URL уже существует');
		return template 'admin/pages/add', {
			title => loc("Страницы"),
			    p => $params
		};
	}

	quick_insert(
		'pages', {
			site_id   => vars->{site}->{site_id},
			title     => $params->{title},
			body      => $params->{body},
			url       => to_url($params->{url}),
			folder_id => $params->{folder_id}
		}
	);
	my $page_id = last_insert_id();

	my $redirect_url = "/admin/pages/";

	$redirect_url .= $page_id . "/edit"
		if $params->{action} eq 'apply';
	$redirect_url .= $params->{folder_id}
		if $params->{action} eq 'done' && $params->{folder_id};

	redirect $redirect_url;
};

### Edit Page
get '/:id/edit' => sub {
	my $page = quick_select(
		"pages", {
			site_id => vars->{site}->{site_id},
			page_id => params->{id}
		}
	);

	template 'admin/pages/edit', {
		folders => _get_folders(),
		page    => $page,
		title   => loc("Страницы")
	};
};

post '/:id/edit' => sub {
	my $in = params;
	my $data = validator($in, 'page_form_update.pl');
	$data->{valid}
		or return template 'admin/pages/edit', {
			title   => loc("Страницы"),
			page    => $data->{result},
			folders => _get_folders(),
		};
	my $params = $data->{result};

	my $page_is_exists = quick_count(
		'pages', {
			site_id => vars->{site}->{site_id},
			url     => $params->{url},
			page_id => { 'ne' => $params->{id} }
		},
		'page_id'
	);

	if ($page_is_exists) {
		$params->{err_url} = loc('Такой URL уже существует');
		return template 'admin/pages/edit', {
			title   => loc("Страницы"),
			page    => $params,
			folders => _get_folders(),
		};
	}

	quick_update(
		'pages', {
			page_id => $params->{id},
			site_id => vars->{site}->{site_id}
		}, {
			title     => $params->{title},
			body      => $params->{body},
			url       => to_url($params->{url}),
			folder_id => $params->{folder_id}
		}
	);

	my $redirect_url = "/admin/pages/";

	if ($params->{action} eq 'apply') {
		$redirect_url .= $params->{id} . "/edit";
		$redirect_url .= "?noeditor" if request->uri =~ /noeditor/;
	} else {
		$redirect_url .= $params->{folder_id} if $params->{folder_id};
	}

	redirect $redirect_url;
};

# Set other page's options
post '/:id/set-meta' => sub {
	my $redirect_url = "/admin/pages/";
	$redirect_url   .= params->{id} . '/edit?active=seo'
		if params->{action} eq 'apply';

	quick_update(
		'pages', {
			page_id => params->{id},
			site_id => vars->{site}->{site_id}
		}, {
			meta_keywords    => params->{meta_keywords},
			meta_description => params->{meta_description},
			meta_title       => params->{meta_title},
			noindex          => params->{noindex} || 0
		}
	);
	redirect $redirect_url;
};

## Index

get '/:folder_id?' => sub {
	my $in     = params;
	my $filter = $in->{filter};

	my @criteria = ( "site_id = ?" );
	my @bind     = ( vars->{site}->{site_id} );
	
	if (params->{folder_id}) {
		push @criteria, "folder_id = ?";
		push @bind, params->{folder_id};
	} else {
		push @criteria, "folder_id IS NULL";
	}
	
	if ($filter) {
		push @criteria, "(url LIKE ? OR title LIKE ?)";
		push @bind, "%$filter%", "%$filter%";
	}
	my $criteria = join ' AND ', @criteria;

	my $limit = config->{per_page}->{pages} || 25;
	my $total = sql_row("SELECT COUNT(*) c FROM pages WHERE $criteria", @bind)->{c};
	my $pager = pager($limit, $total);

	my $pages = sql_select(qq{
		SELECT * FROM pages
		 WHERE $criteria
		 ORDER BY page_id
		 LIMIT ? OFFSET ?
	}, @bind, $pager->offset || 0, $pager->from || 0);

	template 'admin/pages/index', {
		title         => loc('Страницы'),
		pages         => $pages,
		pager         => $pager,
		folders       => _get_folders(),
		can_add_pages => _can_add_pages(),
	};
};

get '/' => sub {
	forward '/admin/pages/';
};

# Subroutines

sub _can_add_pages {
	return true if vars->{site}->{premium};
	my $pages = quick_count('pages', { site_id => vars->{site}->{site_id} });
	return $pages < (config->{limits}->{free}->{pages} || 10) ? true : false;
}

sub _get_folders {
	my $folders = sql_select(qq{
		SELECT f.folder_id, f.title, COUNT(pages.page_id) count
		  FROM pages_folders f
		  LEFT JOIN pages USING (folder_id)
		 WHERE f.site_id = ?
		 GROUP BY f.folder_id
		 ORDER BY f.title
	}, vars->{site}->{site_id});
	unshift @$folders, { folder_id => undef, title => loc('Без категории') };
	return $folders;
}

true;
