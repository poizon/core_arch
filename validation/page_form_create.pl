use utf8;
{
	fields => ['title', 'body', 'url', 'folder_id', 'action'],
	filters => [
		[ 'title', 'url' ] => filter('trim', 'strip')
	],
	checks => [
		[ 'title' ] => is_required('Поле обязательно к заполнению'),
		folder_id => is_like( qr/^\d+$/, 'Ошибка' )
	]
}