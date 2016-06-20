use utf8;
{
	fields => [qw/to_price country fee id/],
	filters => [
		[qw/country to_price fee/] => sub {
			ref $_[0] ? $_[0] : [$_[0]];
		}
	],
	checks => [
		[qw/country id/] => is_required('Поле обязательно к заполнению'),
		id => is_like( qr/^\d+$/, 'Ошибка' )
	]
}