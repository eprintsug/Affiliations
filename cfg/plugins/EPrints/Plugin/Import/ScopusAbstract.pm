######################################################################
#
#  Import::ScopusAbstract plugin - Import data from Scopus Abstract 
#  Retrieval API via Scopus eid or via DOI
#
#  Part of https://idbugs.uzh.ch/browse/ZORA-736
#
#  2019/11/27/mb
#  2020/03/10/mb improved author matching
#  2020/05/06/mb improved initials matching
#  
######################################################################
#
#  Copyright 2019- University of Zurich. All Rights Reserved.
#
#  Martin Brändle
#  Zentrale Informatik
#  Universität Zürich
#  Stampfenbachstr. 73
#  CH-8006 Zürich
#
#  The plug-ins are free software; you can redistribute them and/or modify
#  them under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  The plug-ins are distributed in the hope that they will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with EPrints 3; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#
######################################################################

=pod

=head1 NAME

EPrints::Plugin::Import::ScopusAbstract

=head1 DESCRIPTION

Imports data from Scopus Abstract Retrieval API via Scopus eid or via DOI
See https://dev.elsevier.com/documentation/AbstractRetrievalAPI.wadl for 
documentation of the API.

=head2 General structure of Scopus abstract-retrieval-response

=over 4

=item coredata  (for bibliographic core data)

=item affiliation(s)

=item author(s) - not used

=item language 

=item authkeywords - not used

=item subjectareas - scopus_subject

=item bibrecord - document type, authors, affiliations

=back

=head2 Imported Scopus data

=over 4

=item 1   coredata

=item 1.1 Scopus eid 

=item 1.2 pubmedid

=item 1.3 doi 

=item 1.4 volume

=item 1.5 number

=item 1.6 pagerange / 2.5 article number

=item 1.7 status

=back

=over 4
  
=item 2   bibrecord

=item 2.1 title 

=item 2.2 type / subtype

=item 2.3 issn    

=item 2.4 isbn

=item 2.5 article number

=item 2.6 book title

=item 2.7 event title

=item 2.8 event location

=item 2.9 event dates

=item 2.10 date

=item 2.11 publisher

=item 2.12 place of publication

=item 2.13 publication / series

=item 2.14 creators / affiliations

=item 2.15 editors / affiliations

=item 2.16 correspondence

=item 2.17 remaining contributors

=item 2.18 scopus subject areas

=item 2.19 language

=item 2.20 source
	
=back

=head2 Not allowed Scopus metadata
	
Scopus metadata that is not allowed to be imported according to policy:
https://dev.elsevier.com/policy.html , chapter
Scopus data in institutional repositories, research information systems, VIVO

=over 4

=item 3.1 abstract

=item 3.2 funding, grants (not mentioned in policy)

=back 

=head1 METHODS

=over 4

=cut 

package EPrints::Plugin::Import::ScopusAbstract;

use strict;
use warnings;
use utf8;

use EPrints;
use XML::LibXML;
use XML::LibXML::XPathContext;
use Locale::Country;
use Encode qw(encode decode);
use Text::Unidecode;

use EPrints::Plugin::Import::TextFile;
use URI;

use base 'EPrints::Plugin::Import::TextFile';

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{name} = "Scopus";
	$self->{visible} = "all";
	$self->{produce} = [ 'dataobj/eprint', 'list/eprint' ];
	$self->{screen} = "Import::Scopus";
	$self->{nolimit} = 0;

	return $self;
}

sub screen
{
	my( $self, %params ) = @_;

	return $self->{repository}->plugin( "Screen::Import::Scopus", %params );
}

=item $list = $plugin->input_text_fh( %opts )

Import one or more objects. Reads DOIs or Scopus eids passed via a filehandle ($opts{fh}),
retrieves the Scopus response from the Scopus Abstract Retrieval API using these parameters.

Returns a list of the imported objects.

=cut

sub input_text_fh
{
	my( $plugin, %opts ) = @_;

	my @ids;

 	my $use_prefix = $plugin->param( "use_prefix" );
	my $doi_field = $plugin->param( "doi_field" );
	my $scopus_abstract_api_url = $plugin->param( "api_url" );
	my $api_key = $plugin->param( "developer_id" );
	$use_prefix = 1 unless defined ( $use_prefix );
	$doi_field = "id_number" unless defined ( $doi_field );

	my $fh = $opts{fh};
	
	my $call_check_duplicate = 1;
	if (defined $opts{check_duplicate})
	{
		$call_check_duplicate = $opts{check_duplicate};
	}
	
	my $cd_plugin = $plugin->{session}->get_repository->plugin( "Import::CheckDuplicates" );
	$cd_plugin->{param}->{user} = $opts{user};
	
	NEWID: while( my $importid = <$fh> )
	{
		chomp $importid;
		$importid =~ tr/\x80-\xFF//d;
		$importid =~ s/^\s+//;
		$importid =~ s/\s+$//;
		
		# Only include prefix if config parameter set - Alan Stiles, Open University, 20140408
		if ( $use_prefix )
		{
			$importid =~ s/^(doi:)?/doi:/i;
		}
		else
		{
			$importid =~ s/^(doi:)?//i;
		}
		
		# Is it a DOI or a Scopus EID ?
		my $url;
		my $fieldname_dupcheck;
		if ( $importid =~ /^10\./ )
		{
			$url = "$scopus_abstract_api_url/doi/$importid?apiKey=$api_key";
			$fieldname_dupcheck = $doi_field;
		}
		elsif ( $importid =~ /2-s2\.0-/ )
		{
			$url = "$scopus_abstract_api_url/eid/$importid?apiKey=$api_key";
			$fieldname_dupcheck = "scopus_cluster";
		}
		else
		{
			$plugin->handler->message( "warning", $plugin->html_phrase( "incorrect_format",
				importid => $plugin->{session}->make_text( $importid )
			));
			next NEWID;
		}
		
		next NEWID if ($importid eq "");

		my $duplicate = 0;
		$duplicate = $cd_plugin->check_duplicate( $plugin, $fieldname_dupcheck, $importid ) if $call_check_duplicate;
		next NEWID if $duplicate;

		# Call Scopus Abstract Retrieval API
		my $scopus_data = {};
		$scopus_data = $plugin->submit_request($url);
		if (( !defined $scopus_data->{status} ) || ( $scopus_data->{status} ne "ok" ))
		{
			$plugin->handler->message( "warning", $plugin->html_phrase( "no_response",
				field => $plugin->html_phrase( "field_" . $fieldname_dupcheck ),
				importid => $plugin->{session}->make_text( $importid )
			));
			next;
		}
		
		# Get the parsed XML document
		my $doc = $plugin->get_parsed_doc( $scopus_data->{content} );
		
		# Do additional duplicate checks on retrieved eid, doi, pmid
		$duplicate = $plugin->check_duplicate( $doc, $cd_plugin, $doi_field );
		next if $duplicate;
		
		# Read XML formatted API response and push into epdata 
		my $epdata = $plugin->convert_input( $doc );

		next unless( defined $epdata );

		my $dataobj = $plugin->epdata_to_dataobj( $opts{dataset}, $epdata );
		if( defined $dataobj )
		{
			push @ids, $dataobj->get_id;
		}
	}

	return EPrints::List->new( 
		dataset => $opts{dataset}, 
		session => $plugin->{session},
		ids=>\@ids
	);
}

