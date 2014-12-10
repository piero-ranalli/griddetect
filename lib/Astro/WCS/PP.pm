# Copyright (C) 2005-2014 Piero Ranalli
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Affero General Public License as
#  published by the Free Software Foundation, either version 3 of the
#  License, or (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Affero General Public License for more details.
#
#  You should have received a copy of the GNU Affero General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.

=head1 NAME

Astro::WCS::PP  --  WCS conversion utilities (Pure Perl)

=cut

package Astro::WCS::PP;

use Carp;
use Exporter;
@ISA = 'Exporter';

# most useful functions:
@EXPORT = qw/wcs_tan_pix2radec wcs_tan_L_pix2radec wcs_img_radec2pix
	     wcs_img_pix2radec wcs_evt_radec2pix wcs_cd_pix2radec
	     wcs_cd_radec2pix wcs_evt_pix2radec/;


# import trigonometric functions: if available, from PDL; else, from Math::Trig
BEGIN {
    eval {
	require PDL;
    };
    unless ($@) {
	PDL->import(qw/pdl asin acos atan/);
	#warn "loading PDL";
    } else {
	require Math::Trig;
	Math::Trig->import(qw/asin acos atan/);
	#warn "loading Math::Trig";
    };
}

=head1 VERSION

3.0 (2014/11/11)

=cut

our $VERSION = '3.0';

=head1 SYNOPSYS

 use Astro::WCS::PP;


In the following, $hdr is a hash ref containing a FITS header; in
practice, assuming that files are read using rfits() from PDL it
means:

 $hdr = $image->hdr;      # for images

or

 $hdr = $event->{hdr};    # for FITS tables aka event files

RA and Dec are always in degrees (with decimals).

=head2 Projections for images

=head3 Using CDELTn

 ($ra,$dec) = wcs_img_pix2radec($hdr,$x,$y)  # pixel to world

 ($x,$y) = wcs_img_radec2pix($hdr,$ra,$dec)  # world to pixel

 (NB: rotations [CROTA2] not yet implemented)

=head3 Using the CD matrix

 ($ra,$dec) = wcs_cd_pix2radec($hdr,$x,$y)  # pixel to world

 ($x,$y) = wcs_cd_radec2pix($hdr,$ra,$dec)  # world to pixel
          # This function depends on PDL::Slatec
          # for matrix inversion

=head2 Gnomonic projections for event files

Conversion between "physical pixels" and RA,Dec.

 ($ra,$dec) = wcs_evt_pix2radec($hdr,$x,$y)  #  phys.pixel to world

 ($x,$y) = wcs_evt_radec2pix($hdr,$ra,$dec)  # world to phys.pixel


=head2 Tangent plane projections

 ($ra,$dec) = wcs_tan_pix2radec($hdr,$x,$y)  #  pixel to world, rarely useful

 ($phys_x,$phys_y) = wcs_tan_L_pix2radec($hdr,$x,$y)
     # pixel to physical_pixel using CRPIX1L keywords etc.


=head1 DESCRIPTION

This module implements some WCS conversion functions in pure Perl, and
is PDL compatible. The formulae are taken from the FITS WCS definition
by Calabretta & Greisen 2002 (A&A 395,1077).

Several different possibilities exist to insert WCS information in
FITS headers, only a few of which are currently implemented. (Users
with needs not satisfied by this module might look for example at
Astro::WCS::LibWCS).

There is no code in this module to find out which routine should be
used given a random FITS file, though some guidelines are given
below. User inspection of the FITS header might be necessary.

This module uses PDL, if available, or Math::Trig as a fallback. One
routine (wcs_cd_radec2pix) only works is PDL and PDL::Slatec are
installed since it needs to invert a matrix.

The routines are divided according to the convention used to store the
WCS info in the FITS header files.

Note that using the "image" routines instead of the "event" ones when dealing
with an event file header (or viceversa) leads to division by zeroes
when trying to transform the reference pixel.

=over 4

=item - B<legacy> or B<AIPS> convention

