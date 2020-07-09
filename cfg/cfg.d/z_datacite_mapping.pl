#####################################################
# eprint => DataCite Metadata Schema mapping
####################################################

# DataCite Metadata Schema 4.3 elements
# mandatory elements
#   1 identifier (done in DataCiteXML)
#   2 creator, including affiliations
#   3 title
#   4 publisher
#   5 publicationYear
#  10 resourceType
#
# recommended elements
#   6 subject
#   7 contributor (collecting institution, editors, corresponding author)
#   8 date		(e.g. Issued date)
#  12 relatedIdentifier
#  17 description 
#  18 geoLocation
#
# optional elements
#  9 language
# 11 alternateIdentifier
# 13 size
# 14 format
# 15 version
# 16 rights
# 19 fundingReference

# DataCite element 2, creators, mandatory
$c->{datacite_mapping_creators} = sub {
	
	my ($xml, $dataobj, $repo, $value) = @_;
	
	my $type = $dataobj->get_value( "type" );

	my $element_creators = $xml->create_element("creators");
	
	# UZH specific type
	if ($type eq 'edited_scientific_work' )
	{
		$value = $dataobj->get_value( "editors" );
	}

	foreach my $name (@$value) 
	{
		my $element_creator = $xml->create_element( "creator" );
		
		EPrints::Extras::create_name_part( $xml, $dataobj, $element_creator, "creatorName", $name );

		$element_creators->appendChild( $element_creator );
	}
	
	return $element_creators;
};

# DataCite element 3, titles, mandatory
$c->{datacite_mapping_title} = sub {

	my ($xml, $dataobj, $repo, $value) = @_;

	use Locale::Language;
	
	my $element_titles = $xml->create_element("titles");
	my $title = $dataobj->render_value("title");
	
	my $lang_code;
	if ( $dataobj->is_set( "language_mult") )
	{
		my @languages = @{$dataobj->get_value( "language_mult" )};
		$lang_code = $languages[0];
	}
	
	# convert from 3-letter ISO 639-2 to 2-letter ISO 639-1 code 
	# my $lang_iso639_1 = language_code2code( $lang_code, 'alpha-3', 'alpha-2' ) if (defined $lang_code);
	my $lang_iso639_1 = EPrints::Extras::code2code( $lang_code ) if (defined $lang_code);
	
	if (defined $lang_iso639_1)
	{
		$element_titles->appendChild( $xml->create_data_element( "title", 
			$title, 
			"xml:lang" => $lang_iso639_1
		) );
	}
	else
	{
		$element_titles->appendChild( $xml->create_data_element( "title", $title ) );
	}
	
	if ( $dataobj->is_set( "othertitles" ) )
	{
		my $other_titles = $dataobj->get_value( "othertitles" );
		if (defined $lang_iso639_1)
		{
			$element_titles->appendChild( $xml->create_data_element( "title",
				$other_titles,
				"titleType" => "AlternativeTitle",
				"xml:lang" => $lang_iso639_1
			) );
		}
		else
		{
			$element_titles->appendChild( $xml->create_data_element( "title",
				$other_titles,
				"titleType" => "AlternativeTitle"
			) );
		}
	}

	return $element_titles;
};

# DataCite element 4, publisher, mandatory
$c->{datacite_mapping_publisher} = sub {

	my ($xml, $dataobj, $repo, $value) = @_;
	
	if ( defined $value && $value ne '' )
	{
		return $xml->create_data_element( "publisher", $dataobj->render_value( "publisher" ) );
	}
	else
	{
		return $xml->create_data_element( "publisher", "(:unav)" );
	}
};

# DataCite element 5, publicationYear, mandatory
$c->{datacite_mapping_date} = sub {

	my ( $xml, $dataobj, $repo, $value ) = @_;
	
	my $date = $dataobj->get_value( "date" );
	my ($year, $month, $day) = EPrints::Time::split_value( $date );

	return $xml->create_data_element( "publicationYear", $year ) if $year;

	return;
};