=item $epdata = $plugin->convert_input( $doc )

Parses the Scopus XML response in $doc and returns an eprints data object.

=cut 

sub convert_input
{
	my( $plugin, $doc ) = @_;
	
	# General structure of Scopus abstract-retrieval-response
	# - coredata  (for bibliographic core data)
	# - affiliation(s)
	# - author(s) - not used
	# - language 
	# - authkeywords - not used
	# - subjectareas - scopus_subject
	# - bibrecord - document type, authors, affiliations
	
	# 1   coredata
	# 1.1 Scopus eid 
	# 1.2 pubmedid
	# 1.3 doi 
	# 1.4 volume
	# 1.5 number
	# 1.6 pagerange / 2.5 article number
	# 1.7 status
	  
	# 2   bibrecord
	# 2.1 title 
	# 2.2 type / subtype
	# 2.3 issn    
	# 2.4 isbn
	# 2.5 article number
	# 2.6 book title
	# 2.7 event title
	# 2.8 event location
	# 2.9 event dates
	# 2.10 date
	# 2.11 publisher
	# 2.12 place of publication
	# 2.13 publication / series
	# 2.14 creators / affiliations
	# 2.15 editors / affiliations
	# 2.16 correspondence
	# 2.17 remaining contributors
	# 2.18 scopus subject areas
	# 2.19 language
	# 2.20 source
	
	
	# Scopus metadata that is not allowed to be imported according to policy:
	# https://dev.elsevier.com/policy.html , chapter
	# Scopus data in institutional repositories, research information systems, VIVO
	#
	# 3.1 abstract
	# 3.2 funding, grants? (not mentioned in policy, available in 
	#     item/xocs:meta/xocs:funding-list 
	#     item/bibrecord/head/grantlist 
	

	my $epdata = {};
	
	# 1.1 Scopus eid
	my $eid_nodes = $doc->findnodes( '/dn:abstracts-retrieval-response/dn:coredata/dn:eid' );
	
	foreach my $eid_node (@$eid_nodes)
	{
		$epdata->{scopus_cluster} = $eid_node->textContent();
	}
	
	# 1.2 pubmedid
	my $pubmedid_nodes = $doc->findnodes( '/dn:abstracts-retrieval-response/dn:coredata/dn:pubmed-id' );
	foreach my $pubmedid_node (@$pubmedid_nodes)
	{
		$epdata->{pubmedid} = $pubmedid_node->textContent();
	}
	
	# 1.3 doi
	my $doi_nodes = $doc->findnodes( '/dn:abstracts-retrieval-response/dn:coredata/prism:doi' );
	foreach my $doi_node (@$doi_nodes)
	{
		$epdata->{doi} = $doi_node->textContent();
	}
	
	# 1.4 volume
	my $volume_nodes =  $doc->findnodes( '/dn:abstracts-retrieval-response/dn:coredata/prism:volume' );
	foreach my $volume_node (@$volume_nodes)
	{
		$epdata->{volume} = $volume_node->textContent();
	}
	
	# 1.5 number
	my $issue_nodes = $doc->findnodes( '/dn:abstracts-retrieval-response/dn:coredata/prism:issueIdentifier' );
	foreach my $issue_node (@$issue_nodes)
	{
		$epdata->{number} = $issue_node->textContent();
	}
	
	# 1.6 pagerange / 2.5 article number
	my $pagerange_nodes = $doc->findnodes( '/dn:abstracts-retrieval-response/dn:coredata/prism:pageRange' );
	foreach my $pagerange_node (@$pagerange_nodes)
	{
		$epdata->{pagerange} = $pagerange_node->textContent();
	}
	
	if ( !defined $epdata->{pagerange} )
	{
		my $pagestart_nodes = $doc->findnodes( '/dn:abstracts-retrieval-response/dn:coredata/prism:startingPage' );
		foreach my $pagestart_node (@$pagestart_nodes)
		{
			$epdata->{pagerange} = $pagestart_node->textContent();
		}
	}
	
	if ( !defined $epdata->{pagerange} )
	{
		my $articlenumber_nodes = $doc->findnodes( '/dn:abstracts-retrieval-response/dn:coredata/dn:article-number' );
		foreach my $articlenumber_node (@$articlenumber_nodes)
		{
			$epdata->{pagerange} = $articlenumber_node->textContent();
		}
	}
	
	# 1.7 status
	$epdata->{status} = 'final';
	my $onlinestatus_nodes = $doc->findnodes( '/dn:abstracts-retrieval-response/item/xocs:meta/xocs:online-status' );
	foreach my $onlinestatus_node (@$onlinestatus_nodes)
	{
		my $online_status = $onlinestatus_node->textContent();
		if ( $online_status eq 'unavailable' )
		{
			$epdata->{status} = 'firstelectronic';
		}
	}
	
	
	# 2.1 title
	my $title_nodes = $doc->findnodes( '/dn:abstracts-retrieval-response/item/bibrecord/head/citation-title/titletext' );
	
	$epdata->{title} = "";
	
	my $notfirst = 0;
	foreach my $title_node (@$title_nodes)
	{
		$epdata->{title} .= ' : ' if $notfirst;
		$epdata->{title} .= $title_node->textContent();
		$notfirst = 1;
	}
	
    # 2.2 type / subtype
    # typemap is constructed both of citation type and source type
    my $typemap = {};
    
    $typemap->{ar}->{j} = 'article';
    $typemap->{ar}->{b} = 'book_section';
    $typemap->{ar}->{k} = 'book_section';
    $typemap->{ar}->{w} = 'newspaper_article';
    $typemap->{bk}->{b} = 'monograph';
    $typemap->{br}->{j} = 'article';
    $typemap->{ch}->{b} = 'book_section';
    $typemap->{ch}->{k} = 'book_section';
    $typemap->{cp}->{p} = 'conference_item';
 	$typemap->{di}->{b} = 'dissertation';
 	$typemap->{ed}->{j} = 'article';
 	$typemap->{er}->{j} = 'article';
 	$typemap->{le}->{j} = 'article';
 	$typemap->{no}->{j} = 'article';
 	$typemap->{re}->{j} = 'article';
 	$typemap->{rp}->{r} = 'published_research_report';
 	$typemap->{sh}->{j} = 'article';
 	$typemap->{wp}->{j} = 'working_paper';
 	
 	# subtypemap is constructed both of citation type and source type
 	my $subtypemap = {};
 	
 	$subtypemap->{ar}->{j} = 'original';
    $subtypemap->{ar}->{b} = 'original';
    $subtypemap->{ar}->{k} = 'original';
    $subtypemap->{ar}->{w} = 'original';
    $subtypemap->{bk}->{b} = 'original';
    $subtypemap->{br}->{j} = 'further';
    $subtypemap->{ch}->{b} = 'original';
    $subtypemap->{ch}->{k} = 'original';
    $subtypemap->{cp}->{p} = 'original';
 	$subtypemap->{di}->{b} = 'original';
 	$subtypemap->{ed}->{j} = 'further';
 	$subtypemap->{er}->{j} = 'further';
 	$subtypemap->{le}->{j} = 'further';
 	$subtypemap->{no}->{j} = 'further';
 	$subtypemap->{re}->{j} = 'further';
 	$subtypemap->{rp}->{r} = 'original';
 	$subtypemap->{sh}->{j} = 'further';
 	$subtypemap->{wp}->{j} = 'original';
    
    my $citation_type = $doc->findnodes( '/dn:abstracts-retrieval-response/item/bibrecord/head/citation-info/citation-type/@code' )->to_literal();
    my $source_type = $doc->findnodes( '/dn:abstracts-retrieval-response/item/bibrecord/head/source/@type' )->to_literal();
    if ( defined $typemap->{$citation_type}->{$source_type} )
    {
    	$epdata->{type} = $typemap->{$citation_type}->{$source_type};
    }
    else
    {
    	$epdata->{type} = 'article';
    }
    
    if ( defined $subtypemap->{$citation_type}->{$source_type} )
    {
    	$epdata->{subtype} = $subtypemap->{$citation_type}->{$source_type};
    }
    else
    {
    	$epdata->{subtype} = undef;
    }
  
    
    # 2.3 issn
	# order: electronic > print
	my $eissn_nodes = $doc->findnodes( '/dn:abstracts-retrieval-response/item/bibrecord/head/source/issn[@type = "electronic"]' );
	my $eissn;
	foreach my $eissn_node (@$eissn_nodes)
	{
		my $issn = $eissn_node->textContent();
		if (defined $issn)
		{ 
			$eissn = substr($issn,0,4) . '-' . substr($issn,4,4);
		}
	}
	
	my $pissn_nodes = $doc->findnodes( '/dn:abstracts-retrieval-response/item/bibrecord/head/source/issn[@type = "print"]' );
	my $pissn;
	foreach my $pissn_node (@$pissn_nodes)
	{
		my $issn = $pissn_node->textContent();
		if (defined $issn)
		{ 
			$pissn = substr($issn,0,4) . '-' . substr($issn,4,4);
		}
	}
	
	$epdata->{issn} = $pissn;
	$epdata->{issn} = $eissn;
	
	# 2.4 isbn
	# order: print > electronic
	my $eisbn_nodes = $doc->findnodes( '/dn:abstracts-retrieval-response/item/bibrecord/head/source/isbn[@type = "electronic"]' );
	my $eisbn;
	foreach my $eisbn_node (@$eisbn_nodes)
	{
		$eisbn = $eisbn_node->textContent();
	}
	
	my $pisbn_nodes = $doc->findnodes( '/dn:abstracts-retrieval-response/item/bibrecord/head/source/isbn[@type = "print"]' );
	my $pisbn;
	foreach my $pisbn_node (@$pisbn_nodes)
	{
		$pisbn = $pisbn_node->textContent();
	}
	
	$epdata->{isbn} = $eisbn;
	$epdata->{isbn} = $pisbn;
	
    # 2.5 article number see above
    # 2.6 book title for book section
    if ( $epdata->{type} eq 'book_section' )
    {
    	my $sourcetitle_nodes = $doc->findnodes( '/dn:abstracts-retrieval-response/item/bibrecord/head/source/sourcetitle' );
    	foreach my $sourcetitle_node (@$sourcetitle_nodes)
    	{
    		$epdata->{book_title} = $sourcetitle_node->textContent();
    	}
    }
    
    # 2.7 event title
    # 2.8 event location
    # 2.9 event dates
    if ( $epdata->{type} eq 'conference_item' )
    {
    	$epdata->{event_type} = 'conference';
    	
    	my $confname_nodes = $doc->findnodes( '/dn:abstracts-retrieval-response/item/bibrecord/head/source/additional-srcinfo/conferenceinfo/confevent/confname' );
    	foreach my $confname_node (@$confname_nodes)
    	{
    		$epdata->{event_title} = $confname_node->textContent();
    	}
    	
    	my $country;
    	my $state;
    	my $city;
    	my $location = "";
    	
    	my $conflocation_country_nodes = $doc->findnodes( '/dn:abstracts-retrieval-response/item/bibrecord/head/source/additional-srcinfo/conferenceinfo/confevent/conflocation/@country' );
    	foreach my $conflocation_country_node (@$conflocation_country_nodes)
    	{
    		$country = code2country( $conflocation_country_node->textContent(), LOCALE_CODE_ALPHA_3);
    	}
    	my $conflocation_city_nodes = $doc->findnodes( '/dn:abstracts-retrieval-response/item/bibrecord/head/source/additional-srcinfo/conferenceinfo/confevent/conflocation/city' );
    	foreach my $conflocation_city_node (@$conflocation_city_nodes)
    	{
    		$city = $conflocation_city_node->textContent();
    	}
    	my $conflocation_state_nodes = $doc->findnodes( '/dn:abstracts-retrieval-response/item/bibrecord/head/source/additional-srcinfo/conferenceinfo/confevent/conflocation/state' );
    	foreach my $conflocation_state_node (@$conflocation_state_nodes)
    	{
    		$state = $conflocation_state_node->textContent();
    	}
    	
    	$city = "" if ( !defined $city );
    	$state = "" if ( !defined $state );
    	$country = "" if ( !defined $country );
    	 
    	$location = join('_', $city, $state, $country);
    	$location =~ s/^_|_$|^\s|\s$//g;
    	$location =~ s/__/_/g;
    	$location =~ s/_/, /g;
  
  		$epdata->{event_location} = $location;
    
    	my $confdate_startdate_nodes = $doc->findnodes( '/dn:abstracts-retrieval-response/item/bibrecord/head/source/additional-srcinfo/conferenceinfo/confevent/confdate/startdate' );
    	foreach my $confdate_startdate_node (@$confdate_startdate_nodes)
    	{
    		my $year = $confdate_startdate_node->findvalue( './@year');
    		my $month = $confdate_startdate_node->findvalue( './@month');
    		my $day = $confdate_startdate_node->findvalue( './@day');
    		if (defined $year)
    		{
    			my $date = $year;
    			$date .= '-' . $month if (defined $month);
    			$date .= '-' . $day if (defined $day);
    			$epdata->{event_start} = $date;
    		}
    	}
    	
    	my $confdate_enddate_nodes = $doc->findnodes( '/dn:abstracts-retrieval-response/item/bibrecord/head/source/additional-srcinfo/conferenceinfo/confevent/confdate/enddate' );
    	foreach my $confdate_enddate_node (@$confdate_enddate_nodes)
    	{
    		my $year = $confdate_enddate_node->findvalue( './@year');
    		my $month = $confdate_enddate_node->findvalue( './@month');
    		my $day = $confdate_enddate_node->findvalue( './@day');
    		if (defined $year)
    		{
    			my $date = $year;
    			$date .= '-' . $month if (defined $month);
    			$date .= '-' . $day if (defined $day);
    			$epdata->{event_end} = $date;
    		}
    	}
    }
    
    # 2.10 date (unfortunately, only publication year is allowed)
    my $publicationyear_nodes = $doc->findnodes( '/dn:abstracts-retrieval-response/item/bibrecord/head/source/publicationdate/year' );
    foreach my $publicationyear_node (@ $publicationyear_nodes)
    {
    	$epdata->{date} = $publicationyear_node->textContent();
    }
    
    # 2.11 publisher
    my $publishername_nodes = $doc->findnodes( '/dn:abstracts-retrieval-response/item/bibrecord/head/source/publisher/publishername' );
    foreach my $publishername_node (@$publishername_nodes)
    {
    	$epdata->{publisher} = $publishername_node->textContent();
    }
    
    # 2.12 place of publication
    my $publishercity_nodes = $doc->findnodes( '/dn:abstracts-retrieval-response/item/bibrecord/head/source/publisher/affiliation/city' );
    foreach my $publishercity_node (@$publishercity_nodes)
    {
    	$epdata->{place_of_pub} = $publishercity_node->textContent();
    }
    
    # 2.13 publication / series
    if ( $epdata->{type} eq 'article' )
    {
    	my $sourcetitle_nodes = $doc->findnodes( '/dn:abstracts-retrieval-response/item/bibrecord/head/source/sourcetitle' );
    	foreach my $sourcetitle_node (@$sourcetitle_nodes)
    	{
    		$epdata->{publication} = $sourcetitle_node->textContent();
    	}
    }
    elsif ( $epdata->{type} eq 'conference_item' )
    {
    	my $confseriestitle_nodes = $doc->findnodes( '/dn:abstracts-retrieval-response/item/bibrecord/head/source/additional-srcinfo/conferenceinfo/confevent/confseriestitle' );
    	foreach my $confseriestitle_node (@$confseriestitle_nodes)
    	{
    		$epdata->{series} = $confseriestitle_node->textContent();
    	}
    }
    else
    {
    	my $sourcetitle_nodes = $doc->findnodes( '/dn:abstracts-retrieval-response/item/bibrecord/head/source/sourcetitle' );
    	foreach my $sourcetitle_node (@$sourcetitle_nodes)
    	{
    		$epdata->{series} = $sourcetitle_node->textContent();
    	}
    	
    	# if there is an issue title, use this one
    	my $issuetitle_nodes = $doc->findnodes( '/dn:abstracts-retrieval-response/item/bibrecord/head/source/issuetitle' );
    	foreach my $issuetitle_node (@$issuetitle_nodes)
    	{
    		$epdata->{series} = $issuetitle_node->textContent();
    	}
    }
    
	# 2.14 creators / affiliations
    my $creator_data = $plugin->get_author_data( $doc, $epdata );
    if (defined $creator_data)
    {
    	$epdata->{creators} = $creator_data;
    }
    
    # 2.15 editors / affiliations
    my $editor_data = $plugin->get_editor_data( $doc, $epdata );
    if (defined $editor_data)
    {
    	$epdata->{editors} = $editor_data;
    }
    
    # 2.16 correspondence
    $plugin->process_correspondence( $doc, $epdata->{creators} );
    $plugin->process_correspondence( $doc, $epdata->{editors} );
    
    # 2.17 remaining contributors
    my $corp_creators = [];
    my $collaboration_nodes = $doc->findnodes( '/dn:abstracts-retrieval-response/item/bibrecord/head/author-group/collaboration' );
    foreach my $collaboration_node (@$collaboration_nodes)
    {
    	my $collaboration_text_nodes = $collaboration_node->findnodes( './ce:text' );
    	foreach my $collaboration_text_node (@$collaboration_text_nodes)
    	{
    		my $collaboration_text = $collaboration_text_node->textContent();
 	    	push @$corp_creators, $collaboration_text if (defined $collaboration_text);
    	}
    }
    if (scalar @$corp_creators > 0)
    {
    	$epdata->{corp_creators} = $corp_creators;
    }
    
	# 2.18 scopus subject areas
	my $scopus_subject_areas = $plugin->get_subject_data( $doc );
	if (scalar @$scopus_subject_areas > 0)
	{
		$epdata->{scopussubjects} = $scopus_subject_areas;
	}
	
	# 2.19 language
	my $language_mult = [];
	my $citationlanguage_nodes = $doc->findnodes( '/dn:abstracts-retrieval-response/item/bibrecord/head/citation-info/citation-language' );
	foreach my $citationlanguage_node (@$citationlanguage_nodes)
	{
		my $language = $citationlanguage_node->findvalue( './@xml:lang' );
		$language =~ s/ger/deu/g;
		
		push @$language_mult, $language if (defined $language);
	}
	if (scalar @$language_mult > 0)
	{
		$epdata->{language_mult} = $language_mult;
	}
	
	
	# 2.20 source
	$epdata->{source} = "Scopus:" . $epdata->{scopus_cluster};
	
	return $epdata;
}

