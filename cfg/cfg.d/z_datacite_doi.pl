# Enable the plugin
$c->{plugins}{"Export::DataCiteXML"}{params}{disable} = 0;
# $c->{plugins}{"Event::DataCiteEvent"}{params}{disable} = 0;

# which field to use for the doi
# $c->{datacitedoi}{eprintdoifield} = "id_number";

# for xml:lang attributes in XML
$c->{datacitedoi}{defaultlangtag} = "en-US";

# When should you register/update doi info.
# $c->{datacitedoi}{eprintstatus} = {inbox=>0,buffer=>1,archive=>1,deletion=>0};

#set these (you will get the from data site)
# doi = {prefix}/{repoid}/{eprintid}
$c->{datacitedoi}{prefix} = "10.5167";
$c->{datacitedoi}{repoid} = "uzh";
# $c->{datacitedoi}{apiurl} = "https://test.datacite.org/mds/";
# $c->{datacitedoi}{user} = "USER";
# $c->{datacitedoi}{pass} = "PASS";

# datacite requires a Publisher
# The name of the entity that holds, archives, publishes,
# prints, distributes, releases, issues, or produces the
# resource. This property will be used to formulate the
# citation, so consider the prominence of the role.
# eg World Data Center for Climate (WDCC);
$c->{datacitedoi}{publisher} = "Zurich Open Repository and Archive";


# Namespace and location for datacite XML schema
# feel free to update, though no guarantees it'll be accepted if you do
$c->{datacitedoi}{xmlns} = "http://datacite.org/schema/kernel-4";
$c->{datacitedoi}{schemaLocation} = $c->{datacitedoi}{xmlns} . " http://schema.datacite.org/meta/kernel-4.3/metadata.xsd";

# need to map eprint type (article, dataset etc) to ResourceType
# Controled list http://schema.datacite.org/meta/kernel-4.3/doc/DataCite-MetadataKernel_v4.3.pdf
# where v is the ResourceType and a is the resourceTypeGeneral
$c->{datacitedoi}{typemap}{article} = {v=>'Article',a=>'Text'};
$c->{datacitedoi}{typemap}{book_section} = {v=>'BookSection',a=>'Text'};

$c->{datacitedoi}{typemap}{monograph} = {v=>'Monograph',a=>'Text'};
$c->{datacitedoi}{typemap}{thesis} = {v=>'Thesis',a=>'Text'};
$c->{datacitedoi}{typemap}{book} = {v=>'Book',a=>'Text'};
$c->{datacitedoi}{typemap}{patent} = {v=>'Patent',a=>'Text'};
$c->{datacitedoi}{typemap}{artefact} = {v=>'Artefact',a=>'PhysicalObject'};
$c->{datacitedoi}{typemap}{performance} = {v=>'Performance',a=>'Event'};
$c->{datacitedoi}{typemap}{composition} = {v=>'Composition',a=>'Sound'};
$c->{datacitedoi}{typemap}{image} = {v=>'Image',a=>'Image'};
$c->{datacitedoi}{typemap}{experiment} = {v=>'Experiment',a=>'Text'};
$c->{datacitedoi}{typemap}{teaching_resource} = {v=>'TeachingResourse',a=>'InteractiveResource'};
$c->{datacitedoi}{typemap}{other} = {v=>'Misc',a=>'Collection'};
$c->{datacitedoi}{typemap}{dataset} = {v=>'Dataset',a=>'Dataset'};
$c->{datacitedoi}{typemap}{audio} = {v=>'Audio',a=>'Sound'};
$c->{datacitedoi}{typemap}{video} = {v=>'Video',a=>'Film'};
$c->{datacitedoi}{typemap}{data_collection} = {v=>'Dataset',a=>'Dataset'};

# UZH CHANGE ZORA-648 2018/03/23/mb UZH types added
$c->{datacitedoi}{typemap}{conference_item} = {v=>'ConferenceItem',a=>'Text'};
$c->{datacitedoi}{typemap}{dissertation} = {v=>'PhDThesis',a=>'Text'};
$c->{datacitedoi}{typemap}{habilitation} = {v=>'Habilitation',a=>'Text'};
$c->{datacitedoi}{typemap}{masters_thesis} = {v=>'MastersThesis',a=>'Text'};
$c->{datacitedoi}{typemap}{newspaper_article} = {v=>'NewspaperArticle',a=>'Text'};
$c->{datacitedoi}{typemap}{edited_scientific_work} = {v=>'EditedBook',a=>'Text'};
$c->{datacitedoi}{typemap}{working_paper} = {v=>'WorkingPaper',a=>'Text'};
$c->{datacitedoi}{typemap}{published_research_report} = {v=>'Report',a=>'Text'};
$c->{datacitedoi}{typemap}{scientific_publication_in_electronic_form} = {v=>'OnlineResource',a=>'Dataset'};



###########################
#### DOI syntax config ####
###########################

# Set config of DOI delimiters
# Feel free to change, but they must conform to DOI syntax
# If not set will default to prefix/repoid/id the example below gives prefix/repoid-id
$c->{datacitedoi}{delimiters} = ["/","-"];

# If set, plugin will attempt to register what is found in the EP DOI field ($c->{datacitedoi}{eprintdoifield})
# Will only work if what is found adheres to DOI syntax rules (obviously)
$c->{datacitedoi}{allow_custom_doi} = 0;

#Datacite recommend digits of length 8-10 set this param to pad the id to required length
$c->{datacitedoi}{zero_padding} = 0;

##########################################
### Override which URL gets registered ###
##########################################

#Only useful for testing from "wrong" domain (eg an unregistered test server) should be undef for normal operation
$c->{datacitedoi}{override_url} = undef;

##########################
##### When to coin ? #####
##########################

# If auto_coin is set DOIs will be minted on Status change (provided all else is well)
$c->{datacitedoi}{auto_coin} = 0;
# If action_coin is set then a button will be displayed under action tab (for staff) to mint DOIs on an adhoc basis
$c->{datacitedoi}{action_coin} = 0;

# NB setting auto_coin renders action coin redundant as only published items can be registered

####### Formerly in cfg.d/datacite_core.pl #########

# Including datacite_core.pl below as we can make some useful decisions based on the above config.

## Adds the minting plugin to the EP_TRIGGER_STATUS_CHANGE
if($c->{datacitedoi}{auto_coin}){
	$c->add_dataset_trigger( "eprint", EP_TRIGGER_STATUS_CHANGE , sub {
       my ( %params ) = @_;

       my $repository = $params{repository};

       return if (!defined $repository);

		if (defined $params{dataobj}) {
			my $dataobj = $params{dataobj};
			my $eprint_id = $dataobj->id;
			$repository->dataset( "event_queue" )->create_dataobj({
				pluginid => "Event::DataCiteEvent",
				action => "datacite_doi",
				params => [$dataobj->internal_uri],
			});
     	}

	});
}

# Activate an action button, the plugin for which is at
# /plugins/EPrints/Plugin/Screen/EPrint/Staff/CoinDOI.pm
if($c->{datacitedoi}{action_coin}){
 	$c->{plugins}{"Screen::EPrint::Staff::CoinDOI"}{params}{disable} = 0;
}