# DataCite element 10, resourceType, mandatory
# The two methods both map to resourceType (and resourceTypeGeneral) 
# the first is for publication repositories 
# the second for research data repositories
$c->{datacite_mapping_type} = sub {
	
	my ($xml, $dataobj, $repo, $value) = @_;

	my $pub_resourceType = $repo->get_conf("datacitedoi", "typemap", $value);
	
	if (defined $pub_resourceType)
	{
		return $xml->create_data_element( "resourceType", 
			$pub_resourceType->{'v'}, 
			resourceTypeGeneral => $pub_resourceType->{'a'}
		);
	}

	return;
};

#$c->{datacite_mapping_data_type} = sub {
#	
# 	my($xml, $dataobj, $repo, $value) = @_;
#
#	return $xml->create_data_element( "resourceType", $value, resourceTypeGeneral => $value );
#};

# DataCite element 6, subjects, recommended
$c->{datacite_mapping_dewey} = sub {

	my ($xml, $dataobj, $repo, $value) = @_;
	
	my $element_subjects;
	my $session = $dataobj->{session}; 
	
	my $keywords = $dataobj->get_value( "keywords" );
	my $jel_classification = $dataobj->get_value( "jel_classification" );
	my $zora_subjects = $dataobj->get_value( "subjects" );
	my $scopus_subjects = $dataobj->get_value( "scopussubjects" );
	
	if ( defined $value || defined $keywords || defined $jel_classification || 
	     defined $zora_subjects || defined $scopus_subjects  )
	{
		$element_subjects = $xml->create_element("subjects");
		
		# Dewey Decimal Classification
		if (defined $value)
		{
			foreach my $ddc (@$value)
			{
				my $dewey_subject = EPrints::DataObj::Subject->new( $session, $ddc);
				# Try to fetch the English term
				my $pos = 0;
				my $lang_pos = 0;
				foreach my $lang (@{$dewey_subject->{data}->{name_lang}})
				{
					$lang_pos = $pos if ($lang eq 'en');
					$pos++;
				}
				
				my @dewey_subject_names = @{$dewey_subject->{data}->{name_name}};
				my $dewey_subject_name = $dewey_subject_names[$lang_pos];
				
				my $ddc_class;
				($ddc_class = $ddc) =~ s/ddc//g;
				
				$element_subjects->appendChild( $xml->create_data_element( "subject",
					$dewey_subject_name,
					subjectScheme => "Dewey Decimal Classification",
					schemeURI => "http://dewey.info/scheme/",
					valueURI => "http://dewey.info/class/" . $ddc_class . "/",
					"xml:lang" => "en"
				) );
			}
		}

		if (defined $zora_subjects)
		{
			foreach my $zora_subject_code (@$zora_subjects)
			{
				my $zora_subject = EPrints::DataObj::Subject->new( $session, $zora_subject_code );
				if (defined $zora_subject)
				{
					# Try to fetch the English term
					my $pos = 0;
					my $lang_pos = 0;
					foreach my $lang (@{$zora_subject->{data}->{name_lang}})
					{
						$lang_pos = $pos if ($lang eq 'en');
						$pos++;
					}

					my @zora_subject_names = @{$zora_subject->{data}->{name_name}};
					my $zora_subject_name = $zora_subject_names[$lang_pos];

					$element_subjects->appendChild( $xml->create_data_element( "subject",
						$zora_subject_code . " " . $zora_subject_name,
						subjectScheme => "ZORA Communities & Collections",
						valueURI => "https://www.zora.uzh.ch/view/subjectsnew/" . 
							$zora_subject_code . ".html",
						"xml:lang" => "en"
					) );
				}
			}
		}

		if (defined $scopus_subjects)
		{
			foreach my $scopus_subject_code (@$scopus_subjects)
			{
				my $scopus_subject = EPrints::DataObj::Subject->new( $session, $scopus_subject_code );
				if (defined $scopus_subject)
				{
					# Try to fetch the English term
					my $pos = 0;
					my $lang_pos = 0;
					foreach my $lang (@{$scopus_subject->{data}->{name_lang}})
					{
						$lang_pos = $pos if ($lang eq 'en');
						$pos++;
					}

					my @scopus_subject_names = @{$scopus_subject->{data}->{name_name}};
					my $scopus_subject_name = $scopus_subject_names[$lang_pos];

					my $scopus_class;
					($scopus_class = $scopus_subject_code) =~ s/scopus//g;

					$element_subjects->appendChild( $xml->create_data_element( "subject",
						$scopus_class . " " . $scopus_subject_name,
						subjectScheme => "Scopus Subject Areas",
						"xml:lang" => "en"
					) );
				}
			}
		}
		
		if (defined $jel_classification)
		{
			foreach my $jel_code (@$jel_classification)
			{
				$element_subjects->appendChild( $xml->create_data_element( "subject",
					$jel_code,
					subjectScheme => "Journal of Economic Literature Classification Scheme (JEL) ",
					schemeURI => "http://zbw.eu/beta/external_identifiers/jel",
					valueURI => "http://zbw.eu/beta/external_identifiers/jel#" . $jel_code,
					"xml:lang" => "en"
				) );
			}
		}
		
		if (defined $keywords)
		{
			my @terms = split(/,|;|-/,$keywords);
			
			foreach my $term (@terms)
			{
				$element_subjects->appendChild( $xml->create_data_element( "subject", $term ) );
			}
		}
	}
	
	return $element_subjects;
};