#
# Parses author data from author groups in Scopus metadata, including the affiliations
#
sub get_author_data
{
	my ($plugin, $node, $epdata) = @_;
	
	my $limit = 10000;
	if ($plugin->{nolimit} == 0)
	{
		$limit = $plugin->param( "importlimit" );
	}
	my $author_counter = 0;
	
	my $authordata = [];
	
	my $authorgroup_nodes = $node->findnodes( '/dn:abstracts-retrieval-response/item/bibrecord/head/author-group' );
   
	foreach my $authorgroup_node (@$authorgroup_nodes)
	{
		my $affiliation_nodes = $authorgroup_node->findnodes( 'affiliation' );
		my $affiliation_ids = $plugin->process_affiliations( $node, $affiliation_nodes ); 
		
		my $author_nodes = $authorgroup_node->findnodes( './author[@type = "auth"]|./author' );
		
		foreach my $author_node (@$author_nodes)
		{
			if (($limit) && ($author_counter >= $limit))
			{
				$authordata->[$author_counter]->{'name'}->{'family'} = "et al";
				$authordata->[$author_counter]->[$author_counter]->{'name'}->{'given'} = "?";
				$epdata->{'suggestions'} .= $plugin->phrase( "author_limit", limit => $limit );
				# warning only in screen/workflow; is there a current_user?
				if ($plugin->{session}->get_repository->current_user) 
				{
					my $limit_message = $plugin->{session}->make_doc_fragment;
					my $limit_warning = $plugin->{session}->make_text( $plugin->phrase("author_limit", limit => $limit ) );
					$limit_message->appendChild( $limit_warning );
					$plugin->handler->message( "warning", $limit_message );
				}
				last;
			}
			
			my $author_pos = '' . $author_node->findnodes( './@seq' )->to_literal();
			my $pos = $author_pos - 1;
			
			
			my $family = '' . $author_node->findnodes( './ce:surname' )->to_literal();
			my $given = '' . $author_node->findnodes( './ce:given-name' )->to_literal();
			
			# clean up given name (there may be cases such as "A.nton")
			if ( $given =~ /\p{Alpha}\.\p{Alpha}{2,}/ )
			{
				$given =~ s/(\p{Alpha})\.(\p{Alpha}{2,})/$1$2/g;
			}
			
			$given =~ s/\./ /g;
			$given =~ s/\s{2,}/ /g;
			$given =~ s/^\s|\s$//g;
			
			# given name may be missing - get from preferred name
			if ( $given eq '')
			{
				$given = '' . $author_node->findnodes( './preferred-name/ce:given-name' )->to_literal();
				$given =~ s/\./ /g;
				$given =~ s/\s{2,}/ /g;
				$given =~ s/^\s|\s$//g;
			}
			
			my $orcid = '' . $author_node->findnodes( './@sorcid' )->to_literal();
			
			$authordata->[$pos]->{'name'}->{'family'} = $family;
			$authordata->[$pos]->{'name'}->{'given'} = $given;
			$authordata->[$pos]->{'orcid'} = $orcid if (defined $orcid);
			
			# multiple affiliations 
			# has author already an affiliation from another author group? Then add it,
			# if not a duplicate
			if (defined $authordata->[$pos]->{affiliation_ids})
			{
				my $q_afid = qr/$affiliation_ids/;
				if ( $authordata->[$pos]->{affiliation_ids} !~ $q_afid )
				{ 
					$authordata->[$pos]->{affiliation_ids} .= '|' . $affiliation_ids;
				}
			}
			else
			{
				$authordata->[$pos]->{affiliation_ids} = $affiliation_ids if ($affiliation_ids ne "");
			}
			
			$author_counter++;
		}
	}
	
	return $authordata;
}

