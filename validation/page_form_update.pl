use utf8;
{
	fields => ['title', 'body', 'url', 'id', 'folder_id', 'action'],
	filters => [
		[ 'title', 'url' ] => filter('trim', 'strip'),
		folder_id => sub { $_[0] eq '' ? undef : $_[0]; }
	],
	checks => [
		['body', 'url', 'id'] => is_required('Поле обязательно к заполнению'),
	]
}