# DataCite element 7, contributor (editor or collecting institution), recommended
$c->{datacite_mapping_editors} = sub {

	my ($xml, $dataobj, $repo, $value) = @_;
	
	my $element_contributors = $xml->create_element( "contributors" );
	
	# always add the hosting institution
	my $element_contributor = $xml->create_element( "contributor",
		"contributorType" => "HostingInstitution"
	);
	
	$element_contributor->appendChild( $xml->create_data_element( "contributorName",
		"University of Zurich",
		nameType => "Organizational" 
	) );
	$element_contributor->appendChild( $xml->create_data_element ( "nameIdentifier",
		"https://doi.org/10.13039/501100006447",
		nameIdentifierScheme => "CrossRef Funder DOI",
		schemeURI => "http://www.crossref.org/fundref/"
	) );
	$element_contributors->appendChild( $element_contributor );
	
	return $element_contributors if ( !defined $value );
	
	my $type = $dataobj->get_value( "type" );
	
	if ( $type ne 'edited_scientific_work' )
	{
		foreach my $name (@$value)
		{
			my $element_contributor = $xml->create_element( "contributor",
				contributorType => "Editor"
			);
		
			EPrints::Extras::create_name_part( $xml, $dataobj, $element_contributor, "contributorName", $name );
			
			$element_contributors->appendChild( $element_contributor );
		}
	}

	# UZH CHANGE ZORA-736 2020/01/09/mb corresponding author (may be creator or editor)
	my $creators = $dataobj->get_value( "creators" );
	
	if (defined $creators)
	{
		foreach my $creator (@$creators)
		{
			if (defined $creator->{correspondence} && $creator->{correspondence} eq "TRUE")
			{
				my $element_contributor = $xml->create_element( "contributor",
					contributorType => "ContactPerson"
				);

				EPrints::Extras::create_name_part( $xml, $dataobj, $element_contributor, "contributorName", $creator );

				$element_contributors->appendChild( $element_contributor );
			}
		}
	}

	foreach my $editor (@$value)
	{
		if (defined $editor->{correspondence} && $editor->{correspondence} eq "TRUE")
		{
			my $element_contributor = $xml->create_element( "contributor",
				contributorType => "ContactPerson"
			);

			EPrints::Extras::create_name_part( $xml, $dataobj, $element_contributor, "contributorName", $editor);

			$element_contributors->appendChild( $element_contributor );
		}
	}
	# END UZH CHANGE ZORA-736
	
	return $element_contributors;
};

