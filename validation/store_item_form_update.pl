use utf8;
{
	fields => [qw/id title cover description body categories price price_sale hidden items_more info_key info_val/],
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
		[ qw/id title price/ ] => is_required('Поле обязательно к заполнению')
	]
}
