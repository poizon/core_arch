use utf8;
{
	fields => ['currency_code'],
	checks => [
		['currency_code'] => is_required('Поле обязательно к заполнению'),
		currency_code => is_like( qr/^\w{3}$/, 'Ошибка' )
	]
}