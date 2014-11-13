package Atlas::Grid::DB;

# role which contains the DB queries

use Moose::Role 'has';
use PDL;
use PDL::PGSQL;


# pointer to PDL::PGSQL
has 'sql'     => ( is => 'ro', isa => 'Any', builder => 'sqlbuild' );



sub sqlbuild {
    # initialize the db hook
    my $self = shift;

    my $sql = PDL::PGSQL->new('atlas');
    return $sql;
}


sub selectcell {
    my $self = shift;
    my ($i,$j) = @_;

    my $xmin = ${$self->x_bound}[$i];
    my $ymin = ${$self->y_bound}[$j+1];  #NB the y is reverse ordered
    my $xmax = ${$self->x_bound}[$i+1];
    my $ymax = ${$self->y_bound}[$j];

    # overlapping exposures: in rotra,rotdec coordinates, the exposure in ATLAS are separated
    # by ~15 rot-arcmin. So here's a quick hack...
    # 7 rot-arcmin / 60 = .117 rot-deg
    my ($obsid,$pointing) = $self->sql->getlists("select distinct obs_id,pointing from pointings where rotra>=$xmin-.25 and rotra<$xmax+.25 and rotdec>=$ymin-.25 and rotdec<$ymax+.25;", 2);

    $self->obsid($obsid);
    $self->pointing($pointing);

    $self->cellxmin( $xmin );
    $self->cellxmax( $xmax );
    $self->cellymin( $ymin );
    $self->cellymax( $ymax );
}


sub getallobsid {
    my $self = shift;

    my ($obsid) = $self->sql->getlists('select distinct obs_id from pointings', 1);
    return $obsid;
}


sub getpointings {
    my $self = shift;
    my $obsid = shift;

    my $oquote = $self->sql->getdbh->quote($obsid);
    my ($point) = $self->sql->getlists("select distinct pointing from pointings where obs_id=$oquote", 1);
    return $point;
}


sub dbupload {
    ...
}

sub mmin {
    my $l = pdl( @_ );
    return $l->min;
}

sub mmax {
    my $l = pdl( @_ );
    return $l->max;
}


1;