#
# Parse editor data, including affiliations
#
sub get_editor_data
{
	my ($plugin, $node, $epdata) = @_;
	
	my $limit = 10000;
	if ($plugin->{nolimit} == 0)
	{
		$limit = $plugin->param( "importlimit" );
	}
	my $editor_counter = 0;
	
	my $editordata = [];
		
	my $contributorgroup_nodes = $node->findnodes( '/dn:abstracts-retrieval-response/item/bibrecord/head/source/contributor-group' );
	
	foreach my $contributorgroup_node (@$contributorgroup_nodes)
	{
		my $affiliation_nodes = $contributorgroup_node->findnodes( './affiliation' );
		my $affiliation_ids = $plugin->process_affiliations( $node, $affiliation_nodes );
		
		my $editor_nodes = $contributorgroup_node->findnodes( './contributor[@role = "edit"]' );
    	
    	# this is slightly different than with get_author_data because @seq is reset
    	foreach my $editor_node (@$editor_nodes)
    	{
    		if (($limit) && ($editor_counter >= $limit))
			{
				$editordata->[$editor_counter]->{'name'}->{'family'} = "et al";
				$editordata->[$editor_counter]->[$editor_counter]->{'name'}->{'given'} = "?";
				$epdata->{'suggestions'} .= $plugin->phrase( "editor_limit", limit => $limit );
				# warning only in screen/workflow; is there a current_user?
				if ($plugin->{session}->get_repository->current_user) 
				{
					my $limit_message = $plugin->{session}->make_doc_fragment;
					my $limit_warning = $plugin->{session}->make_text( $plugin->phrase("editor_limit", limit => $limit ) );
					$limit_message->appendChild( $limit_warning );
					$plugin->handler->message( "warning", $limit_message );
				}
				last;
			}
    		
    		my $family = '' . $editor_node->findnodes( './ce:surname' )->to_literal();
			my $given = '' . $editor_node->findnodes( './ce:given-name' )->to_literal();
			$given =~ s/\./ /g;
			$given =~ s/^\s|\s$//g;
			
			$editordata->[$editor_counter]->{name}->{family} = $family;
			$editordata->[$editor_counter]->{name}->{given} = $given;
			
			# multiple affiliations 
			# has editor already an affiliation from another contributor group? Then add it, 
			# if not a duplicate
			if (defined $editordata->[$editor_counter]->{affiliation_ids})
			{
				my $q_afid = qr/$affiliation_ids/;
				if ( $editordata->[$editor_counter]->{affiliation_ids} !~ $q_afid)
				{
					$editordata->[$editor_counter]->{affiliation_ids} .= '|' . $affiliation_ids;
				}
			}
			else
			{
				$editordata->[$editor_counter]->{affiliation_ids} = $affiliation_ids if ($affiliation_ids ne "");
			}
			
			$editor_counter++;
    	}
	}
	
	return $editordata;
}

