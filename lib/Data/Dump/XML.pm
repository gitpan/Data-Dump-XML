package Data::Dump::XML;
# $Revision: 1.11 $
# $Id: XML.pm,v 1.11 2009/06/04 14:08:54 apla Exp $
# $Author: apla $

use Class::Easy;

use UNIVERSAL;

use XML::LibXML;

our $defaults = {
	# xml configuration
	'encoding'            => 'utf-8',
	'dtd-location'        => '',
	'namespace'           => {},
	
	# xml tree namespace
	'dump-config'         => 1,
	'root-name'           => 'data',
	'hash-element'        => 'key',
	'array-element'       => 'item',
	'ref-element'         => 'ref',
	'empty-array'         => 'empty-array',
	'empty-hash'          => 'empty-hash',
	'undef'               => 'undef',
	'key-as-hash-element' => 1,
	'@key-as-attribute'   => 1,
	
	# options
	'sort-keys'           => 0,
	
	# internal structure
	'doc-object'          => undef,
	'references'          => {},
	'ref-count'           => 0,
	'used'                => {},
};

our $VERSION = 1.11;

1;
############################################################
sub new {
	my $class   = shift;
	my $params  = {@_};
	
	my $config = \%$defaults;
	
	foreach my $key (keys %$params) {
		if (exists $config->{$key}) {
			$config->{$key} = $params->{$key};
		}
	}
	
	bless $config, $class;
	
	return $config;
}
############################################################
sub refs {
	my $self	= shift;
	my $address = shift;
	my $analyse = shift || 0;
	
	my $refs = $self->{'references'};
	
	return $refs->{$address}
		unless $analyse;
	
	if (defined $refs->{$address}) {
		$refs->{$address} = ++ $self->{'ref-count'}
			if $refs->{$address} == 0;
		return 1;
	} else {
		$refs->{$address} = 0;
		return 0;
	}
}
############################################################
sub analyze {
	my $self	  = shift;
	my $structure = shift;
	
	return unless defined $structure;
	
	return unless ref $structure;
	
	return unless "$structure" =~ /^(?:([^=]+)=)?([A-Z]+)\(0x([^\)]+)\)$/;
	
	my ($type, $address) = ($2, $3);
	
	unless ($self->refs ($address, 1)) {
		
		if (UNIVERSAL::isa($type, 'HASH')) {
			# warn "is hash";

			foreach (values %$structure) {
				$self->analyze ($_);
			}

		} elsif (UNIVERSAL::isa($type, 'ARRAY')) {
			# warn "is array";
			
			foreach (@$structure) {
				$self->analyze ($_);
			}
		} elsif (UNIVERSAL::isa($type, 'REF')) {
			# warn "is ref";
			$self->analyze ($$structure);
		}
	}
}
############################################################
sub dump_xml {
	my $self = shift;

	my $structure;

	if ( (scalar @_) == 1) {
		$structure = shift;
	} else {
		$structure = \@_;
	}
	
	my $dom = XML::LibXML->createDocument ('1.0', $self->{'encoding'});
	
	$self->{'doc-object'} = $dom;
	
	my $root;
	
	if ($self->{'dtd-location'} ne '') { 
		$dom->createInternalSubset ('data', undef, $self->{'dtd-location'});
	}
		
	$root = $dom->createElement ($self->{'root-name'});
		
	$dom->setDocumentElement ($root);
	
	# dump config options if any
	foreach (qw(ref-element hash-element array-element empty-array empty-hash undef key-as-hash-element)) {
		$root->setAttribute ($_, $self->{$_})
			if $self->{$_} ne $defaults->{$_};
	}
	
	if (scalar keys %{$self->{'namespace'}}) {
		foreach my $key (keys %{$self->{'namespace'}}) {
			$root->setAttribute ($key, $self->{'namespace'}->{$key});
			#debug "add '$key' namespace";
		}
	}
	
	$self->{'references'} = {};
	$self->{'ref-count'} = 0;
	$self->{'used'} = {};
	
	$self->analyze ($structure);
	
	#my $refs = $self->{'references'};
	#
	#foreach (keys %$refs)
	#{
	#	delete $refs->{$_} unless ($refs->{$_});
	#}
	
	$self->simple_dump ($structure);
	
	return $self->{'doc-object'};
	
}
############################################################
sub hiding {
	my $rval = shift;
	
	unless ("$rval" =~ /^(?:([^=]+)=)?([A-Z]+)\(0x([^\)]+)\)$/) {
		# $tag->appendText ('this structure cannot be dumped' . overload::StrVal($rval) );
		return;
	}
	
	return ($1, $2, $3);
}
############################################################
sub simple_dump {
	my $self  = shift;
	my $rval  = \$_[0]; shift;
	
	my $dom   = $self->{'doc-object'};

	my $tag   = shift || $dom->documentElement;
	my $deref = shift;

	$rval = $$rval if $deref;
	
	my $ref_element   = $self->{'ref-element'};
	my $array_element = $self->{'array-element'};
	my $hash_element  = $self->{'hash-element'};
	my $empty_array   = $self->{'empty-array'};
	my $undef         = $self->{'undef'};
	my $empty_hash    = $self->{'empty-hash'};
	
	my ($class, $type, $id) = hiding ($rval);
	
	if (defined $class) {
		if ($class eq 'XML::LibXML::Element') {
			
			if ($rval->localname eq 'include' and (
				$rval->lookupNamespacePrefix ('http://www.w3.org/2003/XInclude')
				or $rval->lookupNamespacePrefix ('http://www.w3.org/2001/XInclude')
			)) {
				#my $node = $tag->addNewChild ('', 'include');
				#$node->setNamespace ('http://www.w3.org/2003/XInclude', 'xi');
				#$node->setAttribute ('href', $rval->getAttribute ('href'));
				
				my $parser = XML::LibXML->new;
				$parser->expand_xinclude(0); # we try this later
				$parser->load_ext_dtd(0);
				$parser->expand_entities(0);
				
				my $include;
				eval {
					$include = $parser->parse_file ($rval->getAttribute ('href'));
				};
				#my $xinclude_result;
				#eval {$xinclude_result = $parser->process_xincludes ($include);};

				#debug "XInclude processing result is: $xinclude_result, error is: $@";
				
				$tag->addChild ($include->documentElement)
					if not $@ and defined $include;
			
			} else {
				$tag->addChild ($rval);
			}
			
			return;
		} elsif ($class ne '') {
			
			# TODO: make support for calling $rval->DUMP
			# to get structure for dumping
			
			#if ($rval->can ('TO_XML')) {
			#	$rval->TO_XML;
			#}

			$tag->setAttribute ('class', $class);
		}
	}
	
	if (my $ref_no = $self->refs ($id)) {
		if (defined $self->{'used'}->{$id}
			and $self->{'used'}->{$id} eq 'yea'
		) {
		  
			my $node = $tag->addNewChild ('', $ref_element);
			$node->setAttribute ('to', $ref_no);
			return;
		
		} else {
			
			$tag->setAttribute ('id', $ref_no);
			$self->{'used'}->{$id} = 'yea';
		
		}
	}
	
	if ($type eq "SCALAR" || $type eq "REF"){
		
		my $rval_ref = ref $$rval;
		
		if ($rval_ref) {
		
			if (($rval_ref eq 'SCALAR') or ($rval_ref eq 'REF')) {
			
				my $node = $tag->addNewChild ('', $ref_element);
				return $self->simple_dump ($$rval, $node, 1);
			}
	  
			return $self->simple_dump ($$rval, $tag, 1);
		
		} elsif (
			not defined $$rval and defined $rval 
			and defined $class and $class ne ''
		) {
			# regexp. 100% ?
			# debug "has undefined deref '$$rval' and defined '$rval'";
			$tag->addNewChild ('', $rval);
		
		} elsif (not defined $$rval) {
		
			$tag->addNewChild ('', $self->{'undef'});
		
		} else {	
		
			$tag->appendText ($$rval);
		
		}
		
		#debug $rval, $$rval, ref $rval, ref $$rval;
		
		return;
	} elsif ($type eq "ARRAY") {
		my @array;
		
		unless (scalar @$rval){
			$tag->addNewChild ('', $self->{'empty-array'});
			return;
		}
		
		my $level_up = 0;
		my $option_attr = $tag->getAttribute ('option');
		if (defined $option_attr and $option_attr eq 'level-up') {
			$level_up = 1;
		}
		
		my $idx = 0;
		my $tag_name = $tag->nodeName;
		# debug "tag mane is : $tag_name, level up is : $level_up";
		
		foreach (@$rval) {
			my $node;
			if ($level_up) {
				if ($idx) {
					$node = $tag->parentNode->addNewChild ('', $tag_name);
				} else {
					$node = $tag;
					$tag->removeAttribute ('option');
				}
				# $tag->setAttribute ('idx', $idx);
			} else {
				$node = $tag->addNewChild ('', $array_element);
			}
			
			$idx++;
			$self->simple_dump ($_, $node);
		}
		
		return;
	} elsif ($type eq "HASH") {
	
		unless (scalar keys %$rval) {
		
			$tag->addNewChild ('', $self->{'empty-hash'});
			return;
		}
		
		foreach my $key (sort keys %$rval) {
		
			my $val = \$rval->{$key};
			
			# warn "key: $key, value: $val\n";
			
			my $node;
			if ($key =~ /^(\<)?([^\d\W][\w-]*)$/) {
				if (
					$self->{'key-as-hash-element'}
					and $key ne $array_element # for RSS
					and $key ne $hash_element
					and $key ne $ref_element
					and $key ne $empty_array
					and $key ne $empty_hash
					and $key ne $undef
					#and $key ne $self->{'root-name'}
				) {
					$node = $tag->addNewChild ('', $2);
					# debug "child name: $2";
					if (defined $1 and $1 eq '<') {
						$node->setAttribute ('option', 'level-up'); 
					}
				}
			
			} elsif (
				$key =~ /^\@([^\d\W][\w-]*)$/ and $self->{'@key-as-attribute'}	
			) {
				my $attr_name = $1;
				my ($class, $type, $id) = hiding ($$val);
				# TODO: make something with values other than scalar ref
				unless (defined $type) {
					$tag->setAttribute ($attr_name, $$val);
					next;
				}
			} elsif ($key =~ /^\#text$/) {
				my ($class, $type, $id) = hiding ($$val);
				unless (defined $type) {
					$tag->appendText ($$val);
					next;
				}
			} else {
			
			
				$node = $tag->addNewChild ('', $self->{'hash-element'});
				$node->setAttribute ('name', $key);
			}

			$self->simple_dump ($$val, $node);
		}
	
		return;
	
	} elsif ($type eq "GLOB") {

		$tag->addNewChild ('', 'glob');
		return;

	} elsif ($type eq "CODE") {

		$tag->addNewChild ('', 'code');
		return;

	} else {
		my $comment = $dom->createComment ("unknown type: '$type'");
		$tag->addChild ($comment);
		return;
	}
	
	die "Assert";
}
############################################################