# DataCite element 8, date, recommended
$c->{datacite_mapping_datestamp} = sub {

	my ($xml, $dataobj, $repo, $value) = @_;
	
	my $session = $dataobj->{session};
	
	my $element_dates = $xml->create_element( "dates" );
	
	# Created date
	my $dataset_history = $repo->get_dataset( "history" );
	
	my $search_expression = EPrints::Search->new(
		session => $session,
		dataset => $dataset_history,
		order => "historyid"
	);
	
	$search_expression->add_field(
		$dataset_history->get_field( "objectid" ),
		$dataobj->id,
		"EQ",
		"ANY"
	);
	
	$search_expression->add_field(
		$dataset_history->get_field( "action" ),
		"create",
		"EQ",
		"ANY"
	);
	
	my $list = $search_expression->perform_search;
	my @history_objects = $list->slice();
		
	foreach my $history (@history_objects)
	{
		my $timestamp_created = $history->get_value( "timestamp" );
		
		$timestamp_created =~ s/\s/T/g;
		
		$element_dates->appendChild( $xml->create_data_element ( "date", 
			$timestamp_created,
			dateType => "Created"
		) );
	}
	
	# Accepted date (= deposit date)
	$value =~ s/\s/T/g;
	$element_dates->appendChild( $xml->create_data_element ( "date", 
		$value,
		dateType => "Accepted"
	) );
	
	# Updated date
	my $lastmod = $dataobj->get_value( "lastmod" );
	$lastmod =~ s/\s/T/g;
	$element_dates->appendChild( $xml->create_data_element ( "date", 
		$lastmod,
		dateType => "Updated"
	) );
	
	# Issued date
	my $issued_date = $dataobj->get_value( "date" );
	$element_dates->appendChild( $xml->create_data_element ( "date", 
		$issued_date,
		dateType => "Issued"
	) );
	
	# Available date (embargo end date)
	my @documents = $dataobj->get_all_documents();
	foreach my $doc ( @documents )
	{
		my $doc_embargo = $doc->get_value("date_embargo");
		if ( (defined $doc_embargo) && ($doc_embargo ne "") )
		{
			$doc_embargo =~ s/\s/T/g;
			my $filename = $doc->get_value( "main" );
			
			$element_dates->appendChild( $xml->create_data_element ( "date", 
				$doc_embargo,
				dateType => "Available",
				dateInformation => $filename
			) );
		}
	}
	
	return $element_dates; 
};

# DataCite element 9, language, optional
$c->{datacite_mapping_language_mult} = sub {
	
	my ($xml, $dataobj, $repo, $value) = @_;
	
	use Locale::Language;
	
	my $element_language;
	
	if (scalar @$value)
	{
		my @languages = @$value;
		my $lang_code = $languages[0];
		# my $lang_iso639_1 = language_code2code( $lang_code, 'alpha-3', 'alpha-2' );
		my $lang_iso639_1 = EPrints::Extras::code2code( $lang_code );

		$element_language = $xml->create_data_element( "language", $lang_iso639_1 );
	}
	
	return $element_language;
};

# DataCite element 11, alternateIdentifier, optional
$c->{datacite_mapping_eprintid} = sub {
	
	my ($xml, $dataobj, $repo, $value) = @_;
	
	my $element_alternate_ids = $xml->create_element( "alternateIdentifiers" );
	
	my $base_url = $repo->config( "base_url");
	my $url = $base_url . "/id/eprint/" . $value . "/";
	
	$element_alternate_ids->appendChild( $xml->create_data_element( "alternateIdentifier",
		$url,
		alternateIdentifierType => "URL"
	) );
	
	return $element_alternate_ids;
};

