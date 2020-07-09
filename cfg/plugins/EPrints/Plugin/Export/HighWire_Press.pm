######################################################################
##
##  Export::HighWire_Press
##
##  This plug-in exports citation data in the HighWire Press format,
##  used for indexing by Google Scholar.
## 
#######################################################################
##
##  Copyright 2018 University of Zurich. All Rights Reserved.
##
##  Martin Brändle
##  Zentrale Informatik
##  Universität Zürich
##  Stampfenbachstr. 73
##  CH-8006 Zürich
##
##  The plug-ins are free software; you can redistribute them and/or modify
##  them under the terms of the GNU General Public License as published by
##  the Free Software Foundation; either version 2 of the License, or
##  (at your option) any later version.
##
##  The plug-ins are distributed in the hope that they will be useful,
##  but WITHOUT ANY WARRANTY; without even the implied warranty of
##  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##  GNU General Public License for more details.
##
##  You should have received a copy of the GNU General Public License
##  along with EPrints 3; if not, write to the Free Software
##  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
##
#######################################################################

=head1 NAME

EPrints::Plugin::Export::HighWire_Press - Plug-in for exporting citation
data, used for indexing by Google Scholar.

=cut

package EPrints::Plugin::Export::HighWire_Press;

use EPrints::Plugin::Export::TextFile;

use base 'EPrints::Plugin::Export::TextFile';

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "HighWire Press";
	$self->{accept} = [ 'dataobj/eprint' ];
	$self->{visible} = "";

	return $self;
}


sub output_dataobj
{
	my( $plugin, $dataobj ) = @_;

	my $data = $plugin->convert_dataobj( $dataobj );

	my $r = "";
	foreach( @{$data} )
	{
		next unless defined( $_->[1] );
		my $v = $_->[1];
		$v=~s/[\r\n]/ /g;
		$r.=$_->[0].": $v\n";
	}
	$r.="\n";
	return $r;
}

sub dataobj_to_html_header
{
	my( $plugin, $dataobj ) = @_;

	my $links = $plugin->{session}->make_doc_fragment;
	
	$links->appendChild( $plugin->{session}->make_element( "meta", 
		name => "gs_meta_revision",
		content => "1.1"
	));
	$links->appendChild( $plugin->{session}->make_text( "\n" ));

	my $hp = $plugin->convert_dataobj( $dataobj );
	foreach( @{$hp} )
	{
		$links->appendChild( $plugin->{session}->make_element(
			"meta",
			name => $_->[0],
			content => $_->[1],
			%{ $_->[2] || {} } ) );
		$links->appendChild( $plugin->{session}->make_text( "\n" ));
	}
	return $links;
}

	

