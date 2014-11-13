package Atlas::Grid::Catalogue;

# better to work with ftools, not to have to map the catalogue in the DB

use Moose::Role qw/has after/;
use Piero::Ftools::Pfiles;
use File::Temp 'tempfile';

has 'catfile'     => ( is => 'rw', isa => 'Str' );
#has 'env'         => ( is => 'rw', isa => 'Str' );

sub cleancat {
    my $self = shift;
    my $sas = shift;

    my $pf = Pfiles->new;
#    $self->env( $pf->env );

    my $c = $self->catfile;
    my ($th1,$tn1) = tempfile( 'atlastmpXXXX', SUFFIX => '.fits' );
    my ($th2,$tn2) = tempfile( 'atlastmpXXXX', SUFFIX => '.fits' );
    my $r = $self->rotation;

    my $x1 = $self->cellxmin;
    my $x2 = $self->cellxmax;
    my $y1 = $self->cellymin;
    my $y2 = $self->cellymax;


    my $cmds = <<FTOOLS;
 ftcalc $c   $tn1 ROT_RA  'RA*cos($r)-DEC*sin($r)' clobber=yes
 ftcalc $tn1 $tn2 ROT_DEC 'RA*sin($r)+DEC*cos($r)' clobber=yes
 ftselect $tn2 $tn1 'ROT_RA>=$x1'   clobber=yes
 ftselect $tn1 $tn2 'ROT_RA<$x2'    clobber=yes
 ftselect $tn2 $tn1 'ROT_DEC>=$y1'  clobber=yes
 ftselect $tn1 $tn2 'ROT_DEC<$y2'   clobber=yes
 mv $tn2 ok_$c
FTOOLS

    for my $c ( split('\n',$cmds) ) {
	$sas->call( $pf->env.$c );
    }
}



1;
