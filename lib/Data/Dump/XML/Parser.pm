package Data::Dump::XML::Parser;
#
#  Once upon a time this file was a part of ACIS software,
#  http://acis.openlib.org/
#
#  Description:
#
#	Parse an Data::Dump::XML-dumped XML string and recreate the
#	data structure.
#
#  This module is tightly related to Data::Dump::XML, which is
#  based on Data::DumpXML, and it is accordingly based on
#  Data::DumpXML::Parser.
# 
#   Copyright 2004-2009 Ivan Baktsheev
#   Copyright 2003 Ivan Baktsheev, Ivan Kurmanov
#   Copyright 1998-2003 Gisle Aas.
#   Copyright 1996-1998 Gurusamy Sarathy.
#
#  XXX use of GNU GPL here is questionable. 
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License, version 2, as
#  published by the Free Software Foundation.
# 
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
# 
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#
#  ---
#  $Id: Parser.pm,v 1.2 2009/06/07 09:18:35 apla Exp $
#  ---

use Class::Easy;

use Scalar::Util ();

use XML::LibXML::SAX;
use base qw(XML::LibXML::SAX);

use Data::Dump::XML;

sub new {
	my($class, %arg) = @_;
	#$arg{Style} = "Data::Dump::XML::ParseStyle";
	#$arg{Namespaces} = 0;
	
	Data::Dump::XML->new
		unless defined $Data::Dump::XML::INSTANCE;
	
	$arg{defaults} = {%$Data::Dump::XML::defaults};
	
	return bless \%arg, $class;
	#return $class->SUPER::new(%arg);
}

sub start_document {
	my $p = shift;
	
	$p->{dump}->{data} = undef;
	$p->{dump}->{stack} = [];
	push @{ $p->{dump}->{stack} }, \$p->{dump}->{data};
	
	$p->{dump}->{increment} = 0;
	
	$p->SUPER::start_document (@_);
}

sub start_element {
	my ($p, $element) = @_;
	
	my $d = $p->{defaults};
	
	my %attr = map {$_->{LocalName} => $_->{Value}}
		values %{$element->{Attributes}};
	my $tag  = $element->{LocalName};
	
	my $increment = \$p->{dump}->{increment};
	$$increment++;
	
	$p->{dump}->{max_depth} = $$increment;
	
	if ($$increment == 1) {
		# warn $tag;
		foreach (qw(ref_element hash_element array-element
			key-as-hash-element empty-array empty_hash undef)
		) {
			# TODO: make threadsafe
			$d->{$_} = $attr{$_} 
				if exists $attr{$_};
		}
	}
	
	my $key_as_hash_element = $d->{'key_as_hash_element'};
	my $root_name     = $d->{'root_name'};
	my $ref_element   = $d->{'ref_element'};
	my $array_element = $d->{'array_element'};
	my $hash_element  = $d->{'hash_element'};
	my $empty_array   = $d->{'empty_array'};
	my $undef         = $d->{'undef'};
	my $empty_hash    = $d->{'empty_hash'};
	
	my $blesser;
	$blesser = $p->{Blesser}
		if (exists $p->{Blesser} and ref($blesser) eq "CODE");
	
	
	my $attr = shift @{$p->{dump}->{attr}};
	my $parent_class = $attr->{class};
	my $parent_id    = $attr->{id};
	
	my $ref = $p->{'dump'}->{'stack'}->[-1];
	
	#my $defined_parent = 0;
	#$defined_parent = 1
	#	if  ref $p->{'dump'}->{'stack'}->[-1] eq 'SCALAR'
	#		and not defined ${$p->{'dump'}->{'stack'}->[-1]};
	
	push ( @{$p->{'dump'}->{'attr'}}, \%attr);
	
	if ($tag eq $root_name and $$increment == 1)# and not defined $ref) {
	{
	} elsif ($tag eq $array_element) {
		#$$ref = []
		#	if $defined_parent;
		
		###  check the data type
		die "'$tag' elements only appear in list elements" 
			unless not defined $$ref 
				or Scalar::Util::reftype ($$ref) eq 'ARRAY';
		
		push @{$$ref}, undef;
		push @{$p->{'dump'}->{'stack'}}, \($$ref->[-1]);
		
		$blesser ? &$blesser ($$ref, $parent_class) : bless ($$ref, $parent_class)
			if defined $parent_class;		  
		
	} elsif ($tag eq $ref_element) {
		my $value = undef;
		$$ref = \$value;
		
		$$ref = ${$p->{'dump'}->{'id'}->[$attr{'to'}]}
			if (defined $attr{'to'});
		
		push @{$p->{'dump'}->{'stack'}}, $$ref;
	
	} elsif ($tag eq $undef) {
	
		$$ref = undef;
		push @{$p->{'dump'}->{'stack'}}, undef;
	
	} elsif ($tag eq $empty_hash) {
	
		$$ref = {};
		push @{$p->{'dump'}->{'stack'}}, undef;
	
	} elsif ($tag eq $empty_array) {
	
		$$ref = [];
		push @{$p->{'dump'}->{'stack'}}, undef;
	
	} elsif ($key_as_hash_element
	  or ($tag eq $hash_element and exists $attr{'name'})) {
		#$$ref = {}
		#	if $defined_parent;
		
		my $key = $tag;
		$key = $attr{'name'}
			if exists $attr{'name'};
		
		die "hash element '$key' must appear in hash context" 
			unless not defined $$ref 
				or Scalar::Util::reftype ($$ref) eq 'HASH';
		
		unless (defined $$ref) {
			# copy all attributes except d:*
			foreach my $k (keys %$attr) {
				next if $k =~ /^d\:/;
				$$ref->{"\@$k"} = $attr->{$k}; 
			}
		}
		
		die "hash element '$key' already present" 
			if exists $$ref->{$key};
		$$ref->{$key} = undef;
		
		push @{$p->{dump}->{stack}}, \(${$ref}->{$key});
		
		$blesser ? &$blesser ($$ref, $parent_class) : bless ($$ref, $parent_class)
			if defined $parent_class;
	} else {
		warn "found unknown element $tag";
	}
	
	
	$p->{dump}->{char} = '';
	
	$p->{dump}->{id}->[$parent_id] = $ref
		if ($parent_id);
	
	$p->SUPER::start_element ($element);

}

