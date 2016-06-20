package admin::store::products;

use Dancer ':syntax';
use Helpers;

use Text::CSV_XS qw/csv/;

use tools::store;

prefix '/admin/store/products';

### Add Products

get '/add/?' => sub {
	return redirect '/admin/store/products' unless _can_add_items();
	template 'admin/store/products/add', {
		categories => tools::store::get_categories(),
		items      => _get_items(),
		title      => loc("Товары"),
	};
};

post '/add/?' => sub {
	return redirect '/admin/store/products' unless _can_add_items();

	my $in   = params;
	my $data = validator($in, 'store_item_form_create.pl');

	$data->{valid}
		or return template 'admin/store/products/add', {
			categories => tools::store::get_categories(),
			     error => loc('Ошибка'),
			     items => _get_items(),
			         p => $data->{result},
		};
	my $params = $data->{result};

	# 1. Add item
	database->begin_work;
	quick_insert(
		'store_item', {
			site_id     => vars->{site}->{site_id},
			title       => $params->{title},
			description => $params->{description},
			body        => $params->{body},
			price       => $params->{price} || 0,
			price_sale  => $params->{price_sale} || undef,
			hidden      => $params->{hidden} || 0,
		}
	);
	my $item_id = last_insert_id();

	# 2. Add item params
	_insert_params($item_id, $in);

	# 4. Add item more
	_insert_more($item_id, $params->{items_more});

	# Add item categories
	_insert_category_relations($item_id, $params->{categories});

	database->commit;

	# 5. Upload cover
	_upload_item_cover($item_id) if params->{cover};
	
	my $catalog_id = ref $in->{categories} ? 
		$in->{categories}->[0] : $in->{categories};

	my $redirect = "/admin/store/products/";
	if ($in->{action} eq 'apply') {
		$redirect .= "$item_id/edit/";
	}
	else {
		$redirect .= $catalog_id if $catalog_id;
	}
	
	redirect $redirect;
};

### Edit Products

get '/:id/edit/?' => sub {
	my $in   = params;
	my $data = validator($in, 'id_field.pl');

	$data->{valid} or return redirect '/admin/store';
	my $params = $data->{result};
	my $stash  = _get_item_stash($params->{id});

	return $stash->{item} ?
		template 'admin/store/products/edit', $stash :
		redirect '/admin/store';
};

post '/:id/edit/?' => sub {
	my $in   = params;
	my $data = validator($in, 'store_item_form_update.pl');
	
	my $params = $data->{result};
	unless ($data->{valid}) {
		my $stash  = _get_item_stash($in->{id});
		$stash->{p} = $params;
		return template 'admin/store/products/edit', $stash;
	}

	my $item = quick_select(
		'store_item', {
			site_id => vars->{site}->{site_id},
			item_id => $params->{id},
		}
	);

	quick_delete('store_category_relations', { item_id => $params->{id} });
	_insert_category_relations($item->{item_id}, $params->{categories});

	quick_delete('store_item_param',       { item_id => $in->{id} });
	quick_delete('store_item_param_value', { item_id => $in->{id} });
	_insert_params($item->{item_id}, $in);
	
	quick_delete('store_item_info', { item_id => $in->{id} });
	_insert_info($item->{item_id}, $params->{info_key}, $params->{info_val});

	quick_delete('store_item_more', { parent_id => $in->{id} });
	_insert_more($item->{item_id}, $params->{items_more});

	_upload_item_cover($item->{item_id}, $item->{cover}) if $in->{'cover'};

	quick_update(
		'store_item', {
			site_id => vars->{site}->{site_id},
			item_id => $params->{id}
		}, {
			title       => $params->{title},
			description => $params->{description},
			body        => $params->{body},
			price       => $params->{price} || 0,
			price_sale  => $params->{price_sale} || undef,
			hidden      => $params->{hidden} || 0
		}
	);
	
	my $catalog_id = ref $in->{categories} ? 
		$in->{categories}->[0] : $in->{categories};

	my $redirect  = "/admin/store/products/";
	   $redirect .= "$in->{id}/edit/" if $in->{action} eq 'apply';
	
	redirect $redirect;
};

# CSV Export
get '/export' => sub {	
	my $ref = sql_select(qq{
		SELECT i.*, GROUP_CONCAT(c.title)
		  FROM store_item i
		  LEFT JOIN store_category_relations scr USING (item_id)
		  LEFT JOIN store_category c USING (category_id)
		 WHERE i.site_id = ?
		 GROUP BY i.item_id
	}, vars->{site}->{site_id});

	my @columns  = qw/title categories description body price price_sale/;
	my @products = ( "TITLE,CATEGORIES,SHORT DESCRIPTION,DESCRIPTION,PRICE,SALE PRICE" );
	push @products, join ',', map { _csv_escape($_) } @{$_}{ @columns } for @$ref;
	
	content_type 'text/csv';
	return join "\n", @products;
};