Used by the Chandra (CIAO) and XMM-Newton (SAS) software for B<images>.
This convention uses the CRPIX[12], CDELT[12] and CRVAL[12] header keywords.
Rotations (through the CROTA2 keyword) are not yet implemented.

=item - B<CD> convention

Used e.g. by DS9 when saving images.

This convention replaces CDELT[12] with the CDi_j matrix. This module only
supports 2D (bidimensional) images (and not event files) which require
2x2 matrices.  The inversion of the matrix is needed for the inverse transform
(ra,dec => x,y); PDL::Slatec is currently used for this
purpose.

=item - B<event files> use a different projection

Chandra and XMM-Newton event files use different keywords (TCRPX[12],
TCDLT[12], TCRVL[12]) and a different ("gnomonic") projection. Hence
specialised routines are provided for them.

Also, while "image pixels" have a non-ambiguous definition, event
files use "physical pixels" which broadly correspond in size to
detector pixels (e.g., in Chandra, 1 phys.pixel = 1 detector pixel; in
XMM-Newton, 5 phys.pix = 1 PN pixel) though a rotation has already
been applied before producing the event files. This is the reason why
the CROTA2 keyword is missing in event file headers and images derived
from those, and why rotations are not yet implemented.


=back

Images and event files require different formulae for the WCS conversion,
thus different functions are provided.

=head2 Notes on individual functions

=over 4

=cut

sub wcs_tan_pix2radec { # wcs tranform on tangent plane
    # (template image, xpixel, ypixel)
    # returns: array with RA,DEC

    my $templ = shift;
    my $p1 = shift;
    my $p2 = shift;

    #my $naxis1 = $templ->hdr->{NAXIS1};  my $naxis2 = $templ->hdr->{NAXIS2};
    my $crpix1 = $templ->{CRPIX1};  my $crpix2 = $templ->{CRPIX2};
    my $cdelt1 = $templ->{CDELT1};  my $cdelt2 = $templ->{CDELT2};
    my $crval1 = $templ->{CRVAL1};  my $crval2 = $templ->{CRVAL2};

    return (
	    $crval1+$cdelt1*($p1-$crpix1),
	    $crval2+$cdelt2*($p2-$crpix2)
	    );

}



sub wcs_img_pix2radec { # (template image, xpixel, ypixel)
    # returns: array with RA,DEC

    my $templ = shift;
    my $p1 = shift;
    my $p2 = shift;

    my $debug=0;

    my $naxis1 = $templ->{NAXIS1};  my $naxis2 = $templ->{NAXIS2};
    my $crpix1 = $templ->{CRPIX1};  my $crpix2 = $templ->{CRPIX2};
    my $cdelt1 = $templ->{CDELT1};  my $cdelt2 = $templ->{CDELT2};
    my $crval1 = $templ->{CRVAL1};  my $crval2 = $templ->{CRVAL2};

    print "crpix=$crpix1 $crpix2\n" if ($debug);
    print "p1 p2=$p1 $p2\n" if ($debug);


    my $x = $cdelt1 * ($p1-$crpix1);
    my $y = $cdelt2 * ($p2-$crpix2);

    # fi   = atan( -y/x )
    # teta = atan( 180/pi / ||$tdlxy|| )
    # NB: in Calabretta&Greisen 2002 (A&A 395,1077) they use arg(-y,x)
    # without clear definition.. or is it a typo in Sect.7.3.1?
    # anyway, arg(-y,x) really means atan2(x,-y)
    $fi   = atan2d ($x,-$y);

    $teta = atan2d(180/3.141592/sqrt($x*$x+$y*$y), 1);

    print "x y=$tdlxy\n teta fi=$teta $fi\n" if ($debug);

    $sindelta = sind($teta) * sind($crval2)
	-cosd($teta) * cosd($fi) * cosd($crval2);

    $cosdelta = sqrt(1-$sindelta*$sindelta);
    $sinalfa1 = cosd($teta)*sind($fi) / $cosdelta;
    $cosalfa1 = ( sind($teta)*cosd($crval2) 
	  + cosd($teta)*cosd($fi)*sind($crval2) ) / $cosdelta;
    $alfa1 = atan2d ($sinalfa1,$cosalfa1);

    $alfa = $alfa1 + $crval1;
    $delta = asind($sindelta);

    print "alfa=$alfa delta=$delta\n" if ($debug);

    return ($alfa,$delta);

}




