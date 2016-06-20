package site::forms;

use Dancer ':syntax';
use Helpers;
use Authen::Captcha;
use MIME::Base64;

my $captcha = Authen::Captcha->new(
	data_folder   => (config->{captcha}->{data}   || '/tmp'),
	output_folder => (config->{captcha}->{images} || '/tmp/img'),
);

prefix '/forms';

get '/:form_id/?' => sub {
	my $form = get_form(params->{form_id});
	status 404 unless $form;
	my $token = $captcha->generate_code(config->{captcha}->{length} || 5);
	render_template(
		'forms/item', {
			title   => $form->{name} || loc('Ничего не найдено'),
			data    => $form || {},
			status  => status,
			token   => $token,
			noindex => $form->{noindex},
		}
	);
};

post '/:form_id/?' => sub {
	my $form = get_form(params->{form_id});
	status 404 unless $form;

	if ($form->{nocaptcha}) {
		return redirect '/' if params->{url}; # filter bots
		return redirect '/' if params->{furry} ne 'kitten';
	}

	my $finish;
	if ($form) {
		$finish = 1;
		my $params = params2hash({ params() });
		for my $q (@{$form->{questions}}) {
			if ($q->{type} eq "text" || $q->{type} eq "textarea") {
				$q->{value}  = $params->{answers}->{$q->{priority}};
				if ($q->{is_required} && !$q->{value}) {
					$q->{error} = loc('Поле обязательно к заполнению');
					$finish = 0;
				}
			}
			elsif ($q->{type} eq "file") {
				$q->{file} = upload('answers.' . $q->{priority});
				if ($q->{is_required} && !$q->{file}) {
					$q->{error} = loc('Поле обязательно к заполнению');
					$finish = 0;
				}
				$q->{value} = $q->{file} ? loc('Файл загружен') : loc('Файл не загружен');
			}
			elsif ($q->{type} eq "radio" || $q->{type} eq "select") {
				my $ok = 0;
				my $active_option = $params->{answers}->{$q->{priority}};
				for my $o (@{$q->{options}}) {
					delete $o->{active};
					next unless $o->{priority} == $active_option;
					$o->{active} = $ok = 1;
					$q->{answer} = $o->{option};
				}
				unless ($ok) {
					$q->{error} = loc('Ошибка');
					$finish     = 0;
				}
			}
			elsif ($q->{type} eq "checkbox") {
				my $ok = 0;
				$q->{answer} = '';
				for my $opt_priority (sort {$a <=> $b} keys %{$params->{answers}->{$q->{priority}}}) {
					my $option = $q->{options}->[$opt_priority - 1];
					if ($option) {
						$option->{active} = $ok = 1;
						$q->{answer} .= " $option->{option}";
					}
				}
				if ($q->{is_required} && !$ok) {
					$q->{error} = loc('Поле обязательно к заполнению');
					$finish     = 0;
				}
			}
		}

		if (!$form->{nocaptcha}) {
			my $result = $captcha->check_code($params->{code}, $params->{token});
			if ($result != 1) {
				$form->{code_error} = loc('Ошибка');
				$finish = 0;
			}
		}
	}

	my $token;
	if ($finish) {
		my $attach = [];
		my $body = '<h4>' . $form->{name} . '</h4>';
		for my $q (@{$form->{questions}}) {
			if ($q->{file}) {
				my $file_name = '/tmp/' . $q->{question};
				$file_name =~ s/\s/_/g;
				my ($ext) = $q->{file}->tempname() =~ /(\.[^.]+)$/;
				$file_name .= $ext if $ext;
				utf8::encode($file_name);
				$q->{file}->copy_to($file_name);
				push(@$attach, $file_name);
			} else {
				$body .= "<p><strong>$q->{question}</strong></li>";
				$body .= "<p>" . ($q->{value} || $q->{answer}) . "</p>";
			}
		}
		my $sbj = $form->{name};
		utf8::encode($sbj);
		email {
			from    => config->{email},
			to      => $form->{reply_email},
			subject => '=?UTF-8?B?' . encode_base64($sbj) . '?=',
			body    => $body,
			type    => 'html',
			attach  => $attach,
		};
		unlink @$attach;
	}
	else {
		$token = $captcha->generate_code(config->{captcha}->{length} || 5);
	}

	render_template(
		'forms/item', {
			title   => $form->{name} || loc('Ничего не найдено'),
			data    => $form || {},
			finish  => $finish,
			status  => status,
			token   => $token,
			noindex => $form->{noindex},
		}
	);
};

get qr{/captcha/(?<file>\w+\.png)} => sub {
	my $file = config->{captcha}->{images} || '/tmp/img';
	$file .= '/' if '/' ne substr($file, -1);
	$file .= captures->{file};
	return send_file($file, system_path => 1) if -e $file;
	
	status 404;
	render_template 'index', {
		body => loc('Ничего не найдено')
	};
};

sub get_form {
	my ($id) = @_;
	my $form = quick_select(
		'form_info', {
			form_id => $id,
			site_id => vars->{site}->{site_id},
		}
	);

	if ($form) {
		my @questions = quick_select(
			'form_questions', {
				form_id => $id,
			}, {
				order => 'priority',
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
		push(@{ $options->{$_->{form_question_id}} }, $_) for @options;
		for (@questions) {
			$_->{options} = $options->{$_->{form_question_id}};
			$_->{options}->[0]->{active} = 1 if $_->{type} eq 'radio' && $_->{options} && @{$_->{options}};
		}
		$form->{questions} = \@questions;
	}
	return $form;
}

true;
