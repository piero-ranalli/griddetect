package Detection::Grid::DB;

# role which contains the DB and its queries

# when queried, populates the D::Grid attributes

use Moose::Role 'has';
use PDL;
use Storable;
use PDL::IO::Storable;  # this allows Storable to store piddles

# a set of tables containing the necessary information for ALL exposures
has dbrotra    => (is => 'rw', isa => 'PDL',     default => sub { pdl [] } );
has dbrotdec   => (is => 'rw', isa => 'PDL',     default => sub { pdl [] } );
has dbrapnt    => (is => 'rw', isa => 'PDL',     default => sub { pdl [] } );
has dbdecpnt   => (is => 'rw', isa => 'PDL',     default => sub { pdl [] } );
has dbcdelt1   => (is => 'rw', isa => 'PDL',     default => sub { pdl [] } );
has dbimages   => (is => 'rw', isa => 'ArrayRef', default => sub { [] } );
has dbexpmaps  => (is => 'rw', isa => 'HashRef',  default => sub { {} } );
has dbnovigns  => (is => 'rw', isa => 'HashRef',  default => sub { {} } );
has dbbkgs     => (is => 'rw', isa => 'HashRef',  default => sub { {} } );
# no need to duplicate what's already in D::Grid
#has dbsrclist  => (is => 'rw', isa => 'Str',      default => '' );
#has dbccf      => (is => 'rw', isa => 'Str',      default => '' );
#has dbodf      => (is => 'rw', isa => 'Str',      default => '' );

has storage  => (is => 'ro', isa => 'Str', default => 'griddetect.database');

sub dbstore {
    my $self = shift;

    # write the pointing info and the grid definition in a Storable
    my @things = (
		  $self->dbrotra,
		  $self->dbrotdec,
		  $self->dbrapnt,
		  $self->dbdecpnt,
		  $self->dbcdelt1,
		  $self->dbimages,
		  $self->dbexpmaps,
		  $self->dbnovigns,
		  $self->dbbkgs,
		  $self->srclist,
		  $self->ccf,
		  $self->odf,
		  $self->x_bound,
		  $self->y_bound,
		 );
    store \@things, $self->storage;
}

sub dbreload {
    my $self = shift;

    my $things = retrieve $self->storage;

    $self->dbrotra(   shift @$things );
    $self->dbrotdec(  shift @$things );
    $self->dbrapnt(   shift @$things );
    $self->dbdecpnt(  shift @$things );
    $self->dbcdelt1(  shift @$things );
    $self->dbimages(  shift @$things );
    $self->dbexpmaps( shift @$things );
    $self->dbnovigns( shift @$things );
    $self->dbbkgs(    shift @$things );
    $self->srclist(   shift @$things );
    $self->ccf(       shift @$things );
    $self->odf(       shift @$things );
    $self->x_bound(   shift @$things );
    $self->y_bound(   shift @$things );
}

sub dbstoreimgexp {
    my $self = shift;
    my %arg = @_;

    my @img = @{ $self->dbimages };
    my %exp = %{ $self->dbexpmaps };
    my %nov = %{ $self->dbnovigns };
    my %bkg = %{ $self->dbbkgs };
    push @img, $arg{img};
    $exp{ $arg{img} } = $arg{exp};
    $nov{ $arg{img} } = $arg{expnovign};
    $bkg{ $arg{img} } = $arg{bkg};
    $self->dbimages(  \@img );
    $self->dbexpmaps( \%exp );
    $self->dbnovigns( \%nov );
    $self->dbbkgs( \%bkg );

    # also add the pointing coordinates
    my $hdr = rfitshdr( $arg{img} );
    $self->dbrapnt(  $self->dbrapnt->append(  pdl $hdr->{RA_PNT} ) );
    $self->dbdecpnt( $self->dbdecpnt->append( pdl $hdr->{DEC_PNT}) );
    $self->dbcdelt1( $self->dbcdelt1->append( pdl $hdr->{CDELT1} ) );

    my ($rotra,$rotdec) = $self->transform( $hdr->{RA_PNT}, $hdr->{DEC_PNT} );
    $self->dbrotra(  $self->dbrotra->append(  pdl $rotra  ) );
    $self->dbrotdec( $self->dbrotdec->append( pdl $rotdec ) );
}