sub atan2d {
    my $a=shift; my $b=shift;
    return atan2($a,$b)/3.14159265*180;
}
sub asind {
    my $a=shift;
    return asin($a)/3.14159265*180;
}
# sub atand {
#     my $a=shift;
#     return atan($a)/3.14159265*180;
# }
sub sind {
    my $a=shift;
    return sin($a/180*3.14159265);
}
sub cosd {
    my $a=shift;
    return cos($a/180*3.1415926535897932);
}




sub wcs_img_radec2pix { # viceversa la reazione inversa
    # (template image, ra, dec)
    # returns: array with p1,p2 (pixel)

    my $templ = shift;
    my $pi = 3.1415926535897932;
    my $duepi = 2*$pi;
    my $d2r = $pi/180;
    my $ra =   $d2r * shift;
    my $dec =  $d2r * shift;


    my $debug=0;

    my $naxis1 =      $templ->{NAXIS1};  my $naxis2 =      $templ->{NAXIS2};
    my $crpix1 =      $templ->{CRPIX1};  my $crpix2 =      $templ->{CRPIX2};
    my $cdelt1 = $d2r*$templ->{CDELT1};  my $cdelt2 = $d2r*$templ->{CDELT2};
    my $crval1 = $d2r*$templ->{CRVAL1};  my $crval2 = $d2r*$templ->{CRVAL2};

    print "crpix=$crpix1 $crpix2\n" if ($debug);
    print "ra dec=$ra $dec\n" if ($debug);

    # eq 5, ricordando che fi_p = 180 per le proiezioni zenitali
    my $fi = $pi + atan2( -cos($dec)*sin($ra-$crval1),
	sin($dec)*cos($crval2)-cos($dec)*sin($crval2)*cos($ra-$crval1) );
    print "fi=$fi\n" if ($debug);

    if (ref($fi) eq 'PDL') {
	require PDL;
	my $idx = which($fi>$duepi);
	#$fi->index($idx) -= 360;
	my $tmp = $fi->index($idx);
	$tmp -= $duepi;
    } else { # e' uno scalare
	$fi -= $duepi if ($fi>$duepi);
    }

    my $sinfi = sin($fi);
    my $tgfi = $sinfi/cos($fi);

    my $tgficheck = cos($dec)*sin($ra-$crval1) /
	(cos($dec)*sin($crval2)*cos($ra-$crval1)
	 - sin($dec)*cos($crval2) );

    print "fi=$fi tgfi tgficheck=$tgfi $tgficheck\n" if ($debug);

    my $tgteta = ( sin($dec)*sin($crval2)+
		   cos($dec)*cos($crval2)*cos($ra-$crval1) )
	/ cos($dec)/sin($ra-$crval1) * $sinfi;

    print "tgteta=$tgteta\n" if ($debug);

    my $Rteta = 1/$tgteta; #180/3.14159265/$tgteta;
    my $x = $Rteta * $sinfi;
    my $y = -$Rteta * cos($fi);

    print "Rteta x y=$Rteta $x $y\n" if ($debug);

    $p1 = $x / $cdelt1 + $crpix1;
    $p2 = $y / $cdelt2 + $crpix2;

    print "p1 p2=$p1 $p2\n" if ($debug);

    return ($p1,$p2);

}









sub wcs_evt_radec2pix { # viceversa la reazione inversa

=item ($x,$y) = B<wcs_evt_radec2pix>($img->hdr,$ra,$dec)

Gnomonic projection from Calabretta & Griesen (Eq.5); uses
TCTYPn=="RA--TAN" or "DEC--TAN").

