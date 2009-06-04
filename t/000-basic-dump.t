#!/usr/bin/perl

use Class::Easy;

use Data::Dumper;

use Test::More qw(no_plan);

use_ok 'Data::Dump::XML';
use_ok 'Data::Dump::XML::Parser';

$Class::Easy::DEBUG = 'immediately';

my $dumper = Data::Dump::XML->new;

my $data = {a => 1, b => [3, 4, 5], c => {e => 15}};

my $t = timer ("dumping structure");

my $xml = $dumper->dump_xml ($data);

$t->end;

#diag Dumper $data;

#diag $xml->toString (1);

ok $xml->toString =~ m|<a>1</a><b><item>3</item><item>4</item><item>5</item>|;
ok $xml->toString =~ m|<c><e>15</e></c>|;

my $parser = Data::Dump::XML::Parser->new;

my $parsed = $parser->parse_string ($xml->toString);

# diag Dumper $parsed;



1;
