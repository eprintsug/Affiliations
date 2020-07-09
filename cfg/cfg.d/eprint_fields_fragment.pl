#
# CAUTION: This configuration file is only a snippet of the eprint fields configuration that 
# is used at University of Zurich; it serves as illustration.
# It provides the main definitions for the author affiliations.
# Please copy what you need to your own eprint field configuration.
#

$c->{fields}->{eprint} = [

          {
            'name' => 'creators',
            'type' => 'compound',
            'fromform' => 'format_orcid_id_fromform',
            'multiple' => 1,
            'fields' => [
                          {
                            'sub_name' => 'name',
                            'type' => 'name',
                            'hide_honourific' => 1,
                            'hide_lineage' => 1,
                            'family_first' => 1,
                            'make_single_value_orderkey' => 'localfn_no_accents_ordervalue',
                            'render_single_value' => 'EPrints::Extras::render_authors_via_search',
                          },
                          {
                            'sub_name' => 'id',
                            'type' => 'text',
                            'input_cols' => 20,
                            'allow_null' => 1,
                          },
                        # UZH CHANGE ZORA-116 2017/05/04/mb ORCID ID subfield
                          {
                            'sub_name' => 'orcid',
                            'type' => 'id',
                            'input_cols' => 19,
                          },
			# END UZH CHANGE ZORA-116
			# UZH CHANGE ZORA-736 2019/11/18/mb corresponding author 
			  {
                            'sub_name' => 'correspondence',
                            'type' => 'boolean',
                            'input_style' => 'radio',
                          },
                        # END UZH CHANGE ZORA-736
                        # UZH CHANGE ZORA-736 2019/11/18/mb affiliation ids linking to affiliation dataset
                          {
                            'sub_name' => 'affiliation_ids',
                            'type' => 'text',
                            'input_cols' => 40,
                            'show_in_fieldlist' => 0,
                            'render_single_value' => 'EPrints::Extras::render_afid_organisation',
                          },
                        # END UZH CHANGE ZORA-736
                        ],
            'input_boxes' => 4,
          },


          {
            'name' => 'examiners',
            'type' => 'compound',
            'fromform' => 'format_orcid_id_fromform',
            'multiple' => 1,
            'fields' => [
                          {
                            'sub_name' => 'name',
                            'type' => 'name',
                            'hide_honourific' => 1,
                            'hide_lineage' => 1,
                            'family_first' => 1,
                            'fromform' => 'EPrints::Extras::trim_fromform',
                          },
                          {
                            'sub_name' => 'id',
                            'type' => 'text',
                            'input_cols' => 20,
                            'allow_null' => 1,
                          },
                        # UZH CHANGE ZORA-116 2017/05/04/mb ORCID ID subfield
                          {
                            'sub_name' => 'orcid',
                            'type' => 'id',
                            'input_cols' => 19,
                          },
                        # END UZH CHANGE ZORA-116
                        # UZH CHANGE ZORA-736 2019/11/18/mb corresponding author 
                          { 
                            'sub_name' => 'correspondence',
                            'type' => 'boolean',
                            'input_style' => 'radio',
                          },
                        # END UZH CHANGE ZORA-736
                        # UZH CHANGE ZORA-736 2019/11/18/mb affiliation ids linking to affiliation dataset
                          { 
                            'sub_name' => 'affiliation_ids',
                            'type' => 'text',
                            'input_cols' => 40,
                            'show_in_fieldlist' => 0,
                          },
                        # END UZH CHANGE ZORA-736
                        ],
            'input_boxes' => 4,
          },
          {
            'name' => 'editors',
            'type' => 'compound',
            'fromform' => 'format_orcid_id_fromform',
            'multiple' => 1,
            'fields' => [
                          {
                            'hide_honourific' => 1,
                            'type' => 'name',
                            'hide_lineage' => 1,
                            'family_first' => 1,
                            'sub_name' => 'name',
            'make_single_value_orderkey' => 'localfn_no_accents_ordervalue',
	    'render_single_value' => 'EPrints::Extras::render_authors_via_search',
                          },
                          {
                            'input_cols' => 20,
                            'allow_null' => 1,
                            'type' => 'text',
                            'sub_name' => 'id',
                          },
                        # UZH CHANGE ZORA-116 2017/05/04/mb ORCID ID subfield
                          {
                            'sub_name' => 'orcid',
                            'type' => 'id',
                            'input_cols' => 19,
                          },
                        # END UZH CHANGE ZORA-116
                        # UZH CHANGE ZORA-736 2019/11/18/mb corresponding author 
                          { 
                            'sub_name' => 'correspondence',
                            'type' => 'boolean',
                            'input_style' => 'radio',
                          },
                        # END UZH CHANGE ZORA-736
                        # UZH CHANGE ZORA-736 2019/11/18/mb affiliation ids linking to affiliation dataset
                          { 
                            'sub_name' => 'affiliation_ids',
                            'type' => 'text',
                            'input_cols' => 40,
                            'show_in_fieldlist' => 0,
                          },
                        # END UZH CHANGE ZORA-736
                        ],
            'input_boxes' => 4,
          },
	 { 
            'name' => 'suggestions',
            'type' => 'longtext',
            'render_value' => 'EPrints::Extras::render_highlighted_field',
            'input_rows' => 3,
          },
# UZH CHANGE ZORA-736 2019/11/20/mb Scopus Subject Areas for IRO-DB
	{
		'name' => 'scopussubjects',
		'type' => 'subject',
		'multiple' => 1,
		'top' => 'scopus',
		'browse_link' => 'scopussubjects',
	},

];

