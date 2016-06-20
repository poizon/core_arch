use utf8;
{
	fields => [ 'option','priority' ],
	checks => [
		['option', 'priority'] => is_required('Поле обязательно к заполнению'),
		priority => is_like( qr/^\d+$/, 'Ошибка' )
	],
}