sub convert_dataobj
{
	my( $plugin, $eprint ) = @_;

	my $dataset = $eprint->{dataset};
	my $session = $plugin->{session};

	my @hpdata = ();

	# GoogleScholar-required tags
	
	# Title
	push @hpdata, $plugin->simple_value( $eprint, title => "citation_title" );

	# Authors
	if ( $eprint->exists_and_set( "creators" ) )
	{
		my $creators = $eprint->get_value( "creators" );
		if( defined $creators )
		{
			foreach my $creator ( @{$creators} )
			{
				next if !defined $creator;
				push @hpdata, [ "citation_author", EPrints::Utils::make_name_string( $creator->{name} ) ];

				# UZH CHANGE ZORA-736 2020/03/05/mb add affiliations
				my $affiliation_ids = $creator->{affiliation_ids};
				if (defined $affiliation_ids)
				{
					my @afids = split( /\|/, $affiliation_ids );
					foreach my $afid (@afids)
					{
						my $affilobj = EPrints::DataObj::Affiliation::get_affilobj( $session, $afid );
						my $affiliation = $plugin->get_affiliation( $affilobj );
						push @hpdata, [ "citation_author_institution", $affiliation ];
					}
				}
				# END UZH CHANGE ZORA-736
			}
		}
	}

        if ( $eprint->exists_and_set( "editors" ) )
        {
                my $editors = $eprint->get_value( "editors" );
                if( defined $editors )
                {
                        foreach my $editor ( @{$editors} )
                        {
                                push @hpdata, [ "citation_author", EPrints::Utils::make_name_string( $editor->{name} ) ];

				# UZH CHANGE ZORA-736 2020/03/05/mb add affiliations
				my $affiliation_ids = $editor->{affiliation_ids};
				if (defined $affiliation_ids)
				{
					my @afids = split( /\|/, $affiliation_ids );
					foreach my $afid (@afids)
					{
						my $affilobj = EPrints::DataObj::Affiliation::get_affilobj( $session, $afid );
						my $affiliation = $plugin->get_affiliation( $affilobj );
						push @hpdata, [ "citation_author_institution", $affiliation ];
					}
				}
				# END UZH CHANGE ZORA-736
                        }
                }
        }

	# Publication date
	if ( $eprint->exists_and_set( "event_end" ) )
	{
		my $eventend = $eprint->get_value( "event_end" );
		if( defined $eventend )
		{
			$eventend =~ s/(-0+)+$//;
			$eventend =~ s/-/\//g;
			push @hpdata, [ "citation_publication_date", $eventend ];
		}
	}
	else 
	{
		if( $eprint->exists_and_set( "date" ) )
		{
			my $date = $eprint->get_value( "date" );
			if( defined $date )
			{
				$date =~ s/(-0+)+$//;
				$date =~ s/-/\//g;
				push @hpdata, [ "citation_publication_date", $date ];
			}
		}
	}

	# Journal title
	if ( $eprint->exists_and_set( "publication" ) )
	{
		push @hpdata, $plugin->simple_value( $eprint, publication => "citation_journal_title" );
	}
	elsif ( $eprint->exists_and_set( "series" ) )
	{
		push @hpdata, $plugin->simple_value( $eprint, series => "citation_journal_title" );
	}
	else
	{}

	# Volume
	if ( $eprint->exists_and_set( "volume" ) )
	{
		push @hpdata, $plugin->simple_value( $eprint, volume => "citation_volume" );
	}

	# Issue
	if ( $eprint->exists_and_set( "number" ) )
	{
		push @hpdata, $plugin->simple_value( $eprint, number => "citation_issue" );
	}

	# First and last page
	if ( $eprint->exists_and_set( "pagerange" ) )
	{
		my $pagerange = $eprint->get_value( "pagerange" );
		$pagerange =~ /^(.*?)\-(.*?)$/;
		if (defined $1 && defined $2 )
		{
			push @hpdata, [ "citation_firstpage", $1 ];
			push @hpdata, [ "citation_lastpage", $2 ];
		}
		else
		{
			push @hpdata, [ "citation_firstpage", $pagerange ];
		}
	}

	# PDF URL
	my @documents = $eprint->get_all_documents();
	foreach my $doc (@documents)
	{
		push @hpdata, [ "citation_pdf_url", $doc->get_url() ];
	}
	


	# Additional tags not required by Google Scholar
	# Publisher
	push @hpdata, $plugin->simple_value( $eprint, publisher => "citation_publisher" );

	# Keywords
	if ( $eprint->exists_and_set( "keywords" ) ) 
	{
		my $keywords = $eprint->get_value( "keywords" );
		$keywords =~ s/\r\n/ /g;
		$keywords =~ s/\r/ /g;
		$keywords =~ s/\n/ /g;
		push @hpdata, [ "citation_keywords", $keywords ];
	}
	
	# Language
	if ( $eprint->exists_and_set( "language_mult" ) )
	{
		foreach my $langid ( @{$eprint->get_value( "language_mult" )} )
		{
			push @hpdata, [ "citation_language", $langid ];
		}
	}

	# DOI
	if ( $eprint->exists_and_set( "doi" ) )
        {
                my $tmpdoi = EPrints::Utils::tree_to_utf8( $eprint->render_value( "doi" ) );
                $tmpdoi =~ s/^\s*//;
                $tmpdoi =~ s/\s*$//;
                push @hpdata, [ "citation_doi", $tmpdoi ];
        }

	# PubMed Id
        if ( $eprint->exists_and_set( "pubmedid" ) )
        {
                my $tmppubmed = EPrints::Utils::tree_to_utf8( $eprint->render_value( "pubmedid" ) );
                $tmppubmed =~ s/^\s*//;
                $tmppubmed =~ s/\s*$//;
                push @hpdata, [ "citation_pmid", $tmppubmed ];
        }

	# ISBN
        if ( $eprint->exists_and_set( "isbn" ) )
        {
                my $tmpisbn = EPrints::Utils::tree_to_utf8( $eprint->render_value( "isbn" ) );
                $tmpisbn =~ s/^\s*//;
                $tmpisbn =~ s/\s*$//;
                push @hpdata, [ "citation_isbn", $tmpisbn ];
        }

	# ISSN
        if ( $eprint->exists_and_set( "issn" ) )
        {
                my $tmpissn = EPrints::Utils::tree_to_utf8( $eprint->render_value( "issn" ) );
                $tmpissn =~ s/^\s*//;
                $tmpissn =~ s/\s*$//;
                push @hpdata, [ "citation_issn", $tmpissn ];
        }

	# Institution
	my $type = $eprint->get_value( "type" );
 	if ( $type eq 'dissertation' || $type eq 'habilitation' || $type eq 'masters_thesis' )
	{
		if ( $eprint->exists_and_set( "institution" ) )
		{
			push @hpdata, $plugin->simple_value( $eprint, institution => "citation_dissertation_institution" );
		}
	}

	# Abstract URL
	push @hpdata, [ "citation_abstract_html_url", $eprint->get_url() ];

	return \@hpdata;
}