=begin InternalDoc

=over

=item format_orcid_id_fromform( $value, $repo )

=back

Test and if possible/necessay reformat the supplied ORCID iD by removing
any URI part and adding hyphens as required

=end InternalDoc

=cut

$c->{format_orcid_id_fromform} = sub
{
        my( $value, $repo ) = @_;

	if ( ref( $value ) eq 'HASH' )
	{   	
		my $orcid_val = $value->{orcid};

		$orcid_val =~ s/(http|https):\/\/orcid.org\/// if $orcid_val;
		if ( $orcid_val && $orcid_val =~ /\D*(\d{4})\D?(\d{4})\D?(\d{4})\D?(\d{3}[Xx\d])$/ )
		{
			my $p1 = $1;
			my $p2 = $2;
			my $p3 = $3;
			my $p4 = $4;
			if ( $p1 && $p2 && $p3 && $p4 )
			{
                		$value->{orcid} = $p1."-".$p2."-".$p3."-".$p4;
			}
		}	
	}
	else
	{
        	foreach my $entry (@$value)
        	{
                	my $orcid_val = $entry->{orcid};
			$orcid_val =~ s/(http|https):\/\/orcid.org\/// if $orcid_val;
			if ( $orcid_val && $orcid_val =~ /\D*(\d{4})\D?(\d{4})\D?(\d{4})\D?(\d{3}[Xx\d])$/ )
			{
				my $p1 = $1;
				my $p2 = $2;
				my $p3 = $3;
				my $p4 = $4;
				if ( $p1 && $p2 && $p3 && $p4 )
				{
                			$entry->{orcid} = $p1."-".$p2."-".$p3."-".$p4;
				}
			}
		}
        }
        return $value;
};

sub render_page_range
{
    my( $session, $field, $value ) = @_;

    if( EPrints::Utils::is_set( $value ) )
    {
        unless( $value =~ m/^(\d+)-(\d+)$/ )
        {
                # value not in expected form. Ah, well. Muddle through.
                return $session->make_text( $value );
        }
        my( $a, $b ) = ( $1, $2 );
        my $frag;
        if( $a == $b )
        {
                $frag = $session->make_doc_fragment();
                $frag->appendChild( $session->make_text( $a ) );
        }
        else
        {
                $frag = $session->make_doc_fragment();
                $frag->appendChild( $session->make_text( $a.'-'.$b ) );
        }
        return $frag;
    }
    else
    {
        return $session->make_doc_fragment;
    }
}