=cut

    # (reference to header template event file, ra, dec)
    # returns: array with p1,p2 (pixel)
    # NB: IN INPUT SOLO L'HEADER! NON TUTTO IL FILE, CHE NON E' NECESSARIO

    # versione con i conti in radianti

    # ah, e funziona anche se in input/output ci sono dei pdl


    my $templ = shift;
    my $ra = shift; # in gradi
    my $dec = shift; # in gradi
    $ra = $ra*3.14159265/180;
    $dec= $dec*3.14159265/180;
    my $debug=0;

    # find relevant keywords (taken from align_evt)
    my ($ind,$val);
    for my $k (keys %$templ) {
	next unless (defined($templ->{$k})); # sometimes the CONTINUE keyword may
	                                     # have a null value, and this prompts
	                                     # a warning when using -w
	if ($templ->{$k} =~ m/(RA|DEC)---?TAN/) {
	    my $coor = $1;
	    unless ($k =~ m/TCTYP(\d+)/) {
		unless ($k =~ m/^REF[XY]/) {
		    # REFX... are safe in XMM-Newton data
		    print "Unexpected keyword name $k with value matching '/(RA|DEC)---?TAN/'\n";
		}
		next;
	    }

	    $ind{$coor} = $1;
	    $val{$coor} = $templ->{"TCRVL$1"};
	}
    }

    # get values for keywords
    my $crpix1 = $templ->{"TCRPX$ind{RA}"};
    my $crpix2 = $templ->{"TCRPX$ind{DEC}"};
    my $cdelt1 = $templ->{"TCDLT$ind{RA}"} *3.14159265/180;
    my $cdelt2 = $templ->{"TCDLT$ind{DEC}"} *3.14159265/180;
    my $crval1 = $templ->{"TCRVL$ind{RA}"} *3.14159265/180;
    my $crval2 = $templ->{"TCRVL$ind{DEC}"} *3.14159265/180;

    print "crpix=$crpix1 $crpix2\n" if ($debug);
    print "ra dec=$ra $dec\n" if ($debug);

    # eq 5, ricordando che fi_p = 180 per le proiezioni zenitali
    my $fi = 3.14159265 + atan2( -cos($dec)*sin($ra-$crval1),
	sin($dec)*cos($crval2)-cos($dec)*sin($crval2)*cos($ra-$crval1) );
    #if ($fi>360) { $fi-=360; }

    my $sinfi = sin($fi);


    # ancora eq.5 nell'articolo citato
    my $tmp = sin($dec)*sin($crval2) +
	cos($dec)*cos($crval2)*cos($ra-$crval1);

    # il controllo su tmp e' necessario, perche' se RA=CRVAL1 e DEC=CRVAL2,
    # allora tmp=1, e puo' capitare che per arrotondamenti venga tmp>1
    # (per una n-esima cifra decimale...), e in quel caso il risultato 
    # di asin sarebbe un bel nan... invece lo intercettiamo prima.
    #
    # che poi, questo era vero usando la versione con le variabili in gradi,
    # con i radianti ci sono meno conversioni e la precisione e' migliore...
    if (ref($tmp) eq 'PDL') {
	require PDL;
	my $msk = $tmp>1;
	(my $xxx = $tmp->where($msk)) .= 1;
    } else { #scalare
	if ($tmp>1) { $tmp = 1; }
    }
    print($tmp,"\n") if ($debug);

    my $teta = asin( $tmp );

    my $Rteta = cos($teta)/sin($teta);

    my $x = $Rteta * $sinfi;
    my $y = -$Rteta * cos($fi);

    print "Rteta x y=$Rteta $x $y\n" if ($debug);

    $p1 = $x / $cdelt1 + $crpix1;
    $p2 = $y / $cdelt2 + $crpix2;

    print "p1 p2=$p1 $p2\n" if ($debug);

    return ($p1,$p2);

}


