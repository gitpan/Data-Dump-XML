use ExtUtils::MakeMaker;

WriteMakefile(
	NAME => "Data::Dump::XML",
	VERSION_FROM => "lib/Data/Dump/XML.pm",
	'dist' => { COMPRESS=>"gzip", SUFFIX=>"gz" },
	AUTHOR => 'Ivan Baktsheev <dot.and.thing@gmail.com>',
	PREREQ_PM => {
		'Class::Easy'  => 0.02, # try_to_use support
		'XML::LibXML'  => 1.60,
		'Scalar::Util' => 1,
		'IO::Easy'     => 0.01,
	}
);