#
# Process the affiliation data. If you new affiliation has been found, add it to the
# affiliations dataset 
#
sub process_affiliations
{
	my ($plugin, $doc, $affil_nodes) = @_;
	
	my $affiliation_ids = "";
	
	my $notfirst = 0;
	
	foreach my $affil_node (@$affil_nodes)
	{
		my $afid = '' . $affil_node->findnodes( './@afid' )->to_literal();
		# in contributor-group, there may be affiliations without affiliaton id, skip those
		if (defined $afid)
		{
			my $countrycode = '' . $affil_node->findnodes( './@country' )->to_literal();
			
			# is affiliation already available in affiliation dataset ?
			my $exists_afid = $plugin->find_affiliation( $afid ); 
			if ( $exists_afid == 0 )
			{
				# no - create a new affiliation item
				my $organisation_name;
				my $city;
				my $country;
				
				# preferably take the normalized node
				my $normalized_affil_nodes = $doc->findnodes( '/dn:abstracts-retrieval-response/dn:affiliation[@id = "' . $afid . '"]' );
				
				if (defined $normalized_affil_nodes && scalar(@$normalized_affil_nodes) > 0 )
				{
					foreach my $normalized_affil_node (@$normalized_affil_nodes)
					{
						$organisation_name = '' . $normalized_affil_node->findnodes( './dn:affilname' )->to_literal();
						$city = '' . $normalized_affil_node->findnodes( './dn:affiliation-city' )->to_literal();
						$country = '' . $normalized_affil_node->findnodes( './dn:affiliation-country' )->to_literal();
					}
				}
				else
				{
					# otherwise the non-normalized affiliation
					my $organisation_parts = $affil_node->findnodes( './organization' );
					my $first = 0;
					$organisation_name = '';
					foreach my $organisation_part (@$organisation_parts)
					{
						$organisation_name .= ', ' if $first;
						$organisation_name .= $organisation_part->to_literal();
						$first = 1;
					}
					$city = $affil_node->findnodes( './city-group|./city' )->to_literal();
					$country = $affil_node->findnodes( './country' )->to_literal();
					
				}
				
				my $affiliation_data = {
					'primary_afid' => $afid,
					'primary_afid_type' => 'scopus',
					'name' => $organisation_name,
					'city' => $city,
					'country_code' => $countrycode,
					'country' => $country,
					'source' => "Scopus"
				};
				
				$plugin->create_affiliation( $affiliation_data );
			}
			
			# add affiliation id for linking to affiliation entry in EPrints
			# add only if it is not a duplicate
			my $q_afid = qr/$afid/; 
			if ($affiliation_ids !~ $q_afid )
			{
				$affiliation_ids .= "|" if $notfirst;
				$affiliation_ids .= $afid;
				$notfirst = 1;
			}
		}
	}
	
	return $affiliation_ids;
}

#
# Find an affiliation item in the affiliation dataset
#
sub find_affiliation
{
	my ($plugin, $search_afid) = @_;
	
	my $session = $plugin->{session};
	my $ds_affiliation = $session->get_repository->get_dataset( "affiliation" );
	
	my $afexp = EPrints::Search->new(
		session => $session,
		dataset => $ds_affiliation,
		order => "affiliationid",
	);
	
	$afexp->add_field(
		$ds_affiliation->get_field("primary_afid"),
		$search_afid,
		"EQ",
		"ANY",
	);
	
	$afexp->add_field(
		$ds_affiliation->get_field("primary_afid_type"),
		"scopus",
		"EQ",
		"ANY",
	);
	
	my $aflist = $afexp->perform_search();
	
	return $aflist->count();
}

#
# Create a new affiliation item in the affiliation dataset
#
sub create_affiliation
{
	my ($plugin, $affiliation_data) = @_;
	
	my $session = $plugin->{session};
	my $ds_affiliation = $session->get_repository->get_dataset( "affiliation" );
	
	my $affiliation_obj = $ds_affiliation->create_dataobj( $affiliation_data );
	$affiliation_obj->commit();
	
	return;
}