sub wcs_cd_pix2radec { # (template header, xpixel, ypixel)
    # returns: array with RA,DEC

=item ($ra,$dec) = B<wcs_cd_pix2radec>($img,$x,$y)

Using the "CD formalism" in Greisen & Calabretta 2002 (eq.3)
and only valid for 2D images.

This format is used e.g. by ds9 when saving FITS images.

=cut

    my $templ = shift;
    my $p1 = shift;
    my $p2 = shift;

    my $debug=0;

    my $naxis1 = $templ->{NAXIS1};  my $naxis2 = $templ->{NAXIS2};
    my $crpix1 = $templ->{CRPIX1};  my $crpix2 = $templ->{CRPIX2};
    my $cd1_1  = $templ->{CD1_1};   my $cd1_2  = $templ->{CD1_2};
    my $cd2_1  = $templ->{CD2_1};   my $cd2_2  = $templ->{CD2_2};
    my $crval1 = $templ->{CRVAL1};  my $crval2 = $templ->{CRVAL2};

    print "crpix=$crpix1 $crpix2\n" if ($debug);
    print "p1 p2=$p1 $p2\n" if ($debug);


    my $x = $cd1_1 * ($p1-$crpix1) + $cd1_2 * ($p2-$crpix2);
    my $y = $cd2_1 * ($p1-$crpix1) + $cd2_2 * ($p2-$crpix2);

    # fi   = atan( -y/x )
    # teta = atan( 180/pi / ||$tdlxy|| )
    # NB: in Calabretta&Greisen 2002 (A&A 395,1077) they use arg(-y,x)
    # without clear definition.. or is it a typo in Sect.7.3.1?
    # anyway, arg(-y,x) really means atan2(x,-y)
    $fi   = atan2d ($x,-$y);

    $teta = atan2d(180/3.141592/sqrt($x*$x+$y*$y), 1);

    print "x y=$tdlxy\n teta fi=$teta $fi\n" if ($debug);

    $sindelta = sind($teta) * sind($crval2)
	-cosd($teta) * cosd($fi) * cosd($crval2);

    $cosdelta = sqrt(1-$sindelta*$sindelta);
    $sinalfa1 = cosd($teta)*sind($fi) / $cosdelta;
    $cosalfa1 = ( sind($teta)*cosd($crval2) 
	  + cosd($teta)*cosd($fi)*sind($crval2) ) / $cosdelta;
    $alfa1 = atan2d ($sinalfa1,$cosalfa1);

    $alfa = $alfa1 + $crval1;
    $delta = asind($sindelta);

    print "alfa=$alfa delta=$delta\n" if ($debug);

    return ($alfa,$delta);

}

