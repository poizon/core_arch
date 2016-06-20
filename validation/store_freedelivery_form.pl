use utf8;
{
	fields => ['store_freedelivery'],
	checks => [
		['store_freedelivery'] => is_required('Поле обязательно к заполнению'),
		store_freedelivery => is_like( qr/^\d+$/, 'Ошибка' )
	]
}
