use utf8;
{
	fields => ['id', 'item_id', 'title'],
	filters => [
		'title' => sub { $_[0] ? $_[0] : ''; }
	],
	checks => [
		['id', 'item_id'] => is_required('Поле обязательно к заполнению')
	],
}