# sub dbstorebkg {
#     my $self = shift;
#     my %arg = @_;

#     my %bkg = %{ $self->dbbkgs };
#     $bkg{ $arg{img} } = $arg{bkg};
#     $self->dbbkg(  \%bkg );
# }

sub cellisempty {
    my $self = shift;

    if ( @{ $self->img } == 0 ) {
	return 1;
    } else {
	return 0;
    }
}


sub selectcell {
    my $self = shift;
    my ($i,$j) = @_;

    # x_bound and y_bound are expected to be numeric-sorted
    my $xmin = ${$self->x_bound}[$i];
    my $ymin = ${$self->y_bound}[$j];
    my $xmax = ${$self->x_bound}[$i+1];
    my $ymax = ${$self->y_bound}[$j+1];

    my $mask = $self->dbrotra >= $xmin-.3;
    $mask *=   $self->dbrotra <  $xmax+.3;
    $mask *=  $self->dbrotdec >= $ymin-.3;
    $mask *=  $self->dbrotdec <  $ymax+.3;

    # is it empty?
    unless( any($mask) ) {
	$self->img( [] );
	return;
    }

    # populate the main Grid file lists with the selected files

    # (this functionality was in D::G::GlobFiles, but now it is here)
    my @idx = $mask->which->list;

    my @img = @{$self->dbimages}[@idx];    # array slice
    $self->img( \@img );

    # @sel1..@sel6 are different variables because their refs are
    # stored in the object attributes; if the same variable was reused
    # every time, we'd overwrite everything

    my %h = %{$self->dbexpmaps};
    my @sel1 = @h{@img};   # hash slice; see perldoc perldata
    $self->expmap( \@sel1 );

    %h = %{$self->dbnovigns};
    my @sel2 = @h{@img};   # hash slice
    $self->novign( \@sel2 );

    %h = %{$self->dbbkgs};
    my @sel3 = @h{@img};   # hash slice
    $self->bkg( \@sel3 );

    my @sel4 = $self->dbrapnt->where($mask)->list;   # PDL slice
    $self->ra( \@sel4 );
    my @sel5 = $self->dbdecpnt->where($mask)->list;  # PDL slice
    $self->dec( \@sel5 );
    my @sel6 = $self->dbcdelt1->where($mask)->list;  # PDL slice
    $self->cdelt1( \@sel6 );

    # cell boundaries
    $self->cellxmin( $xmin );
    $self->cellxmax( $xmax );
    $self->cellymin( $ymin );
    $self->cellymax( $ymax );


    # the following is the old SQL query, only left as a reference for the current code which
    # does the same but without using a SQL database
    #
    # overlapping exposures: in rotra,rotdec coordinates, the exposure in ATLAS are separated
    # by ~15 rot-arcmin. So here's a quick hack...
    # 7 rot-arcmin / 60 = .117 rot-deg
    #my ($obsid,$pointing) = $self->sql->getlists("select distinct obs_id,pointing from pointings where rotra>=$xmin-.25 and rotra<$xmax+.25 and rotdec>=$ymin-.25 and rotdec<$ymax+.25;", 2);

}


# sub getallobsid {
#     my $self = shift;

#     my ($obsid) = $self->sql->getlists('select distinct obs_id from pointings', 1);
#     return $obsid;
# }


# sub getpointings {
#     my $self = shift;
#     my $obsid = shift;

#     my $oquote = $self->sql->getdbh->quote($obsid);
#     my ($point) = $self->sql->getlists("select distinct pointing from pointings where obs_id=$oquote", 1);
#     return $point;
# }



sub mmin {
    my $l = pdl( @_ );
    return $l->min;
}

sub mmax {
    my $l = pdl( @_ );
    return $l->max;
}


1;