#
# Process the correspondence author and assign the correspondence flag to existing author/editor data
#
sub process_correspondence
{
	my ($plugin, $node, $contributors) = @_;
	
	my $correspondence_nodes = $node->findnodes( '/dn:abstracts-retrieval-response/item/bibrecord/head/correspondence/person' );
	foreach my $correspondence_node (@$correspondence_nodes)
	{
		my $family = '' . $correspondence_node->findnodes( './ce:surname' )->to_literal();
		my $given = '' . $correspondence_node->findnodes( './ce:given-name' )->to_literal();
		my $initials = '' . $correspondence_node->findnodes( './ce:initials' )->to_literal();
		
		$given =~ s/\./ /g;
		$given =~ s/^\s|\s$//g;
		$initials =~ s/\./ /g;
		$initials =~ s/^\s|\s$//g;
		
		# try to find a match with family and given or with family and initials
		my $match = 0;
		foreach my $contributor (@$contributors)
		{
			my $contributor_initials = $plugin->get_initials( $contributor->{'name'}->{'given'} );
			
			if ( $contributor->{'name'}->{'family'} eq $family && 
			    ( $contributor->{'name'}->{'given'} eq $given || $contributor_initials eq $initials ) ) 
			{
				$match = 1;
				$contributor->{'correspondence'} = "TRUE";
				last;
			}
		}
	}
	
	return;
}

#
# Return the Scopus subject areas. 
#
sub get_subject_data
{
	my ($plugin, $node) = @_;
	
	my $subject_data = [];
	
	my $subject_areas_nodes = $node->findnodes( '/dn:abstracts-retrieval-response/dn:subject-areas/dn:subject-area/@code' );
	foreach my $subject_areas_node (@$subject_areas_nodes)
	{
		push @$subject_data, "scopus" . $subject_areas_node->to_literal();
	}
	
	return $subject_data;
}


=item $success = $plugin->update_authors_subject( $eprint )

Update the author data (affiliations, correspondence) and Scopus subject areas for
an existing item. 

Returns the success flag (1 = successful) of the update.

=cut

sub update_authors_subject
{
	my ($plugin, $eprint) = @_;
	
	my $epdata = {};
	my $url;
	my $success = 0;
	my $update = 1;
	
	my $scopus_abstract_api_url = $plugin->param( "api_url" );
	my $api_key = $plugin->param( "developer_id" );
	
	# import all Scopus authors for matching
	$plugin->{nolimit} = 1;
	
	my $eid = $eprint->get_value( "scopus_cluster" );
	my $doi = $eprint->get_value( "doi" );
	if (defined $eid)
	{
		$url = "$scopus_abstract_api_url/eid/$eid?apiKey=$api_key";
	}
	elsif (defined $doi)
	{
		$url = "$scopus_abstract_api_url/doi/$doi?apiKey=$api_key";
	}
	else
	{
		return $success;
	}
	
	my $scopus_data = {};
	$scopus_data = $plugin->submit_request($url);
	if ((!defined $scopus_data->{status} ) || ( $scopus_data->{status} ne "ok" ))
	{
		$success = -1;
		return $success;
	}
	
	# Get parsed XML document
	my $doc = $plugin->get_parsed_doc( $scopus_data->{content} );

	# Read XML formatted API response and push into epdata 
	$epdata = $plugin->convert_input( $doc );
	
	if (defined $epdata->{scopussubjects})
	{
		$update = 1;
		$eprint->set_value( "scopussubjects", $epdata->{scopussubjects} );
	}
	
	
	if (defined $epdata->{creators} && scalar(@{$epdata->{creators}} > 0))
	{
		$update = 1;
		$plugin->match_author_data( $eprint, "creators", $epdata->{creators} )
	}
	
	if (defined $epdata->{editors} && scalar(@{$epdata->{editors}} > 0))
	{
		$update = 1;
		$plugin->match_author_data( $eprint, "editors", $epdata->{editors} )
	}
	
	if ( !defined $eid && defined $epdata->{scopus_cluster} )
	{
		$update = 1;
		$eprint->set_value( "scopus_cluster", $epdata->{scopus_cluster} );
	}
	
	if ( !defined $doi && defined $epdata->{doi} )
	{
		$update = 1;
		$eprint->set_value( "doi", $epdata->{doi} );
	}
	
	if ($update)
	{
		$success = $eprint->commit();
	}
	
	return $success;
}

