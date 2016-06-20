package admin::menu;

use Dancer ':syntax';
use Helpers;

prefix '/admin/menu';

sub build_autocomplete {
	my $AUTOCOMPLETE = [ 
		{ label => loc("Новости"), url => "/news"    }, 
		{ label => loc("Галерея"), url => "/gallery" }, 
		{ label => loc("Интернет-магазин"), url => "/store" }, 
		#{ label => loc("Блог"),    url => "/blog"    }, 
		#{ label => loc("События"), url => "/events"  }, 
	];

	my @pages = quick_select(
		'pages', {
			site_id => vars->{site}->{site_id},
		}, {
			columns => [ qw(title url) ],
			limit   => 100
		}
	);

	push @$AUTOCOMPLETE, { label => $_->{title}, url => "/" . $_->{url} } for @pages;
	return $AUTOCOMPLETE;
}

get '/' => sub {
	my @menu = quick_select(
		'menu', {
			site_id  => vars->{site}->{site_id},
		}, {
			order_by => 'priority'
		}
	);
	
	return redirect '/admin/menu/add' unless scalar @menu;

	my (@parent_order, %parent_children);
	for my $m (@menu) {
		if ($m->{parent_id}) {
			$parent_children{$m->{parent_id}} = []
				unless $parent_children{$m->{parent_id}};
			push(@{$parent_children{$m->{parent_id}}}, $m);
		}
		else {
			push(@parent_order, $m);
		}
	}
	for my $p (@parent_order) {
		$p->{children} = $parent_children{$p->{menu_id}}
			if $parent_children{$p->{menu_id}};
	}

	template 'admin/menu/index', {
		menu  => \@parent_order,
		title => loc('Меню')
	};
};

post '/delete/?' => sub {
	content_type 'application/json';
	quick_delete('menu', { menu_id   => params->{id}, site_id => vars->{site}->{site_id} });
	quick_delete('menu', { parent_id => params->{id}, site_id => vars->{site}->{site_id} });
	return to_json { result => 'ok' };
};

post '/hide/?' => sub {
	content_type 'application/json';

	my $menu = quick_select(
		'menu', {
			site_id => vars->{site}->{site_id},
			menu_id => params->{id},
		}
	) or return to_json { status => loc('Ничего не найдено') };

	quick_update(
		'menu', {
			menu_id => $menu->{menu_id},
		}, {
			hidden  => $menu->{hidden} ? 0 : 1,
		}
	);
	return to_json { result => 'ok' };
};

### Drag&Drop

post '/move/?' => sub {
	content_type 'application/json';

	return to_json { status => loc('Ничего не найдено') } unless params->{id};

	my $element = quick_select(
		'menu', {
			site_id => vars->{site}->{site_id},
			menu_id => params->{id},
		}
	);
	return to_json { status => loc('Ничего не найдено') } unless $element;

	if ($element->{parent_id} != params->{new_parent}) {
		quick_update(
			'menu', {
				menu_id   => $element->{menu_id},
			}, {
				parent_id => params->{new_parent},
			}
		);
	}

	my $priority = 0;
	for my $id (split(/,/, params->{ids})) {
		quick_update(
			'menu', {
				menu_id   => $id,
				parent_id => params->{new_parent},
				site_id   => vars->{site}->{site_id},
			}, {
				priority => ++$priority,
			}
		);
	}

	return to_json { result => 'ok' };
};

### Add

get '/add/?' => sub {
	template 'admin/menu/add', {
		title => loc('Добавить'),
		tags  => to_json(build_autocomplete()),
	};
};

post '/add/?' => sub {
	my $prev = quick_select(
		'menu', {
			site_id   => vars->{site}->{site_id},
			parent_id => 0,
		}, {
			order_by  => { desc => 'priority' },
			limit     => 1,
		}
	);

	quick_insert(
		'menu', {
			title     => params->{title},
			url       => params->{url},
			site_id   => vars->{site}->{site_id},
			priority  => $prev ? $prev->{priority} + 1 : 1
		}
	);
	my $menu_id = last_insert_id();

	redirect params->{action} eq 'done' ? 
		"/admin/menu/" : 
		"/admin/menu/$menu_id/edit";
};

### Edit

get '/:menu_id/edit/?' => sub {
	my $menu = quick_select(
		'menu', {
			menu_id => params->{menu_id},
			site_id => vars->{site}->{site_id},
		}
	) or return redirect '/admin/menu';

	template 'admin/menu/add', {
		title => loc('Изменить'),
		tags  => to_json(build_autocomplete()),
		data  => $menu,
	};
};

post '/:menu_id/edit/?' => sub {
	my $menu_id = params->{menu_id};
	
	quick_update(
		'menu', {
			menu_id => $menu_id,
			site_id => vars->{site}->{site_id}
		}, {
			title   => params->{title},
			url     => params->{url}
		}
	);

	redirect params->{action} eq 'done' ? 
		"/admin/menu/" : 
		"/admin/menu/$menu_id/edit";
};


true;
