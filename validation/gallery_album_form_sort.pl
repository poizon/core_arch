use utf8;
{
	fields => ['ids'],
	filters => [
		ids => sub {
			my @list = split(',', $_[0]);
			return \@list;
		},
	],
	checks => [
		['ids'] => is_required('Поле обязательно к заполнению'),
	]
}