sub wcs_cd_radec2pix { # viceversa la reazione inversa
    require PDL;
    require PDL::Slatec;
    # (template header, ra, dec)
    # returns: array with p1,p2 (pixel)

=item ($x,$y) = B<wcs_cd_radec2pix>($img,$ra,$dec)

Uses the "CD formalism" in Greisen & Calabretta 2002 (eq.3)
and only valid for 2D images.
This format is used by ds9 when saving FITS images.

This function has a dependence on PDL::Slatec (for matrix inversion).

=cut

    my $hdr = shift;
    my $ra = shift;
    my $dec = shift;

    my $debug=0;

    my $naxis1 = $hdr->{NAXIS1};  my $naxis2 = $hdr->{NAXIS2};
    my $crpix1 = $hdr->{CRPIX1};  my $crpix2 = $hdr->{CRPIX2};
    my $cd1_1  = $hdr->{CD1_1};   my $cd1_2  = $hdr->{CD1_2};
    my $cd2_1  = $hdr->{CD2_1};   my $cd2_2  = $hdr->{CD2_2};
    my $crval1 = $hdr->{CRVAL1};  my $crval2 = $hdr->{CRVAL2};

    # invert the transformation matrix:
    my $cdmat = pdl( [ [$cd1_1,$cd1_2], [$cd2_1,$cd2_2] ] );
    my $cdinv = $cdmat->matinv;

    print "crpix=$crpix1 $crpix2\n" if ($debug);
    print "ra dec=$ra $dec\n" if ($debug);

    # eq 5, ricordando che fi_p = 180 per le proiezioni zenitali
    my $fi = 180 + atan2d( -cosd($dec)*sind($ra-$crval1),
	sind($dec)*cosd($crval2)-cosd($dec)*sind($crval2)*cosd($ra-$crval1) );

    if (ref($fi) eq 'PDL') {
	require PDL;
	my $idx = which($fi>360);
	$fi->index($idx) -= 360;
    } else { # e' uno scalare
	$fi -= 360;
    }

    my $sinfi = sind($fi);
    my $tgfi = $sinfi/cosd($fi);

    my $tgficheck = cosd($dec)*sind($ra-$crval1) /
	(cosd($dec)*sind($crval2)*cosd($ra-$crval1)
	 - sind($dec)*cosd($crval2) );

    print "fi=$fi tgfi tgficheck=$tgfi $tgficheck\n" if ($debug);

    my $tgteta = ( sind($dec)*sind($crval2)+
		   cosd($dec)*cosd($crval2)*cosd($ra-$crval1) )
	/ cosd($dec)/sind($ra-$crval1) * $sinfi;

    print "tgteta=$tgteta\n" if ($debug);

    my $Rteta = 180/3.14159265/$tgteta;
    my $x = $Rteta * $sinfi;
    my $y = -$Rteta * cosd($fi);

    print "Rteta x y=$Rteta $x $y\n" if ($debug);

    my ($p1,$p2);
    if (ref($x) eq 'PDL') {
	my (@p1,@p2);
	for my $i (0..$x->dim(0)-1) {
	    my $p1p2 = $cdinv x pdl( [[$x->(($i))],[$y->(($i))]] );
	    my ($tmp1,$tmp2) = $p1p2->list;
	    push(@p1,$tmp1);
	    push(@p2,$tmp2);
	}
	$p1 = pdl( @p1 );
	$p2 = pdl( @p2 );

    } else {
	# two scalars
	my $p1p2 = $cdinv x pdl( [[$x],[$y]] );
	($p1,$p2) = $p1p2->list;
    }

    $p1 += $crpix1;
    $p2 += $crpix2;

    print "p1 p2=$p1 $p2\n" if ($debug);

    return ($p1,$p2);

}


sub wcs_evt_pix2radec { # (template header, xpixel, ypixel)
#     # returns: array with RA,DEC

    # see Eqs. 2, 14,15, 54 in Calabretta & Greisen

    my $templ = shift;
    my $p1 = shift;
    my $p2 = shift;

    my $debug=0;

    # find relevant keywords (taken from align_evt)
    my (%ind,%val);
    foreach (keys %$templ) {
	if ($templ->{$_} =~ /(RA|DEC)---?TAN/) {
	    my $coor = $1;
	    unless (/TCTYP(\d+)/) {
		print "Unexpected keyword name $_ with value matching '/(RA|DEC)---?TAN/'\n";
		next;
	    }

	    $ind{$coor} = $1;
	    $val{$coor} = $templ->{"TCRVL$1"};
	}
    }

    # get values for keywords
    my $crpix1 = $templ->{"TCRPX$ind{RA}"};  
    my $crpix2 = $templ->{"TCRPX$ind{DEC}"};  
    my $cdelt1 = $templ->{"TCDLT$ind{RA}"};  
    my $cdelt2 = $templ->{"TCDLT$ind{DEC}"};  
    my $crval1 = $templ->{"TCRVL$ind{RA}"};  
    my $crval2 = $templ->{"TCRVL$ind{DEC}"};  

    print "crpix=$crpix1 $crpix2\n" if ($debug);
    print "p1 p2=$p1 $p2\n" if ($debug);


    my $x = $cdelt1 * ($p1-$crpix1);
    my $y = $cdelt2 * ($p2-$crpix2);

#     # fi   = atan( -y/x )
#     # teta = atan( 180/pi / ||$tdlxy|| )
#     # NB: in Calabretta&Greisen 2002 (A&A 395,1077) they use arg(-y,x)
#     # without clear definition.. or is it a typo in Sect.7.3.1?
#     # anyway, arg(-y,x) really means atan2(x,-y)
    my $fi   = atan2 ($x,-$y);
    my $Rteta= sqrt($x*$x+$y*$y);

    my $teta = atan(180/3.141592/$Rteta);

    print "x y=$tdlxy\n teta fi=$teta $fi\n" if ($debug);

    my $alfap_d = $crval1;
    my $deltap = $crval2*3.141592/180;
    my $fip = 3.141592;

    my $alfa = $alfap_d +
	atan2d( -cos($teta)*(sin($fi-$fip)),
		sin($teta)*cos($deltap)-cos($teta)*sin($deltap)*cos($fi-$fip) );
    my $delta = asind(sin($teta)*sin($deltap) + cos($teta)*cos($deltap)*
		                                 cos($fi-$fip));



#     my $delta = $teta;

    print "alfa=$alfa delta=$delta\n" if ($debug);

    return ($alfa,$delta);

}



