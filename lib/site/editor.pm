package site::instant_editing;

use Dancer ':syntax';
use Helpers;

my $EDITING_MAP = {
	# table name => [ [ field_name1, field_type1] , ],
	blocks     => { id => 'place_id', fields => [ ['body', 'text'] ] },
	news       => { id => 'news_id',  fields => [ ['title', 'text'], ['body', 'text'], ['hidden', 'bool'] ] },
	blog_posts => { id => 'post_id',  fields => [ ['title', 'text'], ['body', 'text'], ['hidden', 'bool'] ] },
	pages      => { id => 'page_id',  fields => [ ['title', 'text'], ['body', 'text'], ['hidden', 'bool'], ['noindex', 'bool'], ] },
};

prefix '/instant_editing';

any ['get', 'post'] => '/update/?' => sub {
	content_type 'application/json';

	unless (vars->{site}->{user_id} == (session('user_id') || 0) || config->{environment} ne 'production') {
		return to_json { error => 'access denied' };
	}

	my $alias  = params->{alias} || '';
	my $field  = params->{field} || '';
	my $id     = params->{id}    || '';
	my $value  = params->{value} || '';

	return to_json { error => 'invalid alias' } unless $alias && $EDITING_MAP->{$alias};
	my @field_type = map { $_->[1] } grep { $_->[0] eq $field } @{ $EDITING_MAP->{$alias}->{fields} };

	return to_json { error => 'invalid field' } unless @field_type;

	$value = 0 if $field_type[0] eq 'bool' && !$value;

	my $id_name = $EDITING_MAP->{$alias}->{id};
	my $entity = quick_select(
		$alias, {
			$id_name => $id,
			site_id  => vars->{site}->{site_id},
		}
	);

	if ($entity) {
		quick_update(
			$alias, {
				$id_name => $id,
				site_id  => vars->{site}->{site_id},
			}, {
				$field   => $value,
			}
		);
	}
	else {
		quick_insert(
			$alias, {
				$id_name => $id,
				site_id  => vars->{site}->{site_id},
				$field   => $value,
			}
		);
	}

	return to_json { status => 'ok', value => $value };
};

# get '/load_form/?' => sub {
# 	my $alias  = params->{alias} || '';
# 	return to_json { error => 'invalid alias' } unless $alias && $EDITING_MAP->{$alias};

# 	# TODO: use template to generate form
# 	return to_json { fields => $EDITING_MAP->{$alias} };
# };

true;
