#!/usr/bin/perl

use Class::Easy;

use Data::Dumper;

use IO::Easy;

use Test::More qw(no_plan);

use_ok 'Data::Dump::XML';
use_ok 'Data::Dump::XML::Parser';

my $file_name = shift || 't/apple-pkg-contents.xml';
$file_name = 't/Data-Dump-XML/apple-pkg-contents.xml' 
	unless -f $file_name;

$Class::Easy::DEBUG = 'immediately';

my $dumper = Data::Dump::XML->new;
my $parser = Data::Dump::XML::Parser->new;

my $contents = IO::Easy->new ($file_name)->as_file->contents;
my $data;
my $xml;

$data = $parser->parse_string ($contents);
$xml = $dumper->dump_xml ($data);

# warn Dumper $data;

ok $data->{mysql}->{'@pt'} eq '/tmp/destroot/mysql/';
ok $data->{mysql}->{Library}->{LaunchDaemons}->{'com.mysql.mysqld.plist'}->{'@p'} eq 33188;

1;
