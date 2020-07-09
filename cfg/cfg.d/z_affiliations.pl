# Affiliations table ZORA-736 2019/10/31/mb Project KooperationsDB IRO 
# - dataset affiliation
# - metadata fields
# - permissions
# - package EPrints::DataObj::Affiliation;
# (see https://wiki.eprints.org/w/API:EPrints/DataSet)
#
$c->{datasets}->{affiliation} = {
	class => "EPrints::DataObj::Affiliation",
	sqlname => "affiliation",
	sql_counter => "affiliationid",
	index => 1,
	order => 1,
};

# allow to manage records via admin screen; otherwise set to comment
push @{$c->{user_roles}->{admin}}, qw(
    +affiliation/create
    +affiliation/edit
    +affiliation/view
    +affiliation/destroy
    +affiliation/details
);

{
package EPrints::DataObj::Affiliation;

use base 'EPrints::DataObj';

use strict;

sub get_system_field_info
{
	my( $self ) = @_;

	return
	(
		# id (primary key)
		{
			name => 'affiliationid',
			type => 'counter',
			required => 1,
			can_clone => 0,
			sql_counter => 'affiliationid',
		},
		# datestamp
		{
			name => 'datestamp',
			type => 'time',
			required => 1,
			text_index => 0,
		},
		# last modification datestamp
		{
			name => 'lastmod', 
			type => 'time', 
			required => 0,
			import => 0,
			render_res => 'minute',
			render_style => 'short', 
			can_clone => 0,
		},
		# primary afid
		{
			name => 'primary_afid',
			type => 'id',
			sql_index => 1,
		},
		# primary type
		{
			name =>'primary_afid_type',
			type => 'set',
			options => [ 'scopus', 'grid', 'ror' ],
			input_style => 'medium',
		},
		# Other organisation identifiers (ROR, GRID, Scopus, ...)
		{
			name =>'org_identifiers',
			type => 'compound',
			multiple => 1,
			sql_index => 1,
			fields => [
				{
					sub_name =>'id',
					type => 'text',
				},
				{
					sub_name =>'type',
					type => 'set',
					options => [ 'grid', 'ror', 'scopus' ],
					input_style => 'medium',
				},
			],
		},
		# Organisation 
		{
			name =>'name',
			type => 'text',
			sql_index => 1,
		},
		# City
		{
			name =>'city',
			type => 'text',
			sql_index => 1,
		},
		# Country Code
		{
			name =>'country_code',
			type => 'text',
			input_cols => 3,
			sql_index => 1,
		},
		# Country
		{
			name =>'country',
			type => 'text',
			sql_index => 1,
		},
		# Source of affiliation (bibliographic database or other)
		{
			name =>'source',
			type => 'text',
		},
	);
}

######################################################################

=pod

=head2 Constructor Methods

=cut

#######################################################################

=over 4

=item $affiliation = EPrints::DataObj::Affiliation->new( $repo, $id )

The data object identified by $id.

=back

=cut

#########

sub new
{
	my( $self, $repo, $id ) = @_;

	return $repo->get_database->get_single(
		$repo->get_repository->get_dataset( "affiliation" ),
		$id 
	);
}


#########

=over 4

=item $thing = EPrints::DataObj::Affiliation->new_from_data( $repo, $known )

A new C<EPrints::DataObj::Affiliation> object containing data $known (a hash reference).

=back

=cut

#########

sub new_from_data
{
	my( $self, $repo, $known ) = @_;

	return $self->SUPER::new_from_data(
		$repo,
		$known,
		$repo->get_repository->get_dataset( "affiliation" )
	);
}


#########

=over 4

=item $defaults = EPrints::DataObj::SubmitterGroup->get_defaults( $session, $data )

Return default values for this object based on the starting data.

=back

=cut

#########

sub get_defaults
{
	my( $self, $repo, $data ) = @_;

	if( !defined $data->{affiliationid} )
	{
		$data->{affiliationid} = $repo->get_database->counter_next( "affiliationid" );
	}
	
	$data->{datestamp} = EPrints::Time::get_iso_timestamp();

	return $data;
}


######################################################################

=pod

=head2 Object Methods

=cut

######################################################################

=over 4

=item $affiliation->commit( [$force] )

Write this object to the database.

As modifications to files don't make any changes to the metadata, this will
always write back to the database.

=back

=cut

#########

sub commit
{
	my( $self, $force ) = @_;

	if( !$self->is_set( "datestamp" ) )
	{
		$self->set_value( "datestamp", EPrints::Time::get_iso_timestamp() );
	}

	$self->set_value( "lastmod" , EPrints::Time::get_iso_timestamp() );

	my $affiliation_ds = $self->{session}->get_repository->get_dataset( "affiliation" );
	$self->tidy;

	my $success = $self->SUPER::commit( $force );

	return( $success );
}


#########

=over 4

=item $foo = $affiliation->remove()

Remove this record from the data set (see L<EPrints::Database>).

=back

=cut

#########

sub remove
{
	my( $self ) = @_;

	my $rc = 1;

	my $database = $self->{session}->get_database;

	$rc &&= $database->remove( $self->{dataset}, $self->get_id );

	return $rc;
}

#########

=over 4

=item $dataobj = EPrints::DataObj->create_from_data( $session, $data, $dataset )
		
Create a new object of this type in the database.

$data is the data structured as with new_from_data.

$dataset is the dataset it will belong to (affiliation).

=back

=cut

#########

sub create_from_data
{
	my( $self, $repo, $data, $dataset ) = @_;

	my $new_affiliation = $self->SUPER::create_from_data( $repo, $data, $dataset );
	$repo->get_database->counter_minimum( "affiliationid", $new_affiliation->get_id );

	return $new_affiliation;
}

sub get_dataset_id
{
	my( $self ) = @_;
	return "affiliation";
}

sub get_affilobj
{
	my( $session, $afid ) = @_;
	
	my $dataset = $session->get_repository->dataset( "affiliation" );
	
	my $list = $dataset->search(
		filters => [{
			meta_fields => [qw( primary_afid )],
        	value => $afid,
		}]
	);
	
	my $dataobj = $list->item( 0 ); 	
	
	return $dataobj;
}

}

;