# DataCite element 12, relatedIdentifier, recommended (directly called)
$c->{datacite_mapping_related_identifiers_from_docs} = sub {
	
	my ($xml, $dataobj, $repo) = @_;
	
	my $element_related_ids;
	
	my @documents = $dataobj->get_all_documents(); 
	
	if ( scalar @documents > 0 || $dataobj->is_set( "doi") || $dataobj->is_set( "pubmedid") || $dataobj->is_set( "isbn") )
	{
		$element_related_ids = $xml->create_element( "relatedIdentifiers" );
		
		if ($dataobj->is_set( "doi") )
		{
			$element_related_ids->appendChild( $xml->create_data_element( "relatedIdentifier",
				$dataobj->get_value( "doi" ),
				relatedIdentifierType => "DOI",
				relationType => "Cites"
			) );
		}
		
		if ($dataobj->is_set( "pubmedid") )
		{
			$element_related_ids->appendChild( $xml->create_data_element( "relatedIdentifier",
				$dataobj->get_value( "pubmedid" ),
				relatedIdentifierType => "PMID",
				relationType => "Cites"
			) );
		}
		
		if ($dataobj->is_set( "isbn") )
		{
			$element_related_ids->appendChild( $xml->create_data_element( "relatedIdentifier",
				$dataobj->get_value( "isbn" ),
				relatedIdentifierType => "ISBN",
				relationType => "Cites"
			) );
		}
		
		foreach my $doc (@documents)
		{
			my $url = $doc->get_url();
			$element_related_ids->appendChild( $xml->create_data_element( "relatedIdentifier",
				$url,
				relatedIdentifierType => "URL",
				relationType => "HasPart"
			) );
		}
	}
	
	return $element_related_ids;
};

# DataCite element 13, size, optional (directly called)
$c->{datacite_mapping_sizes_from_docs} = sub {
	
	my ($xml, $dataobj, $repo) = @_;
	
	my $element_sizes;
	
	my @documents = $dataobj->get_all_documents();
	
	if ( scalar @documents > 0 )
	{
		$element_sizes = $xml->create_element( "sizes" );
		
		foreach my $doc (@documents)
		{
			my $filename = $doc->get_main();
			my %files = $doc->files;
			my $size = $files{$filename};
			if( defined $size )
			{
				my $size_string = $filename . " - " . EPrints::Utils::human_filesize( $size );
				$element_sizes->appendChild( $xml->create_data_element( "size", $size_string ) );
			}
		}
	}
	
	return $element_sizes;
};

# DataCite element 14, format, optional (directly called)
$c->{datacite_mapping_formats_from_docs} = sub {
	
	my ($xml, $dataobj, $repo) = @_;
	
	my $element_formats;
	my $session = $dataobj->{session};
	
	my @documents = $dataobj->get_all_documents();
	
	if ( scalar @documents > 0 )
	{
		$element_formats = $xml->create_element( "formats" );
		
		foreach my $doc (@documents)
		{
			my $filename = $doc->get_main();
			my $format = $doc->get_value( "format" );
			
			my $format_string = $filename . " - " . $format;
			$element_formats->appendChild( $xml->create_data_element( "format", $format_string ) );
		}
	}
	
	return $element_formats;
};

# DataCite element 15, version, optional
$c->{datacite_mapping_succeeds} = sub {

	my ($xml, $dataobj, $repo, $value) = @_;
	
	my $version = 1;
	my $succeeds_field = $repo->get_dataset( "eprint" )->get_field( "succeeds" );
	my $has_multiple_versions = $dataobj->in_thread( $succeeds_field );
	
	if ( $has_multiple_versions )
	{
		# recursively try to find the current version number by parsing back to the first linked record
		my $eprint = $dataobj;
		my $dataset = $repo->get_dataset( "eprint" );
		
		while ( defined $eprint && $eprint->is_set( "succeeds") )
		{
			my $eprintid = $eprint->get_value( "succeeds" );
			$version++;
			$eprint = $dataset->dataobj( $eprintid );
		}
	}
	
	my $element_version = $xml->create_data_element( "version", sprintf( "%.1f", $version) );
	
	return $element_version;
};