# map eprint values directly into DC equivalents
sub simple_value
{
	my( $plugin, $eprint, $fieldid, $term ) = @_;

	my @hpdata;

	return () if !$eprint->exists_and_set( $fieldid );

	my $dataset = $eprint->dataset;
	my $field = $dataset->field( $fieldid );

	if( $field->isa( "EPrints::MetaField::Multilang" ) )
	{
		my( $values, $langs ) =
			map { $_->get_value( $eprint ) }
			@{$field->property( "fields_cache" )};
		$values = [$values] if ref($values) ne "ARRAY";
		$langs = [$langs] if ref($values) ne "ARRAY";
		foreach my $i (0..$#$values)
		{
			push @hpdata, [ $term, $values->[$i], { 'xml:lang' => $langs->[$i] } ];
		}
	}
	elsif( $field->property( "multiple" ) )
	{
		push @hpdata, map { 
			[ $term, $_ ]
		} @{ $field->get_value( $eprint ) };
	}
	else
	{
		push @hpdata, [ $term, $field->get_value( $eprint ) ];
	}

	return @hpdata;
}

# UZH CHANGE ZORA-736 2020/03/05/mb 
sub get_affiliation
{
	my( $plugin, $affilobj ) = @_;

	my $org = $affilobj->get_value( "name" );
	my $city = $affilobj->get_value( "city" );
	my $country = $affilobj->get_value( "country" );

	my $affiliation = $org;
	$affiliation .= ", " . $city if (defined $city);
	$affiliation .= ", " . $country if (defined $country);	

	return $affiliation;
}
# END UZH CHANGE ZORA-736

1;

=head1 AUTHOR

Martin Braendle <martin.braendle@uzh.ch>, Zentrale Informatik, University of Zurich

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2018- University of Zurich.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of the Export::HighWire_Press package based on 
EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
License for more details.

You should have received a copy of the GNU Lesser General Public
License along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END
