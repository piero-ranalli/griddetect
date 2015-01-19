package Detection::Grid;

# this module contains most fields, plus a few generic methods
# All the interesting methods are in the roles

use Moose qw/has with/;
with 'Detection::Grid::DB';
with 'Detection::Grid::Catalogue';
#with 'Detection::Grid::GlobFiles';
#with 'Detection::Grid::SumBkgs';  # to be done manually in public version

with 'Detection::Grid::Ingest';
with 'Detection::Grid::Geometry';

use PDL;

use Carp;

# grid definition
has rotation => (is => 'rw', isa => 'Num');
has ra_cen   => (is => 'rw', isa => 'Num');
has dec_cen  => (is => 'rw', isa => 'Num');

# telescope parameters
#has 'eband'    => ( is => 'rw', isa => 'Str'      ); see below
has 'camera'   => ( is => 'rw', isa => 'Str', predicate => 'has_camera' );

# event files & co. (just the subset to be processed; all exposures are defined in D::G::DB)
has 'evt'     => ( is => 'rw', isa => 'ArrayRef' );
has 'img'     => ( is => 'rw', isa => 'ArrayRef' );
has 'expmap'  => ( is => 'rw', isa => 'ArrayRef' );
has 'novign'  => ( is => 'rw', isa => 'ArrayRef' );
has 'bkg'     => ( is => 'rw', isa => 'ArrayRef' );
has 'eband'   => ( is => 'rw', isa => 'ArrayRef' );
has 'pimin'   => ( is => 'rw', isa => 'ArrayRef' );
has 'pimax'   => ( is => 'rw', isa => 'ArrayRef' );
has 'expid'   => ( is => 'rw', isa => 'ArrayRef' );
has 'ra'      => ( is => 'rw', isa => 'ArrayRef' );  # coordinates of the pointings, set when
has 'dec'     => ( is => 'rw', isa => 'ArrayRef' );  # imgs are also set
has 'cdelt1'  => ( is => 'rw', isa => 'ArrayRef' );

has 'pointing' => ( is => 'rw', isa => 'ArrayRef' ); # the selected subset of $self->img
# no longer needed
#has 'obsid'    => ( is => 'rw', isa => 'ArrayRef' );

# cell
has 'cellxmin'  => ( is => 'rw', isa => 'Num' );
has 'cellxmax'  => ( is => 'rw', isa => 'Num' );
has 'cellymin'  => ( is => 'rw', isa => 'Num' );
has 'cellymax'  => ( is => 'rw', isa => 'Num' );

# frame
has 'centre_ra'   => ( is => 'rw', isa => 'Num' );
has 'centre_dec'  => ( is => 'rw', isa => 'Num' );
has 'framesizex'  => ( is => 'rw', isa => 'Num' );
has 'framesizey'  => ( is => 'rw', isa => 'Num' );

# input sources
has 'srclist' => ( is => 'rw', isa => 'Str' );

# SAS stuff
has 'ccf' => ( is => 'rw', isa => 'Str' );
has 'odf' => ( is => 'rw', isa => 'Str' );


# private:
has 'x_bound' => ( is => 'rw', isa => 'Any' );
#		    default => sub { [120, 123.9, 130] } );
has 'y_bound' => ( is => 'rw', isa => 'Any' );
#		    default => sub { [-50, -55.9,-56.4,-57.0,-57.4, -65] } );



# if the rotation changes, the database should also be updated!
# NB the centre of rotation is (RA,DEC)=(0,0)
#
# SQL> update pointings set rotra=ra_pnt*cos( -3.14/7.25)-dec_pnt*sin( -3.14/7.25), rotdec=ra_pnt*sin( -3.14/7.25)+dec_pnt*cos( -3.14/7.25);
# has 'rotation' => ( is => 'ro', isa => 'Num', default => -3.14/7.25 );






sub griddims {
    my $self = shift;
    return (int(@{ $self->x_bound }-1),int(@{ $self->y_bound })-1);
}


# sub get1stobsid {
#     # return obsid number of first datafile
#     my $self = shift;

#     return ${$self->obsid}[0];
# }


sub calc_radec_span {
    my $self = shift;

    my $ra = pdl( $self->ra );
    my $dec= pdl( $self->dec);
    my ($minra, $maxra)  =  $ra->minmax;
    my ($mindec,$maxdec) = $dec->minmax;

    my $cra = ( $maxra+$minra )/2;
    my $cdec= ($maxdec+$mindec)/2;
    my $sra = $maxra-$minra;
    my $sdec= $maxdec-$mindec;

    $self->centre_ra($cra);
    $self->centre_dec($cdec);

    my $deg2pix = 1/abs($self->cdelt1->[0]);

    $self->framesizex(($sra+.6)*$deg2pix);  # .6: add a bit more than 2 x 15arcmin
    $self->framesizey(($sdec+.6)*$deg2pix); # to include all of the FOV and be safe

    print "centre ra dec: $cra $cdec\n";
    print "span ra dec: $sra $sdec\n";
    printf("span in pixels: %f %f\n",$sra*$deg2pix,$sdec*$deg2pix);

}


__PACKAGE__->meta->make_immutable;



1;