# DataCite element 16, rights, optional (directly called)
$c->{datacite_mapping_rights_from_docs} = sub {

	my ( $xml, $dataobj, $repo ) = @_;
	
	my $element_rightslist;
	
	my $current_lang = $repo->get_langid;
	$repo->change_lang( "en" );
	
	my @documents = $dataobj->get_all_documents();
	
	if ( scalar @documents > 0 || $dataobj->exists_and_set( "access_rights" ) )
	{
		$element_rightslist = $xml->create_element( "rightsList" );
		
		if ( $dataobj->exists_and_set( "access_rights" ) )
		{
			$element_rightslist->appendChild( $xml->create_data_element( "rights",
				$dataobj->get_value( "access_rights" ),
				"xml:lang" => "en",
			) );
		}
		
		foreach my $doc (@documents)
		{
		my $rights_text;
			my $filename = $doc->get_main();
			if ( $doc->is_set( "license" ) && $doc->is_public )
			{
			my $license_id = $doc->get_value( "license" );
			my $license_phrase = EPrints::Utils::tree_to_utf8( $repo->html_phrase( 'licenses_description_' . $license_id ) );

			$license_phrase =~ /^\s*(.*?)\s<(.*?)>/ ;
			my $license_text = $1;
			my $license_url = $2;
						
			if ( $license_id eq "publisher" )
			{
				my $formatdesc = $doc->get_value( "formatdesc" );
				if ( $formatdesc =~ /^http.*/ )
				{
					$license_url = $formatdesc;
				}
			}
			
			$rights_text = $filename . " is licensed under a " . $license_text . " license";
				
			if (defined $license_url)
			{
				$element_rightslist->appendChild( $xml->create_data_element("rights", 
					$rights_text,
					rightsURI => $license_url,
					"xml:lang" => "en"
				) );
			}
			else
			{
				$element_rightslist->appendChild( $xml->create_data_element("rights", 
					$rights_text,
					"xml:lang" => "en"
				) );
			}
			}
			else
			{
				if ( $doc->exists_and_set( "date_embargo" ) )
				{
					$rights_text = $filename . "- embargoed until " . $doc->get_value( "date_embargo" );
				}
				else
				{
					$rights_text = $filename . " has no associated licence. Please contact the archive for advice.";
				}
				$element_rightslist->appendChild( $xml->create_data_element("rights", 
					$rights_text,
					"xml:lang" => "en"
				) );
			}
		}
	}
	
	$repo->change_lang( $current_lang );
	
	return $element_rightslist;
};

# DataCite element 17, description, recommended
$c->{datacite_mapping_abstract} = sub {

	my ($xml, $dataobj, $repo, $value) = @_;

	use Locale::Language;
	
	my $element_description = $xml->create_element("descriptions");
	
	my $type = $dataobj->get_value( "type" );
	
	my $citation = EPrints::Utils::tree_to_utf8( $dataobj->render_citation( 'publication' ) );
	# remove all HTML elements 
	$citation =~ s/<.*?>//g;

	if ( $type eq 'article')
	{
		$element_description->appendChild( $xml->create_data_element( "description",
			$citation,
			descriptionType => "SeriesInformation"
		) );
	}
	else
	{
		$element_description->appendChild( $xml->create_data_element( "description",
			$citation,
			descriptionType => "Other"
		) );
	}
	
	if ( defined $value )
	{
		if ( $dataobj->is_set( "language_mult" ) )
		{
			my @languages = @{$dataobj->get_value( "language_mult" )};
			
			my $lang_code = $languages[0];
			# my $lang_iso639_1 = language_code2code( $lang_code, 'alpha-3', 'alpha-2' );
			my $lang_iso639_1 = EPrints::Extras::code2code( $lang_code );
			$element_description->appendChild( $xml->create_data_element( "description", 
				$value,
				descriptionType => "Abstract",
				"xml:lang"=> $lang_iso639_1
			) );
		}
		else
		{
		 	$element_description->appendChild( $xml->create_data_element( "description", 
				$value,
				descriptionType => "Abstract"
			) );
		}
	}
	
	return $element_description;
};

