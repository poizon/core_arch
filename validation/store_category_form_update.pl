use utf8;
{
	fields => ['id', 'title', 'body', 'hidden', 'cover'],
	checks => [
			['id', 'title'] => is_required('Поле обязательно к заполнению'),
			id => is_like( qr/^\d+$/, 'Ошибка' )
	],
}