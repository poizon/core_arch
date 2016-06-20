package site::store::export;

use Dancer ':syntax';
use Helpers;
use tools::store;

prefix '/store/export';

### YML File for Yandex.Market
get '/yml/?' => sub {
	my $items = sql_select(qq{
		SELECT i.*, c.category_id
		  FROM store_item i
		  LEFT JOIN store_category_relations c USING (item_id)
		 WHERE site_id = ? AND i.hidden = 0
		 GROUP BY i.item_id
	}, vars->{site}->{site_id});
	
	$_->{body} =~ s/<[^>]+>//g for @$items;

	template 'admin/store/export_yml', {
		time       => sprintf("%02d:%02d", (localtime)[2, 1]),
		categories => tools::store::get_categories(),
		items      => $items
	}, { 
		layout => undef 
	};
};

### RSS File for Google Merchant Center
get '/rss/?' => sub {
	my $items = sql_select(qq{
		SELECT i.*, c.category_id
		  FROM store_item i
		  LEFT JOIN store_category_relations c USING (item_id)
		 WHERE site_id = ? AND i.hidden = 0
		 GROUP BY i.item_id
	}, vars->{site}->{site_id});
	
	$_->{body} =~ s/<[^>]+>//g for @$items;

	template 'admin/store/export_rss', {
		time       => sprintf("%02d:%02d", (localtime)[2, 1]),
		categories => tools::store::get_categories(),
		items      => $items
	}, { 
		layout => undef 
	};
};

true;