# DataCite element 18, geoLocation, optional, not used in ZORA
$c->{datacite_mapping_geographic_cover} = sub {
	
	my ($xml, $dataobj, $repo, $value) = @_;

	my $geo_locations = $xml->create_element("geoLocations");
	my $geo_location = $xml->create_element("geoLocation");
	if ($dataobj->exists_and_set("geographic_cover")) 
	{
		# Get value of geographic_cover field and append to $geo_location XML element
		my $geographic_cover = $dataobj->get_value("geographic_cover");
		$geo_location->appendChild($xml->create_data_element("geoLocationPlace", $geographic_cover));

		# Get values of bounding box
		my $west = $dataobj->get_value("bounding_box_west_edge");
		my $east = $dataobj->get_value("bounding_box_east_edge");
		my $south = $dataobj->get_value("bounding_box_south_edge");
		my $north = $dataobj->get_value("bounding_box_north_edge");

		if (defined $north && defined $south && defined $east && defined $west) 
		{
			my $geo_location_box = $xml->create_element("geoLocationBox");

			$geo_location_box->appendChild($xml->create_data_element("westBoundLongitude", $west));
			$geo_location_box->appendChild($xml->create_data_element("eastBoundLongitude", $east));
			$geo_location_box->appendChild($xml->create_data_element("southBoundLatitude", $south));
			$geo_location_box->appendChild($xml->create_data_element("northBoundLatitude", $north));

			$geo_location->appendChild($geo_location_box);
		}
		
		$geo_locations->appendChild($geo_location);
	}

	return $geo_locations;
};

# DataCite element 19, fundingReference, optional
$c->{datacite_mapping_funding_reference} = sub {
	
	my ($xml, $dataobj, $repo, $value) = @_;
	
	my $element_funding_references;
	
	if (scalar @$value > 0)
	{
		$element_funding_references = $xml->create_element("fundingReferences");
		foreach my $funding_reference (@$value)
		{
			my $element_funding_reference = $xml->create_element("fundingReference");
			
			if ( defined $funding_reference->{funder_name} )
			{
				$element_funding_reference->appendChild( $xml->create_data_element( "funderName", $funding_reference->{funder_name} ) );
			}
			else
			{
				 $element_funding_reference->appendChild( $xml->create_data_element( "funderName", "(:unav)" ) );
			}
			
			if ( defined $funding_reference->{funder_identifier} )
			{
				if ( defined $funding_reference->{funder_type} )
				{
					$element_funding_reference->appendChild( $xml->create_data_element( "funderIdentifier",
						$funding_reference->{funder_identifier},
						funderIdentifierType => $funding_reference->{funder_type}
					) );
				}
				else
				{
					$element_funding_reference->appendChild( $xml->create_data_element( "funderIdentifier",
						$funding_reference->{funder_identifier}
					) );
				}
			}
			
			if ( defined $funding_reference->{award_number} )
			{
				if ( defined $funding_reference->{award_uri} )
				{
					$element_funding_reference->appendChild( $xml->create_data_element( "awardNumber",
						$funding_reference->{award_number},
						awardURI => $funding_reference->{award_uri}
					) );
				}
				else
				{
					$element_funding_reference->appendChild( $xml->create_data_element( "awardNumber",
						$funding_reference->{award_number}
					) );
				}
			}
			
			if ( defined $funding_reference->{award_title} )
			{
				$element_funding_reference->appendChild( $xml->create_data_element( "awardTitle",
					$funding_reference->{award_title}
				) );
			}
			
			$element_funding_references->appendChild( $element_funding_reference );
		}
	}
	
	return $element_funding_references;
};

