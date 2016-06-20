use utf8;
{
	fields => [ qw/title cover price items_more price_sale category_id categories description body info_key info_val/ ],
	filters => [
		items_more => sub {
			(ref $_[0] && ref $_[0] eq 'ARRAY') ? $_[0] : [ $_[0] ];
		},
		info_key => sub {
			(ref $_[0] && ref $_[0] eq 'ARRAY') ? $_[0] : [ $_[0] ];
		},
		info_val => sub {
			(ref $_[0] && ref $_[0] eq 'ARRAY') ? $_[0] : [ $_[0] ];
		},
		categories => sub {
			(ref $_[0] && ref $_[0] eq 'ARRAY') ? $_[0] : [ $_[0] ];
		},
	],
	checks => [
		['title', 'price'] => is_required('Поле обязательно к заполнению'),
		cover => is_like( qr/^[a-zA-Z0-9\.\_\-\s]+$/, 'Имя файла содержит недопустимые символы' )
	],
}
