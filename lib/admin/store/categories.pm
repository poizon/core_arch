package admin::store::categories;

use Dancer ':syntax';
use Helpers;

use tools::store;

prefix '/admin/store/categories';

get '/' => sub {
	my $categories = tools::store::get_categories();

	my $categories_ids = { map { $_->{category_id} => 1 } @$categories };
	my (@parent_order, %parent_children);
	for my $c (@$categories) {
		if ($c->{parent_id} && !$categories_ids->{ $c->{parent_id} }) {
			$c->{parent_id} = 0;
			quick_update(
				'store_category',{
					category_id => $c->{category_id},
					site_id     => vars->{site}->{site_id}
				}, {
					parent_id   => 0,
				}
			);
		}
		if ($c->{parent_id}) {
			$parent_children{$c->{parent_id}} = []
				unless $parent_children{$c->{parent_id}};
			push(@{$parent_children{$c->{parent_id}}}, $c);
		}
		else {
			push(@parent_order, $c);
		}
	}

	template 'admin/store/categories/index', {
		title      => loc("Категории"),
		categories => _prepare_children(\@parent_order, \%parent_children),
	};
};

get '/add/?' => sub {
	template 'admin/store/categories/add', {
		title    => loc("Категории"),
	};
};

post '/add/?' => sub {
	my $in   = params;
	my $data = validator($in, 'store_category_form_create.pl');

	$data->{valid}
		or return template 'admin/store/categories/add', {
			error    => loc('Ошибка'),
			category => $data->{result},
		};
	my $params = $data->{result};

	my $category = quick_select(
		'store_category', {
			site_id => vars->{site}->{site_id},
			title   => $params->{title},
		}
	);
	if (defined $category) {
		$data->{result}->{err_title} = loc('Такое имя уже существует');
		return template 'admin/store/categories/add', {
			error    => loc('Ошибка'),
			category => $data->{result},
		};
	}

	quick_insert(
		'store_category', {
			site_id	    => vars->{site}->{site_id},
			title       => $params->{title},
			body        => $params->{body},
			hidden      => $params->{hidden} || 0,
		}
	);

	my $id = last_insert_id();
	_upload_category_cover($id, '') if $params->{cover};

	redirect params->{action} eq 'apply' ?
		"/admin/store/categories/$id/edit/" :
		"/admin/store/categories";
};

get '/:id/edit/?' => sub {
	template 'admin/store/categories/edit', {
		title    => loc("Категории"),
		category => tools::store::get_category(params->{id})
	};
};

post '/:id/edit/?' => sub {
	my $in   = params;
	my $data = validator($in, 'store_category_form_update.pl');

	$data->{valid}
		or return template 'admin/store/categories/edit', {
			error    => loc('Ошибка'),
			category => $data->{result},
		};
	my $params = $data->{result};

	my $check_category = quick_select(
		'store_category', {
			category_id => { 'ne' => $params->{id} },
			site_id     => vars->{site}->{site_id},
			title       => $params->{title},
		}
	);
	if (defined $check_category) {
		$data->{result}->{err_title} = loc('Такое имя уже существует');
		return template 'admin/store/categories/edit', {
			error    => loc('Ошибка'),
			category => $data->{result},
		};
	}

	my $category = tools::store::get_category($params->{id});
	_upload_category_cover($params->{id}, $category->{cover}) if params->{cover};

	quick_update(
		'store_category',{
			category_id => $params->{id},
			site_id	    => vars->{site}->{site_id}
		}, {
			title       => $params->{title},
			body        => $params->{body},
			hidden      => $params->{hidden} || 0
		}
	);

	redirect params->{action} eq 'apply' ?
		"/admin/store/categories/$params->{id}/edit/" :
		"/admin/store/categories";
};


sub _upload_category_cover {
	return tools::store::upload_cover('store_category', 'category_id', $_[0], $_[1]);
}

sub _prepare_children {
	my ($parents, $children_map) = @_;

	for my $parent (@$parents) {
		my $children = _prepare_children($children_map->{ $parent->{category_id} } || [], $children_map);
		$parent->{children} = $children;
	}

	return $parents;
}

true;