__END__

=head1 NAME

Data::Dump::XML - Dump arbitrary data structures
as XML::LibXML object

=head1 SYNOPSIS

 use Data::Dump::XML;
 my $dumper = Data::Dump::XML->new;
 $xml = $dumper->dump_xml (@list);

=head1 DESCRIPTION

This module completely rewritten from Gisle Aas
C<Data::DumpXML> to manage perl structures in XML using
interface to gnome libxml2 (package XML::LibXML).
Module provides a single method called dump_xml
that takes a list of Perl values as its argument.
Returned is an C<XML::LibXML::Document> object that represents
any Perl data structures passed to the function. Reference
loops are handled correctly.

Compatibility with Data::DumpXML is absent.

As an example of the XML documents produced, the following
call:

  $a = bless {a => 1, b => {c => [1,2]}}, "Foo";
  $dumper->dump_xml($a)->toString (1);

produces:

  <?xml version="1.0" encoding="utf-8"?>
  <data class="Foo">
  	<a>1</a>
  	<b>
  		<c>
			<item>1</item>
			<item>2</item>
		</c>
	</b>
  </data>

Comparing to Data::DumpXML this module generates noticeably
more simple XML tree, based on assumption that links in perl
can be defined in implicit way, i.e.:
explicit: $a->{b}->{c}->[1];
implicit: $a->{b} {c} [1];

