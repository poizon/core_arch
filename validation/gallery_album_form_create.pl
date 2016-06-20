use utf8;
{
	fields => ['title'],
	filters => [
		title => filter('trim', 'strip')
	],
	checks => [
		['title'] => is_required('Поле обязательно к заполнению'),
	]
}