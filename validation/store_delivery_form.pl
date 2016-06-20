use utf8;
{
	fields => [ qw/id title price body/ ],
	checks => [
		['title', 'price', 'body'] => is_required('Поле обязательно к заполнению'),
	],
}