And make possible similar xpath expressions:
/data/b/c/*[count (preceding-sibling) = 1]

C<Data::Dump::XML::Parser> is a class that can restore
data structures dumped by dump_xml().


=head2 Configuration variables

The generated XML is influenced by a set of configuration
variables. If you modify them, then it is a good idea to
localize the effect. For example:

	my $dumper = new Data::Dump::XML {
		# xml configuration
		'encoding'            => 'utf-8',
		'dtd-location'        => '',
		'namespace'           => {},

		# xml tree namespace
		'dump-config'         => 1,
		'root-name'           => 'data',
		'hash-element'        => 'key',
		'array-element'       => 'item',
		'ref-element'         => 'ref',
		'empty-array'         => 'empty-array',
		'empty-hash'          => 'empty-hash',
		'undef'               => 'undef',
		'key-as-hash-element' => 1,

		# options
		'sort-keys'           => 0,
	}

Data::DumpXML is function-oriented, but this module is rewritten
to be object-oriented, thus configuration parameters are passed
as hash into constructor.

The variables are:

=over

=item encoding

Encoding of produced document. Default - 'utf-8'.

=item dtd-location

This variable contains the location of the DTD.  If this
variable is non-empty, then a <!DOCTYPE ...> is included
in the output.  The default is "". Usable with
L<key-as-hash-element> parameter.

=item namespace

This hash contains the namespace used for the XML elements.
Default: disabled use of namespaces.

Namespaces provides as full attribute name and location. 
Example:

	...
	'namespace' => {
		'xmlns:xsl' => 'http://www.w3.org/1999/XSL/Transform',
		'xmlns:xi'  => 'http://www.w3.org/2001/XInclude',
	}
	...

=item root-name

This parameter define name for xml root element.

=item hash-element, array-element ref-element

This parameters provides names for hash, array items and
references.

Defaults:

	...
	'hash-element'  => 'key',
	'array-element' => 'item',
	'ref-element'   => 'ref',
	...

=item key-as-hash-element

When this parameter is set, then each hash key,
correspondending regexp /^(?:[^\d\W]|:)[\w:-]*$/ dumped as:

	<$keyname>$keyvalue</$keyname>

	instead of 

	<$hashelement name="$keyname">$keyvalue</$hashelement>

=back

=head2 XML::LibXML Features

When dumping XML::LibXML::Element objects, it added by
childs to current place in document tree. 

=head1 BUGS

The content of globs and subroutines are not dumped.  They are
restored as the strings "** glob **" and "** code **".

LVALUE and IO objects are not dumped at all.  They simply
disappear from the restored data structure.

=head1 SEE ALSO

L<Data::DumpXML>, L<XML::Parser>, L<XML::Dumper>, L<Data::Dump>, L<XML::Dump>

=head1 AUTHORS

The C<Data::Dump::XML> module is written by
Ivan Baktsheev <dot.and.thing@gmail.com>, based on C<Data::DumpXML>.

The C<Data::Dump> module was written by Gisle Aas, based on
C<Data::Dumper> by Gurusamy Sarathy <gsar@umich.edu>.

 Copyright 2003-2009 Ivan Baktcheev.
 Copyright 1998-2003 Gisle Aas.
 Copyright 1996-1998 Gurusamy Sarathy.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
