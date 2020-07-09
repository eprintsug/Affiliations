=head1 NAME

EPrints::Plugin::Export::DataCiteXML

=cut

package EPrints::Plugin::Export::DataCiteXML;

use EPrints::Plugin::Export::XMLFile;
use base 'EPrints::Plugin::Export::XMLFile';

use strict;
use utf8;

sub new
{
	my( $class, %opts ) = @_;

	my( $self ) = $class->SUPER::new( %opts );

	$self->{name} = "DataCite XML (4.3)";
	$self->{accept} = [ 'dataobj/eprint' ];
	$self->{visible} = "all";
	$self->{qs} = 0.8;
	$self->{suffix} = ".xml";
	$self->{mimetype} = 'application/xml; charset=utf-8';
	$self->{arguments}->{hide_volatile} = 1;
	$self->{arguments}->{doi} = undef;

	return $self;
}

sub output_dataobj
{
	my ($self, $dataobj, %opts) = @_;

	my $repo = $self->{repository};
	my $xml = $repo->xml;
    
    #reference the datacite schema from config
	my $entry = $xml->create_element( "resource",
		"xmlns" => $repo->get_conf( "datacitedoi", "xmlns"),
		"xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance",
		"xsi:schemaLocation" => $repo->get_conf( "datacitedoi", "schemaLocation")
	);

# UZH CHANGE ZORA-648 2018/03/28/mb use internal method for DOI
#    #RM We pass in the DOI from Event::DataCite... or from --args on the cmd line
#
#    # AH my $thisdoi = $opts{doi}; always returns undefined, even when DOI exists
#    # Ideally coining should NOT happen in this script but opts{doi} should have it
#    # but is always blank
#    my $thisdoi = $dataobj->get_value("id_number");
#    #RM coin a DOI if either
#            # - not come via event or
#            # - no doi arg passed in via cmd_line
#    # ie when someone exports DataCiteXML from the Action tab
#    if(!defined $thisdoi){
#            #nick the coining sub from event plugin
#            my $event = $repo->plugin("Event::DataCiteEvent");
#            $thisdoi = $event->coin_doi($repo, $dataobj);
#            #coin_doi may return an event error code if no prefix present assume this is the case
#            my $prefix = $repo->get_conf( "datacitedoi", "prefix");
#            return $thisdoi if($thisdoi !~ /^$prefix/);
#    }

	my $doi = $self->coin_doi( $repo, $dataobj );
	$entry->appendChild( $xml->create_data_element( "identifier", $doi, identifierType=>"DOI" ) );
    
    # UZH comment: This loop is quite inefficient because many fields are not used
	foreach my $field ( $dataobj->{dataset}->get_fields )
	{
		my $mapping_fn = "datacite_mapping_" . $field->get_name;

    	# UZH CHANGE ZORA-648 2018/03/2/mb value checking done in mapping method
		# if ( $repo->can_call($mapping_fn) && $dataobj->exists_and_set($field->get_name) )
		if ( $repo->can_call($mapping_fn) )
		{
			my $mapped_element = $repo->call( $mapping_fn, $xml, $dataobj, $repo, $dataobj->value( $field->get_name ) );
			$entry->appendChild( $mapped_element ) if (defined $mapped_element);
		}
	}
    
    # UZH CHANGE ZORA-648 2018/03/28/mb
    # There are no field for related identifiers, sizes, formats and rights at eprint level so we derive 
    # them from document metadata
	# As such we need to call our derivation routines outside the above loop
	if ( $repo->can_call("datacite_mapping_related_identifiers_from_docs") )
	{
		my $mapped_element = $repo->call( "datacite_mapping_related_identifiers_from_docs", $xml, $dataobj, $repo );
		$entry->appendChild( $mapped_element ) if(defined $mapped_element);
	}
	
	if ( $repo->can_call("datacite_mapping_sizes_from_docs") )
	{
		my $mapped_element = $repo->call( "datacite_mapping_sizes_from_docs", $xml, $dataobj, $repo );
		$entry->appendChild( $mapped_element ) if(defined $mapped_element);
	}
	
	if ( $repo->can_call("datacite_mapping_formats_from_docs") )
	{
		my $mapped_element = $repo->call( "datacite_mapping_formats_from_docs", $xml, $dataobj, $repo );
		$entry->appendChild( $mapped_element ) if(defined $mapped_element);
	}
	# END UZH CHANGE ZORA-648
	
	if ( $repo->can_call("datacite_mapping_rights_from_docs") )
	{
		my $mapped_element = $repo->call( "datacite_mapping_rights_from_docs", $xml, $dataobj, $repo );
		$entry->appendChild( $mapped_element ) if(defined $mapped_element);
    }

	return '<?xml version="1.0" encoding="UTF-8"?>' . "\n" . $xml->to_string($entry);
}

#
# UZH CHANGE ZORA-648 - part of coin_doi method taken from DataCiteEvent Plugin
#
sub coin_doi
{
	my ($self, $repository, $dataobj) = @_;

	# Zero pads eprintid as per config
	my $z_pad = $repository->get_conf( "datacitedoi", "zero_padding") || 0;
	my $id = sprintf("%0" . $z_pad . "d", $dataobj->id );
	
	# Check for custom delimiters
	my ($delim1, $delim2) = @{$repository->get_conf( "datacitedoi", "delimiters")};
	
	# Default to slash
	$delim1 = "/" if (!defined $delim1);
	
	# Second defaults to first
	$delim2 = $delim1 if (!defined $delim2);
	
	# Construct the DOI string
	my $prefix = $repository->get_conf( "datacitedoi", "prefix");
	my $thisdoi = $prefix . $delim1 . $repository->get_conf( "datacitedoi", "repoid") . $delim2 . $id;

	return $thisdoi;
}
# END UZH CHANGE ZORA-648

1;
