package admin::forms;

use Dancer ':syntax';
use Helpers;

prefix '/admin/forms';

get '/' => sub {
	my @forms = quick_select(
		'form_info', {
			site_id  => vars->{site}->{site_id},
		}, {
			order_by => { desc => 'form_id' },
		}
	);
	
	return redirect '/admin/forms/add' unless @forms;

	template 'admin/forms/index', {
		forms => \@forms,
		title => loc('Формы')
	};
};

get '/add' => sub {
	template 'admin/forms/add', {
		title => loc('Создать форму')
	};
};

post '/add' => sub {
	my ($params, $form_params, $valid, $error) = validate_form();
	$valid or return template
		'admin/forms/add', {
			title => loc('Создать форму'),
			data  => $params,
			error => $error,
		};

	quick_insert('form_info', $form_params);
	my $form_id = last_insert_id();

	insert_qa($params, $form_id);
	redirect $params->{action} eq 'done' ? "/admin/forms/" : "/admin/forms/$form_id/edit";
};

get '/:form_id/edit' => sub {
	my $form = quick_select(
		'form_info', {
			form_id => params->{form_id},
			site_id => vars->{site}->{site_id},
		}
	);

	my $error;
	if ($form) {
		my @questions = quick_select(
			'form_questions', {
				form_id => params->{form_id},
			}, {
				order   => 'priority',
			}
		);

		my @q_ids = map { $_->{form_question_id} } @questions;
		my @options = quick_select(
			'form_question_options', {
				form_question_id => ( @q_ids ? \@q_ids : '' ),
			}, {
				order => 'priority',
			}
		);

		my $options;
		$options->{$_->{form_question_id}}->{$_->{priority}} = $_ for @options;
		$_->{options} = $options->{$_->{form_question_id}} for @questions;
		$form->{questions}->{$_->{priority}} = $_ for @questions;
	}
	else {
		$error = { common => loc('Ничего не найдено') };
	}

	template 'admin/forms/add', {
		data   => $form || {},
		title  => loc('Изменить'),
		error  => $error,
	};
};

post '/:form_id/edit' => sub {
	my $form = quick_select('form_info', {
		form_id => params->{form_id},
		site_id => vars->{site}->{site_id}
	});
	$form or return template 'admin/forms/add', {
		data  => $form || {},
		title => loc('Изменить'),
		error => { common => loc('Ничего не найдено') },
	};

	my ($params, $form_params, $valid, $error) = validate_form();
	$valid or return template
		'admin/forms/add', {
			title => loc('Создать форму'),
			data  => $params,
			error => $error,
		};

	quick_update(
		'form_info', {
			form_id => $form->{form_id},
		},
		$form_params
	);
	# quick_delete('form_questions', { form_id => $form->{form_id} });
	insert_qa($params, $form->{form_id});

	redirect $params->{action} eq 'done' ? "/admin/forms/" : "/admin/forms/$form->{form_id}/edit";
};

sub validate_form {
	my $params = params2hash({ params() });
	my $form_params = {
		name           => $params->{name},
		descr          => $params->{descr},
		reply_email    => $params->{reply_email},
		finish_message => $params->{finish_message},
		nocaptcha      => $params->{nocaptcha} ? 1 : 0,
		noindex        => $params->{noindex} ? 1 : 0,
		site_id        => vars->{site}->{site_id},
	};
	my $data = validator($form_params, 'forms_form_create.pl');
	my ($valid, $error) = ( $data->{valid}, $data->{result} );

	my $new_priority = 1;
	for my $priority (sort {$a <=> $b} keys %{$params->{questions}}) {
		my $q = $params->{questions}->{$priority};
		$q->{priority} = $new_priority++;
		$q->{is_required} = $q->{is_required} ? 1 : 0;

		my $data = validator($q, 'questions_form_create.pl');
		$valid &&= $data->{valid};
		$error->{questions}->{$q->{priority}} = $data->{result};

		my $new_opt_priority = 1;
		delete $q->{options} if ($q->{type} eq 'text' || $q->{type} eq 'textarea');
		for my $opt_priority (sort {$a <=> $b} keys %{$q->{options}}) {
			my $o = $q->{options}->{$opt_priority};
			$o->{priority} = $new_opt_priority++;

			my $data = validator($o, 'options_form_create.pl');
			$valid &&= $data->{valid};
			$error->{questions}->{$priority}->{options}->{$o->{priority}} = $data->{result};
		}
	}
	return ($params, $form_params, $valid, $error);
}

sub insert_qa {
	my ($params, $form_id) = @_;
	# always insert new questions and options
	# for my $priority (sort {$a <=> $b} keys %{$params->{questions}}) {
	# 	$params->{questions}->{$priority}->{form_id} = $form_id;
	# 	my $options = delete $params->{questions}->{$priority}->{options} || {};
	# 	quick_insert('form_questions', $params->{questions}->{$priority});
	# 	my $question = quick_select(
	# 		'form_questions', {
	# 			form_id  => $form_id,
	# 		}, {
	# 			order_by => { desc => 'form_question_id' },
	# 			limit	=> 1,
	# 		}
	# 	);
	# 	for my $opt_priority (sort {$a <=> $b} keys %{$options}) {
	# 		$options->{$opt_priority}->{form_question_id} = $question->{form_question_id};
	# 		quick_insert('form_question_options', $options->{$opt_priority});
	# 	}
	# }

	# insert or update questions and options
	my @questions_exist = quick_select(
		'form_questions', {
			form_id => $form_id,
		}, {
			order => 'priority',
		}
	);
	while (@questions_exist > keys %{$params->{questions}}) {
		my $q = shift @questions_exist;
		quick_delete('form_questions', { form_question_id => $q->{form_question_id} });
	}
	for my $priority (sort {$a <=> $b} keys %{$params->{questions}}) {
		$params->{questions}->{$priority}->{form_id} = $form_id;
		my $options = delete $params->{questions}->{$priority}->{options} || {};
		my $question;
		if (@questions_exist) {
			$question = shift @questions_exist;
			quick_update(
				'form_questions', {
					form_question_id => $question->{form_question_id},
				},
				$params->{questions}->{$priority},
			);
		}
		else {
			quick_insert('form_questions', $params->{questions}->{$priority});
			$question = quick_select(
				'form_questions', {
					form_id  => $form_id,
				}, {
					order_by => { desc => 'form_question_id' },
					limit    => 1,
				}
			);
		}

		my @options_exist = quick_select(
			'form_question_options', {
				form_question_id => $question->{form_question_id},
			}, {
				order => 'priority',
			}
		);
		while (@options_exist > keys %$options) {
			my $o = shift @options_exist;
			quick_delete('form_question_options', { form_question_option_id => $o->{form_question_option_id} });
		}
		for my $opt_priority (sort {$a <=> $b} keys %$options) {
			$options->{$opt_priority}->{form_question_id} = $question->{form_question_id};
			if (@options_exist) {
				my $o = shift @options_exist;
				quick_update(
					'form_question_options', {
						form_question_option_id => $o->{form_question_option_id},
					},
					$options->{$opt_priority},
				);
			}
			else {
				quick_insert('form_question_options', $options->{$opt_priority});
			}
		}
	}
}

true;
