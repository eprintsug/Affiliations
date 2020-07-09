
######################################################################

=item $xhtmlfragment = eprint_render( $eprint, $session, $preview )

This subroutine takes an eprint object and renders the XHTML view
of this eprint for public viewing.

Takes two arguments: the L<$eprint|EPrints::DataObj::EPrint> to render and the current L<$session|EPrints::Session>.

Returns three XHTML DOM fragments (see L<EPrints::XML>): C<$page>, C<$title>, (and optionally) C<$links>.

If $preview is true then this is only being shown as a preview.
(This is used to stop the "edit eprint" link appearing when it makes
no sense.)

=cut

######################################################################

$c->{eprint_render} = sub
{
	my( $eprint, $session, $preview ) = @_;

	# CAUTION: This is only a fragment of the render method used at University of Zurich. 
	# It serves as illustration for rendering the affiliations.
	# The original render method has more than 2000 lines ...
	# Please take from it what is useful for you.
	
	# UZH CHANGE 20/06/2016/mb Author collaborations box
	my $collaborations_heading = $session->make_element( "h3", id=>"collaborations_heading", class=>"hidden-print", 'aria-hidden'=>"true");
	$collaborations_heading->appendChild( $session->html_phrase( "page:collaborations" ) );
	$article_network->appendChild( $collaborations_heading );
	$article_network->appendChild( make_collaborationsbox( $eprint,$session ) );
	$e2_column_right->appendChild( $session->html_phrase( "page:readmore:collaborations" ) );
	# END UZH CHANGE Author collaborations
	
	$page->appendChild( $e2_column );
	# UZH CHANGE 02/11/2015 jv, ZORA-440: build 2-column END
				
	my $title = $eprint->render_description();

	my $links = $session->make_doc_fragment();
	$links->appendChild( $session->plugin( "Export::Simple" )->dataobj_to_html_header( $eprint ) );
	$links->appendChild( $session->plugin( "Export::DC" )->dataobj_to_html_header( $eprint ) );
	$links->appendChild( $session->plugin( "Export::HighWire_Press")->dataobj_to_html_header( $eprint ) );

	return( $page, $title, $links );
};

# UZH CHANGE 20/06/2016/mb Author Collaborations
sub make_collaborationsbox
{
	my ($eprint, $session ) = @_;

	my $more_less;
	$more_less = $session->make_element( "div",
                id => "collaborations",
                class => "col-lg-12 col-md-12 col-sm-12 col-xs-12 summary-widget hidden-print", 
		'aria-hidden'=>"true"
        );

	my $collaborations_div = $session->make_element( "div", id => "more_less", class =>"hidden-print" );

	my $creators = $eprint->get_value( "creators" );
	my $editors = $eprint->get_value( "editors" );

	$collaborations_div->appendChild( render_collaboration( $session, $creators ) );
	$collaborations_div->appendChild( render_collaboration( $session, $editors ) );

	# UZH CHANGE ZORA-116 render ORCID ID source
	my $orcid_source_display = 0;
	$orcid_source_display = get_orcid_display( $creators, $orcid_source_display );
	$orcid_source_display = get_orcid_display( $editors, $orcid_source_display );
	if ($orcid_source_display)
	{
		$collaborations_div->appendChild( render_orcid_source( $eprint, $session ) );
	}

	$more_less->appendChild( $collaborations_div );

	return ( $more_less );
}

