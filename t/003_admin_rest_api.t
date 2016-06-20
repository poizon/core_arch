#!/usr/bin/env perl

use strict;
use warnings;
use 5.010;

use Test::More;
use JSON::XS;
use Data::Dumper;

eval { require Furl } or plan skip_all => 'Not installed requred module: Furl';

my $ua = Furl->new();

my $ns_api = "admin/api";
my $base_url = "http://localhost:3000";

say "$base_url/$ns_api/pages";

my $res = $ua->get("$base_url/$ns_api/ping.json"); 
$res->is_success or plan skip_all => 'The app is not running or producing some errors';

# GET pages.json
$res = $ua->get("$base_url/$ns_api/pages.json");
ok $res->is_success, "GET /$ns_api/pages.json";
is $res->code, 200, '200 OK';
my $res_data;
eval { $res_data = decode_json $res->content };
ok ! $@, 'request got valid JSON data';
ok $res_data->{pages}, 'got pages';

# POST pages.json
$res = $ua->post("$base_url/ns_api/page.json")

done_testing();