# CSV Import
post '/import' => sub {
	my $file = upload('file');
	
	if (!$file->{filename} or $file->{filename} !~ /\.(txt|csv)$/i) {
		return forward '/admin/store/products', { 
			error => loc ('Расширение импортируемого файла должно быть TXT или CSV')
		};
	}

	my $csv = csv(in => $file->{tempname}, headers => 'skip');

	#export to dbase
	my @vars   = ();
	my $query  = 'INSERT INTO store_item (site_id, title, description, body, price, price_sale) VALUES ';
	   $query .= join',', ('(?, ?, ?, ?, ?, ?)') x @$csv;

	push @vars, vars->{site}->{site_id}, $_->[0], @{$_}[2 .. 5] for @$csv;
	sql($query, @vars);

	forward '/admin/store/products';
};

# Products
get '/:category_id' => sub {
	template 'admin/store/products/index', {
		title         => loc("Товары"),
		items         => tools::store::get_items('admin', params->{category_id} // 0),
		categories    => tools::store::get_categories(),
		category_name => quick_lookup('store_category', { category_id => params->{category_id} }, 'title'),
		can_add_items => _can_add_items(),
	};
};

any '/' => sub {
	my $filter = params->{search};
	my $criteria->{site_id} = vars->{site}->{site_id};
	$criteria->{title} = { like => "%$filter%" } if $filter;
	
	my $limit = config->{per_page}->{products} || 50;
	my $total = quick_count('store_item', $criteria);
	my $pager = pager($limit, $total);
	
	my @items = quick_select(
		'store_item', $criteria, {
			columns  => [ qw(title hidden price price_sale item_id) ],
			order_by => 'sort',
			limit    => $pager->offset,
			offset   => $pager->from
		}
	);
	
	template 'admin/store/products/index', {
		title => loc("Товары"),
		items => \@items,
		pager => $pager,
		can_add_items => _can_add_items(),
	};
};

### private methods

sub _csv_escape {
	my $str = shift or return '';
	   $str =~ s/"/""/g;
	return '"' . $str . '"';
}

sub _get_item_stash {
	my $id   = shift or return;
	my $item = tools::store::get_item_data('admin', $id) or return;
	return {
		title      => loc("Товары"),
		items      => _get_items(),
		item       => $item,
		categories => tools::store::get_categories(),
	}
}

sub _get_items {
	my @items = quick_select(
		'store_item', {
			site_id  => vars->{site}->{site_id},
		}, {
			order_by => ['sort', 'item_id'],
		}
	);
	return \@items;
}

sub _can_add_items {
	my $premium  = vars->{site}->{premium};
	return true if $premium && vars->{site}->{package} eq 'Business';
	my $products = quick_count('store_item', { site_id => vars->{site}->{site_id} });
	my $limits   = config->{limits};
	return true if  $premium && $products < ( $limits->{pro}->{products}  || 25 );
	return true if !$premium && $products < ( $limits->{free}->{products} || 10 );
	return false;
}

### Subroutines for add/edit product

sub _insert_info {
	my $item_id = shift or return;
	my $keys    = shift || [];
	my $values  = shift || [];

	for my $i (0 .. @$keys) {
		next unless $keys->[$i] && $values->[$i];
		quick_insert(
			'store_item_info', {
				item_id => $item_id,
				name	=> $keys->[$i],
				value   => $values->[$i]
			}
		);
	}
}

sub _insert_params {
	my ($item_id, $params) = @_;
	$params = tools::store::params_to_struct($params);
	return unless ref $params->{param} eq 'ARRAY';

	for my $param (@{$params->{param}}) {
		quick_insert(
			'store_item_param', {
				item_id => $item_id,
				name    => $param->{name},
				sort    => 1,
			}
		);

		next unless ref $param->{items} eq 'ARRAY';
		my $param_id = last_insert_id();

		for my $item (@{$param->{items}}) {
			next unless $item->{val};
			my $price = $item->{price} eq '0.00' || !$item->{price} ? undef : $item->{price};
			
			quick_insert(
				'store_item_param_value', {
					param_id => $param_id,
					item_id  => $item_id,
					value    => $item->{val},
					price    => $price,
				}
			);
		}
	}
}

sub _insert_more {
	my ($item_id, $items_more) = @_;
	return unless $items_more || ref $items_more;

	for my $id (@$items_more) {
		quick_insert(
			'store_item_more', {
				parent_id => $item_id,
				item_id   => $id,
			}
		);
	}
}

sub _upload_item_cover {
	return tools::store::upload_cover('store_item', 'item_id', $_[0], $_[1]);
}

sub _insert_category_relations {
	my ($item_id, $categories) = @_;

	return unless $categories || ref $categories;

	foreach (@$categories) {
		quick_insert(
			'store_category_relations', {
				category_id => $_,
				item_id     => $item_id,
			}
		) if $_ =~ /^\d+$/;
	}
}

true;