# UZH CHANGE ZORA-116 2017/05/11/mb render ORCID batch
# UZH CHANGE ZORA-588 2019/10/02/mb include ORCID iD in call to collaborations graph
sub render_collaboration
{
	my ($session,$authors) = @_;
	
	my $authors_frag = $session->make_doc_fragment;
	
	foreach my $author (@$authors)
	{
		my $family = $author->{name}->{family};
		next if ( $family =~ /et\sal/ );
		
		my $given = $author->{name}->{given};
		my $orcid = $author->{orcid};
		my $correspondence = $author->{correspondence};
		my $afids = $author->{affiliation_ids};

		# UZH CHANGE ZORA-116 2020/04/07/mb Improve ORCID batch display
		my $auth_orcid = "";
		$auth_orcid = " orcid-person" if (defined $orcid && $orcid ne '');

		my $author_div;
		if (defined $afids)
		{
			$author_div = $session->make_element( "div", class => "authcollab$auth_orcid" );
		}
		else
		{
			$author_div = $session->make_element( "div", class => "authcollab_inline$auth_orcid" );
		}
		# END UZH CHANGE ZORA-695

		utf8::encode($family);
		utf8::encode($given);
		my $author_name = $family;
		$author_name = $author_name . ', ' . $given if ($given ne '');

		my $author_url = '/cgi/collaborations/view?author=' . $author_name;
		$author_url .= ' (' . $orcid . ')' if (defined $orcid && $orcid ne '');

		# UZH CHANGE 2016/11/28 jv, ZORA-534: space is not allowed in anchor tag
		$author_url =~ s/ /%20/g;
		# UZH CHANGE 2016/11/28 jv, ZORA-534 END
		

		# UZH CHANGE 2017/10/18/jv, ZORA-498
		# - simplify: change icon from css-background to <img>
		my $author_a = $session->make_element( "a", href => $author_url );
		my $author_network_img = $session->make_element( "img", 
			src => "/zora_zwonull/images/conwheelicon_24.png",
			class => "collaboration-url",
			alt => EPrints::Utils::tree_to_utf8($session->html_phrase( "Plugin/Screen/Collaborations/View:title" ))
		);
		$author_a->appendChild( $author_network_img );
		# END UZH CHANGE 2017/10/18/jv, ZORA-498

		$author_a->appendChild( $session->make_text( $author_name ) );
		$author_div->appendChild( $author_a );

		if (defined $correspondence && $correspondence eq "TRUE")
		{
			 $author_div->appendChild( $session->make_text("*") );
		}
	
		if ( defined $orcid )
		{
			# UZH CHANGE 2017/10/18/jv, ZORA-498 add name
			$author_div->appendChild( render_orcid_batch( $session, $orcid, $author_name ) );
			# END UZH CHANGE 2017/10/18/jv, ZORA-498
		}

		if (defined $correspondence && $correspondence eq "TRUE")
		{
			$author_div->appendChild( $session->make_text(" ") );
			$author_div->appendChild( $session->html_phrase( "page:corresponding_author" ) );
		}
		
		$authors_frag->appendChild( $author_div );

		if (defined $afids)
		{
			my $affiliations_div = $session->make_element( "div", class => "affiliations" );
			my @affil_ids = split( /\|/, $afids );
			
			foreach my $affil_id (@affil_ids)
			{
				my $affilobj = EPrints::DataObj::Affiliation::get_affilobj( $session, $affil_id );
				my $org = $affilobj->get_value( "name" );
				my $city = $affilobj->get_value( "city" );
				my $country = $affilobj->get_value( "country" );

				my $affiliation = $org;
				$affiliation .= ", " . $city if (defined $city);
				$affiliation .= ", " . $country if (defined $country);
				$affiliations_div->appendChild( $session->make_text( $affiliation ) );
				$affiliations_div->appendChild( $session->make_element( "br" ) );
			}

			$authors_frag->appendChild( $affiliations_div );
		}
	}

	return ( $authors_frag ); 
}
# END UZH CHANGE ZORA-116 2017/05/11/mb render ORCID batch

# UZH CHANGE ZORA-116 2017/10/15/mb get ORCID display flag
sub get_orcid_display
{
	my ($authors, $flag) = @_;

	foreach my $author (@$authors)
	{
		my $orcid = $author->{orcid};
		if (defined $orcid)
		{
			$flag = 1;
		}
	}

	return $flag;
}
# END UZH CHANGE ZORA-116 2017/10/15/mb


# UZH CHANGE ZORA-116 2017/05/11/mb, 2020/04/07/mb render ORCID batch
# UZH CHANGE 2017/10/18/jv, ZORA-498
# - simplify: change icon from css-background to <img>, add alt="authors name"
sub render_orcid_batch
{
	my ($session, $orcid, $author_name) = @_;

	my $author_img_alt = EPrints::Utils::tree_to_utf8($session->html_phrase( "page:orcid_source:orcid_profile" )).$author_name;

	my $orcid_url = "https://orcid.org/" . $orcid;
	my $orcid_a = $session->make_element( "a", 
		href => $orcid_url, 
		title => "ORCID", 
		target => "_blank",
		class => "orcid",
	);
	my $orcid_img = $session->make_element( "img", 
		src => "/zora_zwonull/images/orcid_16x16.png",
		class => "orcid-url",
		alt => $author_img_alt
	);
	$orcid_a->appendChild( $orcid_img );

	my $orcid_span = $session->make_element( "span", class => "orcid-tooltip" );
	$orcid_span->appendChild( $session->make_text( $orcid_url ) );
	$orcid_a->appendChild( $orcid_span );

	return ( $orcid_a );
}
# END UZH CHANGE ZORA-498
# END UZH CHANGE ZORA-116

# UZH CHANGE ZORA-116 2017/10/13/mb render ORCID ID source
sub render_orcid_source
{
	my ($eprint, $session) = @_;

	my $source;

	if ($eprint->is_set( "source" ))
	{
		$source = $eprint->get_value("source");
	}
	else
	{
		$source = "author";
	}

	my $orcid_source_div = $session->make_element( "div",
		id => "orcid_source",
		class => "orcid-source"
	);

	$orcid_source_div->appendChild( $session->html_phrase( "page:orcid_source" ) );

	my $source_phrase = "page:orcid_source:unknown";
	$source_phrase = "page:orcid_source:author" if ( $source =~ /^author/ );
	$source_phrase = "page:orcid_source:crossref" if ( $source =~ /^CrossRef/ );
	$source_phrase = "page:orcid_source:pubmed" if ( $source =~ /^PubMed/ );
	$source_phrase = "page:orcid_source:wos" if ( $source =~ /^WOS/ );
	$source_phrase = "page:orcid_source:orcid" if ( $source =~ /^ORCID/ );

	$orcid_source_div->appendChild( $session->html_phrase( $source_phrase ) );

	return ( $orcid_source_div );
	
}
# END UZH CHANGE ZORA-116
