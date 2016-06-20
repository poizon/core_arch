use utf8;

sub is_good_filename {
	my ($value, $params ) = @_;

	if ( !defined $value or $value eq '' ) {
		return;
	}

	my $error = 0;
	$error = 1 if $value =~ /\.\./;
	$error = 1 if $value =~ /\//;

	return 'Имя файла содержит недопустимые символы' if $error;
	return;
}

{
	fields => ['filename'],
	checks => [
		filename => [ is_required(), \&is_good_filename ],
	],
}