sub wcs_tan_L_pix2radec {

=item ($phys_x,$phys_y) = B<wcs_tan_L_pix2radec>($img, $x, $y)

WCS tranform on tangent plane.
Uses CRPIX1L (and similar) instead of CRPIX1 etc. to return "physical" pixels

This is the only routine that checks for the existence in the header of the
necessary keywords, since they are not always present.

=cut

    my $templ = shift;
    my $p1 = shift;
    my $p2 = shift;

    unless (exists($templ->{CRPIX1L}) and exists($templ->{CRPIX2L}) and
	    exists($templ->{CDELT1L}) and exists($templ->{CDELT2L}) and
	    exists($templ->{CRVAL1L}) and exists($templ->{CRVAL2L})) {
	croak "Cannot find the keywords needed for tangent plane projection.\n";
    }

    #my $naxis1 = $templ->hdr->{NAXIS1};  my $naxis2 = $templ->hdr->{NAXIS2};
    my $crpix1 = $templ->{CRPIX1L};  my $crpix2 = $templ->{CRPIX2L};
    my $cdelt1 = $templ->{CDELT1L};  my $cdelt2 = $templ->{CDELT2L};
    my $crval1 = $templ->{CRVAL1L};  my $crval2 = $templ->{CRVAL2L};

    return (
	    $crval1+$cdelt1*($p1-$crpix1),
	    $crval2+$cdelt2*($p2-$crpix2)
	    );

}



1;

__END__

=back

=head1 INSTALLATION

The standard sequence for Perl modules:

 perl Makefile.PL
 make
 make test
 make install

=head1 BUGS

Functions are not checking for the existence of their needed keywords
(nor for the sanity of the input).

Only special cases are implemented here, while the FITS standard/AIPS
convention comprises many more projection types. Also, rotations are
only handled by the two routines using the CD matrix.

=head1 TODO

=over 4

=item # implement PCi_j formalism, e.g. for IDL-generated images

=item # checks for keywords

=item # detection of formalism (CD or legacy)


=back

=head1 HISTORY

3.0 -- 2014/11/11
  Public version. Package has been reorganised, input is consistent
  among all functions, function names have been changed.

2.31 -- 2013/8/11
  put in proper module distribution
  use strict and warnings experimentally turned on

2.3 -- 2012/7/19
  wcstransfinv now makes all calculations in radians. This addresses a
  strange bug which presents when fi~360 degrees => cos fi = 1 and
  which leads to wrong values of y in output.  In practice, it happens
  on the XMM-CDFS ratemap (whose WCS is that of a NicoNew's expmap)
  for values of (RA,DEC) = (53.1271160027375,-28.0729683940378).
  I think that all other functions should also immediately switch to radiants.

2.21 -- 2012/1/30
  tgwcs* now require $hdr instead of $img

2.2 -- 2012/1/11
  Added tgwcstransfL and POD documentation.

2.1 -- sometime in 2011
  Added CD formalism.

2.0 -- 2010/6/17
  All code should now be PDL safe.

First functions written about year 2005.


=head1 AUTHOR

Piero Ranalli, C<< <piero.ranalli at noa.gr> >>

=head1 BUGS

Please report any bugs or feature requests to C<pranalli-github@gmail.com>.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Astro::WCS::PP

=cut
