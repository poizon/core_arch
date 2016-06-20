use utf8;
{
	fields => ['id'],
	checks => [
		['id'] => is_required('Поле обязательно к заполнению'),
		id => is_like( qr/^\d+$/, 'Ошибка' ),
	]
}