{
	package EPrints::Extras;
	
	sub create_name_part
	{
		my ($xml, $dataobj, $element, $creator_contributor_name, $name) = @_;
		
		my $session = $dataobj->{session};
		
		my $name_name = EPrints::Utils::make_name_string($name->{name});

		my $family = $name->{name}->{family};
		my $given = $name->{name}->{given};
		my $orcid = $name->{orcid};
		my $uzh = $name->{uzh};
		my $affiliation_ids = $name->{affiliation_ids};
		
		my $affil_typemap = {};	
		$affil_typemap->{grid}->{scheme} = "GRID";
		$affil_typemap->{grid}->{schemeURI} = "https://www.grid.ac/";
		$affil_typemap->{ror}->{scheme} = "ROR";
		$affil_typemap->{ror}->{schemeURI} = "https://ror.org/";
		$affil_typemap->{scopus}->{scheme} = "Scopus";
		$affil_typemap->{scopus}->{schemeURI} = "https://www.scopus.com/";
		
		my $name_type = "Personal";
		$name_type = "Organizational" if ($given eq '');
		
		$element->appendChild( 
			$xml->create_data_element( $creator_contributor_name, 
				$name_name,
				"nameType" => $name_type
			)
		);
		
		if ( $name_type eq "Personal" )
		{
			$element->appendChild( $xml->create_data_element( "givenName", $given ) );
			$element->appendChild( $xml->create_data_element( "familyName", $family ) );
		}
		
		if (defined $orcid)
		{
			$element->appendChild( $xml->create_data_element( "nameIdentifier", 
				EPrints::Utils::format_orcid_for_export( $orcid ), 
				"schemeURI" => "http://orcid.org/", 
				"nameIdentifierScheme" => "ORCID"
			) );
		}
		
		if ( defined $affiliation_ids )
		{
			my @afids = split( /\|/, $affiliation_ids );
			
			foreach my $afid (@afids)
			{
				my $affilobj = EPrints::DataObj::Affiliation::get_affilobj( $session, $afid );
				
				my $primary_afid = $affilobj->get_value( "primary_afid" );
				my $primary_afid_type = $affilobj->get_value( "primary_afid_type" );
				my $org = $affilobj->get_value( "name" );
				my $city = $affilobj->get_value( "city" );
				my $country = $affilobj->get_value( "country" );
				
				my $affiliation = $org;
				$affiliation .= "|" . $city if (defined $city);
				$affiliation .= "|" . $country if (defined $country);
				
				$element->appendChild( $xml->create_data_element( "affiliation",
					$affiliation,
					"affiliationIdentifier" => $primary_afid,
					"affiliationIdentifierScheme" => $affil_typemap->{$primary_afid_type}->{scheme},
					"SchemeURI" => $affil_typemap->{$primary_afid_type}->{schemeURI}
				) );
			}
		}
		
		if ( !defined $affiliation_ids && defined $uzh && $uzh eq 'uzh' )
		{
			$element->appendChild( $xml->create_data_element( "affiliation",
				"University of Zurich|Zurich|Switzerland"
			) );
		}
		
		return;
	}
	
	sub code2code
	{
		my ($code) = @_;
		
		my $conversion = {
			ces => "cs",
			dan => "da",
			deu => "de",
			eng => "en",
			fra => "fr",
			ita => "it",
			jpn => "ja",
			lat => "la",
			nld => "nl",
			pol => "pl",
			por => "pt",
			roh => "rm",
			rus => "ru",
			spa => "es",
			zho => "zh"
		};
		
		return $conversion->{$code};
	}
};