#
# Match Scopus author data with existing eprint author data
# 
sub match_author_data
{
	my ($plugin, $eprint, $fieldname, $scopus_authors) = @_;
	
	my $session = $plugin->{session};
	my $eprint_authors = $eprint->get_value( $fieldname );
	my $org_exceptions = $plugin->param( "org_exceptions" );
	
	# double loop for matching (order of authors may differ)
	foreach my $eprint_author (@$eprint_authors)
	{
		my $e_family = lc($eprint_author->{name}->{family});
		my $e_given = lc($eprint_author->{name}->{given});
		my $e_initials = '';
		# do not take initials from $eprint_author->{index} (might have wrong value), 
		# but calculate from given name
		$e_initials = $plugin->get_initials( $e_given ) if defined $e_given;
		
		my $e_orcid = $eprint_author->{orcid};
		my $e_correspondence = $eprint_author->{correspondence};
		my $e_affiliation_ids = $eprint_author->{affiliation_ids};
		
		# strip all hyphen variants from double names
		$e_family =~ s/-|(\x{2010})|(\x{2011})|(\x{2012})|(\x{2013})|(\x{2014})/ /g;
		
		# strip all leading/trailing spaces
		$e_family =~ s/^\s+|\s+$//;
		
		# create umlaut 3 variants from EPrints
		my $is_umlaut3 = 0;
		my $e_family_uml3 = EPrints::Index::Tokenizer::apply_mapping( $session, $e_family);
		my $e_given_uml3 = EPrints::Index::Tokenizer::apply_mapping( $session, $e_given);
		my $e_initials_uml3 = lc($plugin->get_initials( $e_given_uml3 ));
		if ($e_family_uml3 ne $e_family || $e_given_uml3 ne $e_given)
		{
			$is_umlaut3 = 1;
		}
		
		# use Text::Unidecode as a last resort
		my $is_unidecode = 0;
		my $e_family_dec = unidecode( $e_family );
		my $e_given_dec = unidecode( $e_given );
		my $e_initials_dec = lc($plugin->get_initials( $e_given_dec ));
		if ($e_family_dec ne $e_family || $e_given_dec ne $e_given)
		{
			$is_unidecode = 1;
		}
		
		# double (or multiple) family names may be difficult, because Scopus puts only last name to family name
		my $is_double_name = 0;
		my $e_family_double;
		my $e_given_double;
		my $e_initials_double;
		if ( $e_family =~ /\s+/ )
		{
			$is_double_name = 1;
			$e_given_double = $e_given;
			my @e_family_parts = split( /\s/, $e_family );
			my $e_family_partcount = scalar( @e_family_parts );
			
			for (my $i = 0; $i < $e_family_partcount - 1; $i++ )
			{
				$e_given_double .= ' ' . $e_family_parts[$i];
			}
			
			$e_given_double =~ s/^\s+|\s+$//;
			
			$e_family_double = $e_family_parts[ $e_family_partcount - 1];
		}
		
		$e_initials_double = $plugin->get_initials( $e_given_double ) if $is_double_name;
		
		#
		# Scopus Author Loop
		#
		foreach my $scopus_author (@$scopus_authors)
		{
			my $s_family = lc($scopus_author->{name}->{family});
			my $s_given =  lc($scopus_author->{name}->{given});
			my $s_orcid = $scopus_author->{orcid};
			my $s_correspondence = $scopus_author->{correspondence};
			my $s_affiliation_ids = $scopus_author->{affiliation_ids};
			
			# strip all hyphen variants from double names
			$s_family =~ s/-|(\x{2010})|(\x{2011})|(\x{2012})|(\x{2013})|(\x{2014})/ /g;
			
			# move name particles such as "de", "von", "van" from given name to family name
			($s_family, $s_given) = $plugin->clean_name( $s_family, $s_given );
			
			my $s_initials = lc($plugin->get_initials( $s_given ));
			
			# create umlaut 1 variants from Scopus
			my $is_umlaut1 = 0;
			my $s_family_uml1 = $s_family;
			my $s_given_uml1 = $s_given;
			my $s_initials_uml1 = lc($plugin->get_initials( $s_given_uml1 ));
			
			if ($s_family_uml1 =~ /ä|ö|ü/)
			{ 
				$is_umlaut1 = 1;
				$s_family_uml1 =~ s/ä/ae/g;
				$s_family_uml1 =~ s/ö/oe/g;
				$s_family_uml1 =~ s/ü/ue/g;
			}
			
			if (defined $s_given_uml1 && $s_given_uml1 =~ /ä|ö|ü/)
			{ 
				$is_umlaut1 = 1;
				$s_given_uml1 =~ s/ä/ae/g;
				$s_given_uml1 =~ s/ö/oe/g;
				$s_given_uml1 =~ s/ü/ue/g;
			}
			
			# create reverse umlaut 2 variants from Scopus
			my $is_umlaut2 = 0;
			my $s_family_uml2 = $s_family;
			my $s_given_uml2 = $s_given;
			my $s_initials_uml2 = lc($plugin->get_initials( $s_given_uml2 ));
			
			if ($s_family_uml2 =~ /ae|oe|ue/)
			{ 
				$is_umlaut2 = 1;
				$s_family_uml2 =~ s/ae/ä/g;
				$s_family_uml2 =~ s/oe/ö/g;
				$s_family_uml2 =~ s/ue/ü/g;
			}
			
			if (defined $s_given_uml2 && $s_given_uml2 =~ /ae|oe|ue/)
			{ 
				$is_umlaut2 = 1;
				$s_given_uml2 =~ s/ae/ä/g;
				$s_given_uml2 =~ s/oe/ö/g;
				$s_given_uml2 =~ s/ue/ü/g;
			}
			
			# create umlaut 3 variants from EPrints
			my $s_family_uml3 = EPrints::Index::Tokenizer::apply_mapping( $session, $s_family );
			my $s_given_uml3 = EPrints::Index::Tokenizer::apply_mapping( $session, $s_given );
			my $s_initials_uml3 = lc($plugin->get_initials( $s_given_uml3 ));
			
			if ($s_family_uml3 ne $s_family || $s_given_uml3 ne $s_given)
			{
				$is_umlaut3 = 1;
			}
			
			# use Text::Unidecode as a last resort
			my $s_family_dec = unidecode( $s_family );
			my $s_given_dec = unidecode( $s_given );
			my $s_initials_dec = lc($plugin->get_initials( $s_given_dec ));
			
			if ($s_family_dec ne $s_family || $s_given_dec ne $s_given)
			{
				$is_unidecode = 1;
			}
			
			# skip match if author already matched
			next if (defined $eprint_author->{matched} && defined $scopus_author->{matched});
			
			my $match = 0;
			# ORCID match first
			if (defined $e_orcid && defined $s_orcid && $e_orcid eq $s_orcid)
			{
				$match = 1;
			}
			
			# exact match
			if (!$match && 
				$e_family eq $s_family &&
				defined $e_given && defined $s_given && $e_given eq $s_given )
			{
				$match = 1;
			}
			
			# umlaut 1 match
			if (!$match && $is_umlaut1 && 
				$e_family eq $s_family_uml1 &&
				defined $e_given && defined $s_given_uml1 && $e_given eq $s_given_uml1 )
			{
				$match = 1;
			}
			
			# umlaut 2 match
			if (!$match && $is_umlaut2 && 
				$e_family eq $s_family_uml2 &&
				defined $e_given && defined $s_given_uml2 && $e_given eq $s_given_uml2 )
			{
				$match = 1;
			}
	
			# umlaut 3 match
			if (!$match && $is_umlaut3 &&
				$e_family_uml3 eq $s_family_uml3 &&
				defined $e_given_uml3 && defined $s_given_uml3 && $e_given_uml3 eq $s_given_uml3 )
			{
				$match = 1;
			}
			
			# unidecode match
			if (!$match && $is_unidecode &&
				$e_family_dec eq $s_family_dec &&
				defined $e_given_dec && defined $s_given_dec && $e_given_dec eq $s_given_dec )
			{
				$match = 1;
			}
		
			# fuzzy match using initials
			if (!$match && 
				$e_family eq $s_family &&
				defined $e_initials && defined $s_initials && $e_initials eq $s_initials )
			{
				$match = 1;
			}
			
			# fuzzy umlaut 1 match using initials
			if (!$match && $is_umlaut1 && 
				$e_family eq $s_family_uml1 &&
				defined $e_initials && defined $s_initials_uml1 && $e_initials eq $s_initials_uml1 )
			{
				$match = 1;
			}
			
			# fuzzy umlaut 2 match using initials
			if (!$match && $is_umlaut2 && 
				$e_family eq $s_family_uml2 &&
				defined $e_initials && defined $s_initials_uml2 && $e_initials eq $s_initials_uml2 )
			{
				$match = 1;
			}
			
			# fuzzy umlaut 3 match using initials
			if (!$match && $is_umlaut3 &&
				$e_family_uml3 eq $s_family_uml3 &&
				defined $e_initials_uml3 && defined $s_initials_uml3 && $e_initials_uml3 eq $s_initials_uml3 )
			{
				$match = 1;
			}
			
			# fuzzy unidecode match using initials
			if (!$match && $is_unidecode &&
				$e_family_dec eq $s_family_dec &&
				defined $e_initials_dec && defined $s_initials_dec && $e_initials_dec eq $s_initials_dec )
			{
				$match = 1;
			}
			
			# double name matching
			if (!$match && $is_double_name &&
				$e_family_double eq $s_family &&  
				defined $e_given_double && defined $s_given && $e_given_double eq $s_given )
			{
				$match = 1;
			}
			
			# fuzzy double name matching
			if (!$match && $is_double_name &&
				$e_family_double eq $s_family &&  
				defined $e_initials_double && defined $s_initials && $e_initials_double eq $s_initials )
			{
				$match = 1;
			}
			
			if ($match)
			{
				$eprint_author->{matched} = 1;
				$scopus_author->{matched} = 1;
				if ( (!defined $e_orcid || $e_orcid eq '') && defined $s_orcid )
				{
					$eprint_author->{orcid} = $s_orcid;
				}
				
				if ( !defined $e_correspondence && defined $s_correspondence )
				{
					$eprint_author->{correspondence} = $s_correspondence;
				}
				
				if ( !defined $e_affiliation_ids && defined $s_affiliation_ids )
				{
					$eprint_author->{affiliation_ids} = $s_affiliation_ids;
				}
			}
		}
	}
		
	$eprint->set_value( $fieldname, $eprint_authors );
	
	# check if all authors had been matched and update suggestions
	my $suggestions_old = $eprint->get_value( "suggestions" );
	$suggestions_old = '' if ( !defined $suggestions_old );
	my $suggestions = ''; 
	my @suggestions_lines = split( /\n/ , $suggestions_old );
	foreach my $suggestion_line (@suggestions_lines)
	{
		if ( $suggestion_line !~ /${fieldname}:\sNo\sScopus\saffiliation\smatch/ )
		{
			$suggestions .= $suggestion_line . "\n";
		}
	}
	
	foreach my $eprint_author (@$eprint_authors)
	{
		my $e_family = $eprint_author->{name}->{family};
		my $e_given = $eprint_author->{name}->{given};

		my $suggestions_warning = "$fieldname: No Scopus affiliation match for $e_family, $e_given\n";
		
		if ( !defined $eprint_author->{affiliation_ids} || $eprint_author->{affiliation_ids} eq '' )
		{
			my $exception_flag = 0;
			foreach my $org_exception (@$org_exceptions)
			{
				if ( lc( $e_family ) =~ /$org_exception/ && $e_given eq '' )
				{ 
					$exception_flag = 1;
				}
			}
			
			if ( !$exception_flag )
			{
				$suggestions .= $suggestions_warning;
			}
		}
	}
	
	if ($suggestions ne $suggestions_old)
	{
		$eprint->set_value( "suggestions", $suggestions );
	}
	
	return;
}

