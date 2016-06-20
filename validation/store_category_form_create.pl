use utf8;
{
	fields => ['title', 'body', 'hidden', 'cover'],
	checks => [
		['title'] => is_required('Поле обязательно к заполнению'),
	],
}
