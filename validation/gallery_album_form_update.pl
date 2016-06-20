use utf8;
{
	fields => ['cover_id', 'title', 'id', 'size', 'per_page'],
	filters => [
		['title', 'size', 'per_page'] => filter('trim', 'strip')
	],
	checks => [
		'id'   		=> is_required('Поле обязательно к заполнению'),
		'id'   		=> is_like( qr/^\d+$/, 'Ошибка' ),
		'size' 		=> is_like( qr/^\d+$/, 'Некорректное значение' ),
		'per_page'	=> is_like( qr/^\d+$/, 'Некорректное значение' ),
	]
}
