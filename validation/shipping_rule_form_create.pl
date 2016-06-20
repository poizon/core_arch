use utf8;
{
	fields => [qw/to_price country fee/],
	filters => [
		[qw/country to_price fee/] => sub { ref $_[0] ? $_[0] : [$_[0]]; }
	],
	checks => [
		['country'] => is_required('Поле обязательно к заполнению'),
	]
}