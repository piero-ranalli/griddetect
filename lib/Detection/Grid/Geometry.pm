package Detection::Grid::Geometry;

use Moose::Role 'has';
use PDL;

sub transform {
    my $self = shift;
    my ($ra,$dec) = @_;

    my $rot = 3.14159265359/180 * $self->rotation; # deg -> rad

    my $c = cos($rot);
    my $s = sin($rot);

    my $rotra  = ($ra-$self->ra_cen)*$c - ($dec-$self->dec_cen)*$s;
    my $rotdec = ($ra-$self->ra_cen)*$s + ($dec-$self->dec_cen)*$c;

    return ($rotra,$rotdec);
}


# correct but not needed
# sub haversine {     # ra,dec in degrees;  output in degrees
#     my $self = shift;
#     my $d2r = 180/3.14159265359;
#     my ($ra1,$dec1,$ra2,$dec2) = map { $_ * $d2r  } @_;  # deg->rad

#     my $t1 = sin(($dec1-$dec2)/2) ** 2;
#     my $t2 = cos($dec1) * cos($dec2) * sin(($ra1-$ra2)/2)**2;
#     my $ha = 2 * asin(sqrt( $t1+$t2 ));

#     return $ha / $d2r;  # rad->deg
# }




1;