sub characters {
	my ($p, $str) = @_;
	$p->{'dump'}->{'char'} .= $str->{'Data'}
		if defined $str->{'Data'} and $str->{'Data'} ne '';
	
	$p->SUPER::characters ($str);
}

sub end_element {
	my ($p, $element) = @_;
	
	my $d = $p->{defaults};
	
	my $tag   = $element->{'LocalName'};
	
	my $increment = \$p->{'dump'}->{'increment'};
	my $str = $p->{'dump'}->{'char'};
	my $ref = pop @{ $p->{'dump'}->{'stack'} };
	
	$p->{'dump'}->{'char'} = '';
	
	my $attr = $p->{'dump'}->{'attr'}->[0];
	my $attributed_keys = {map {$_ => $attr->{$_}} grep {!/^d\:/} keys %$attr};
	
	my $empty_array_item_as_hash = scalar keys %$attributed_keys;
	
	if( $$increment < $p->{dump}->{max_depth}) {
		#print ' 'x $$increment, "- this element had children\n";
	} elsif ($tag eq $d->{array_element} and $empty_array_item_as_hash) {
		$$ref->{'#text'} = $str
			if defined $str and $str ne '';

		foreach my $k (keys %$attributed_keys) {
			$$ref->{"\@$k"} = $attributed_keys->{$k}; 
		}

	} elsif ($tag ne $d->{'undef'}) {
		if ($tag eq $d->{ref_element} and $p->{'dump'}->{'attr'}->[0]->{'to'}) {
#	  print "'", $p->{'dump'}->{'attr'}->[0]->{'to'}, "'\n";
#	  my $place = $p->{'dump'}->{'attr'}->[0]->{'to'};
#	  
#	  $$ref = ${$p->{'dump'}->{'id'}->[$place]}
#	   if (defined $place);
	  
		} else {
			#print ' 'x $$increment, "element '$tag' holds a string value ('$str')\n";
			$$ref = $str;
		}
	}
	$$increment--;
	
	$p->SUPER::end_element ($element);
}

sub end_document {
	my $p = shift;
	my $data = $p->{'dump'}->{'data'};
	
	#$p->SUPER::end_document (@_);
	return $data;
}

1;

__END__

=head1 NAME

Data::Dump::XML::Parser - Restore data dumped by Data::DumpXML

=head1 SYNOPSIS

 use Data::Dump::XML::Parser;

 my $p = Data::Dump::XML::Parser->new;
 my $data = $p->parse_uri(shift || "test.xml");

=head1 DESCRIPTION

The C<Data::Dump::XML::Parser> is an C<XML::LibXML::SAX> subclass that
will recreate the data structure from the XML document produced by
C<Data::Dump::XML>.  The parserfile() method returns a reference
to an array of the values dumped.

The constructor method new() takes a single additional argument to
that of C<XML::LibXML::SAX> :

=over

=item Blesser => CODEREF

A subroutine that is invoked for blessing of restored objects.  The
subroutine is invoked with two arguments; a reference to the object
and a string containing the class name.  If not provided the built in
C<bless> function is used.

For situations where the input file cannot necessarily be trusted and
blessing arbitrary Classes might give the ability of malicious input
to exploit the DESTROY methods of modules used by the code it is a
good idea to provide an noop blesser:

  my $p = Data::Dump::XML::Parser->new(Blesser => sub {});

=back

=head1 SEE ALSO

L<Data::Dump::XML>, L<XML::LibXML::SAX>, L<Data::DumpXML::Parser>

=head1 AUTHORS

The C<Data::Dump::XML::Parser> module is written by Ivan
Baktsheev <dot.and.thing@gmail.com>, with support Ivan Kurmanov 
<kurmanov@openlib.og>.

Based on C<Data::DumpXML::Parser> written by Gisle Aas
<gisle@aas.no>.

 Copyright 2004-2009 Ivan Baktsheev
 Copyright 2003 Ivan Baktsheev, Ivan Kurmanov
 Copyright 2001 Gisle Aas.

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
