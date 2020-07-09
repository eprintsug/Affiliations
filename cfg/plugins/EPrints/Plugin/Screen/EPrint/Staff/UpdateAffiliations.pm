######################################################################
#
#  Screen::EPrint::Staff::UpdateAffiliations plugin - 
#  Update creator/editor affiliations from Scopus Abstract
#  Retrieval API via Scopus eid or via DOI
#
#  Part of https://idbugs.uzh.ch/browse/ZORA-736
#
#  2020/06/11/mb
#
######################################################################
#
#  Copyright 2020- University of Zurich. All Rights Reserved.
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


=head1 NAME

EPrints::Plugin::Screen::EPrint::Staff::UpdateAffilations

Provides an interface to allow repository editors to update affiliations
from Scopus to creators/editors of an eprint

=cut

package EPrints::Plugin::Screen::EPrint::Staff::UpdateAffiliations;

use base 'EPrints::Plugin::Screen::EPrint';

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{actions} = [qw/ update_affiliations /];

	$self->{appears} = [ {
		place => "eprint_editor_actions",
		action => "update_affiliations",
		position => 1900,
	}, ];

	return $self;
}

sub obtain_lock
{
	my( $self ) = @_;

	return $self->could_obtain_eprint_lock;
}

sub about_to_render 
{
	my( $self ) = @_;

	$self->EPrints::Plugin::Screen::EPrint::View::about_to_render;
}


sub allow_update_affiliations
{
	my( $self ) = @_;

	# only show button if there is a DOI or a Scopus eid
	my $eprint = $self->{processor}->{eprint};
	return 0 unless ($eprint->exists_and_set( "doi" ) || $eprint->exists_and_set( "scopus_cluster" ));  

	return 0 unless $self->could_obtain_eprint_lock;
	
	return $self->allow( "eprint/edit:editor" ); 
}

sub action_update_affiliations
{
	my( $self ) = @_;

	$self->{processor}->{screenid} = "EPrint::View";

	my $repo = $self->{repository};
	my $eprint = $self->{processor}->{eprint};

       	my $plugin = $repo->plugin( "Import::ScopusAbstract" );
	unless( defined $plugin )
       	{
               	$self->{processor}->add_message(
                        "warning",
                        $self->html_phrase( "no_plugin" ) ); 
		return;
       	}
	my $success = $plugin->update_authors_subject( $eprint );

	return;
}

1;