#
# Return the initials of a given name.
#
sub get_initials
{
	my ($plugin, $given) = @_;
	
	my $initials = '';
	return $initials if not defined $given;
	return $initials if ($given eq '');

	# replace "." and the various "-" chars with spaces
	$given =~ s/(\.)|(\x{002D})|(\x{05BE})|(\x{2010})|(\x{2011})|(\x{2012})|(\x{2013})|(\x{2014})|(\x{2015})|(\x{2212})|(\x{FE63})|(\x{FF0D})/ /g;

	my @parts = split(/\s+/, $given);

	my $first = 1;
	foreach my $part (@parts)
	{
		if ($first)
		{
			$initials = substr($part,0,1);
			$first = 0;
		}
		else
		{
			$initials .= " " . substr($part,0,1);
		}
	}

	return $initials;
}


=item $scopus_data = $plugin->submit_request( $url )

Fetches a Scopus record given an Scopus Abstract Retrieval API url.

=cut

sub submit_request
{
	my ($plugin, $url) = @_;
	
	my $scopus_data = {};
	$scopus_data->{status} = "-1";
	
	print STDERR "Import via Scopus Abstract Retrieval API - url:[$url]\n" if $plugin->{param}->{verbose};
	my $req = HTTP::Request->new("GET",$url);
	$req->header( "Accept" => "text/xml" );
	$req->header( "Accept-Charset" => "utf-8" );
	$req->header( "User-Agent" => "ZORA Sync; EPrints 3.3.x; www.zora.uzh.ch" );
	
	my $ua = LWP::UserAgent->new;
	my $response = $ua->request($req);
	my $rc = $response->code;
	        
	return $scopus_data if (200 != $rc);
	
	$scopus_data->{status} = "ok";
	$scopus_data->{content} = $response->content; 
	
	return $scopus_data;
}

#
# Parses the Scopus Abstract Retrieval API response and returns an XML document.
#
sub get_parsed_doc
{
	my ($plugin, $node) = @_;
	
	my $parser = XML::LibXML->new();
	$parser->validation(0);
	my $doc = $parser->parse_string( $node );
	
	#
	# Attention:
	# the dn namespace uses the same URL as general namespace declaration of the Scopus response
	# in all XPath statements, therefore the dn: prefix must be used
	# <abstracts-retrieval-response 
	#   xmlns="http://www.elsevier.com/xml/svapi/abstract/dtd" 
	#   xmlns:dn="http://www.elsevier.com/xml/svapi/abstract/dtd" ...
	#
	# Also: on item node and subnodes, the namespace is reset, so no prefix must be used in 
	# XPath statement
	# <item xmlns="">
	#
	my $xpc = XML::LibXML::XPathContext->new( $doc );

	$xpc->registerNs( "dn", "http://www.elsevier.com/xml/svapi/abstract/dtd" );
	$xpc->registerNs( "ait", "http://www.elsevier.com/xml/ani/ait" );
	$xpc->registerNs( "ce", "http://www.elsevier.com/xml/ani/common" );
	$xpc->registerNs( "cto","http://www.elsevier.com/xml/cto/dtd" );
	$xpc->registerNs( "dc", "http://purl.org/dc/elements/1.1/" );
	$xpc->registerNs( "prism", "http://prismstandard.org/namespaces/basic/2.0/" );
	$xpc->registerNs( "xocs", "http://www.elsevier.com/xml/xocs/dtd" );
	$xpc->registerNs( "xsi", "http://www.w3.org/2001/XMLSchema-instance" );
	
	return $doc;
}

#
# Do additional duplicate checks on retrieved eid, pmid, doi
#
sub check_duplicate
{
	my ($plugin, $doc, $cd_plugin, $doi_field ) = @_;
	
	my $duplicate = 0;

	# 1.1 Scopus eid
	my $eid_nodes = $doc->findnodes( '/dn:abstracts-retrieval-response/dn:coredata/dn:eid' );
	
	foreach my $eid_node (@$eid_nodes)
	{
		my $scopus_eid = $eid_node->textContent();
		$duplicate = $cd_plugin->check_duplicate( $plugin, "scopus_cluster", $scopus_eid );
		return $duplicate if $duplicate;
	}
	
	# 1.2 pubmedid
	my $pubmedid_nodes = $doc->findnodes( '/dn:abstracts-retrieval-response/dn:coredata/dn:pubmed-id' );
	foreach my $pubmedid_node (@$pubmedid_nodes)
	{
		my $pmid = $pubmedid_node->textContent();
		$duplicate = $cd_plugin->check_duplicate( $plugin, "pubmedid", $pmid );
		return $duplicate if $duplicate;
	}
	
	# 1.3 doi
	my $doi_nodes = $doc->findnodes( '/dn:abstracts-retrieval-response/dn:coredata/prism:doi' );
	foreach my $doi_node (@$doi_nodes)
	{
		my $doi_check = $doi_node->textContent();
		$duplicate = $cd_plugin->check_duplicate( $plugin, $doi_field, $doi_check );
	}
	
	return $duplicate;
}

#
# Helper method, shift name parts such as van, van der ...
#
sub clean_name
{
	my ($plugin, $family, $given) = @_;
		
	my $family_clean = $family;
	my $given_clean = $given;
	
	# shift name parts
	if ( $given =~ /(.*?)\s(von)$/ || 
	     $given =~ /(.*?)\s(van)$/ || 
	     $given =~ /(.*?)\s(van\sde)$/ ||
	     $given =~ /(.*?)\s(van\sden)$/ ||
	     $given =~ /(.*?)\s(van\sder)$/ ||
	     $given =~ /(.*?)\s(de)$/ ||
	     $given =~ /(.*?)\s(da)$/ )
	{
		my $family_part = $2;
		$given_clean = $1;
		$family_clean = $family_part . ' ' . $family; 
	}
	
	# remove all . in given names
	$given_clean =~ s/\./ /g;
	$given_clean =~ s/^\s+|\s+$//g;
	
	return ($family_clean, $given_clean);
}


1;

=back

=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2019- University of Zurich.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

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

