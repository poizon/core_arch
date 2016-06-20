use utf8;
{
	fields => ['id', 'album_id', 'title'],
	checks => [
		['id', 'album_id', 'title'] => is_required('Поле обязательно к заполнению')
	],
}