{
package EPrints::Extras;
	sub input_render_my_optional_field
	{
   		my ($caller, $session, $value, $dataset, $staff, $unused, $obj, $basename) = @_;

		# UZH CHANGE 2015/02/26 ZORA-407
		my $frag;
		my $access = $session->current_user->is_staff;

		if ($access)
		{
			my $maxlength = $caller->get_max_input_size;

			my $size = ( $maxlength > $caller->{input_cols} ?
						$caller->{input_cols} : 
						$maxlength );

			$frag = $session->render_noenter_input_field(
				class=>"ep_form_text ep_form_optional_text",
				name => $basename,
				id => $basename,
				value => $value,
				size => $size,
				maxlength => $maxlength,
				title => $session->phrase("eprint_fieldname_optional_index_title"), 
			);
		}
		else
		{
			$frag = $session->make_doc_fragment();
			$frag->appendChild( $session->make_text( $value ) );
		}

  		return $frag;
	}
	
	# UZH CHANGE 2015/02/03 ZORA-400
	sub render_abstract
	{
		my( $session, $field, $value ) = @_;

		my @paras = split( /\r\n/, $value);
		
		my $frag = $session->make_doc_fragment();

                my $counter = 0;
		my $paras_count = scalar(@paras);

		foreach( @paras )
		{
			$counter++;
			my $br = $session->make_element( "br" );
			$frag->appendChild( $session->make_text( $_ ) );
			$frag->appendChild( $br ) unless $counter == $paras_count;
		}
		return $frag;
	}

	# UZH CHANGE 2015/03/18/mb ZORA-415
	sub trim_fromform
	{
		my ($value, $session) = @_;
	
		$value =~ s/^\s+|\s+$//g;
		return $value;
	}

	# UZH CHANGE 2017/01/25/mb ZORA-522
	sub remove_crlf_fromform
	{
		my ($value, $session) = @_;

		if (defined $value)
		{
			$value =~ s/\r|\n/ /g;
			$value =~ s/^\s+|\s+$//g;
			$value =~ s/\s{2,}/ /g;
		}
		return $value;
	}

	sub format_orcid_for_export
	{
		my( $value ) = @_;

		my $protocol = 'https://orcid.org/';
		$value =  $protocol.$value if $value && $value !~ /^http/;
		return $value;
	}

	# UZH CHANGE 2019/08/21/jw ZORA-735
	sub render_authors_via_search
	{
 		my( $session, $field, $value ) = @_;

		my $frag = $session->make_doc_fragment();
		my $name = $value->{family};
		my $given = $value->{given};
		$name .= ", " . $given if (defined $given && $given ne '');
		
		my $tmp_url = "javascript:contributorCitation" . "( '" . $name  . "' );";
		my $tmp_title = $session->phrase("viewpublications_eprint_contributor") . "\"" . $name . "\"";
		my $tmp_link = $session->make_element( "a", href => $tmp_url, title => $tmp_title );

		$tmp_link->appendChild( $session->make_text( $name ) );
		$frag->appendChild( $tmp_link );
		
		return $frag;	
	}
	# END UZH CHANGE 2019/08/21/jw ZORA-735
	
	# UZH CHANGE ZORA-736 2019/12/05/mb
	sub render_afid_organisation
	{
		my( $session, $field, $value ) = @_;
		
		my $frag = $session->make_doc_fragment();
		my $repo = $session->get_repository;
		my $dataset = $repo->dataset( "affiliation" );
		
		my @afids = split( /\|/, $value );
		
		sub render_afid_org
		{
			my( $session, $dataset, $item, $param ) = @_;
			
			my $frag = $param->{xml};
			my $afid = $param->{afid};
			my $organisation = $item->get_value( "name" );
			
			my $value = $afid . " : " . $organisation;
			
			$frag->appendChild( $session->make_text( $value ) );
			$frag->appendChild( $session->make_element( "br" ) );
			
			return;
		}
	
		foreach my $afid (@afids)
		{
			my $list = $dataset->search(filters => [{
    				meta_fields => [qw( primary_afid )], 
    				value => $afid,
    			}]);
    		
    			my $param;
    			$param->{xml} = $frag;
    			$param->{afid} = $afid;
    		
    			$list->map( \&render_afid_org, $param );
		}
		
		return $frag;
	}
	# END UZH CHANGE ZORA-736
	
}

;



