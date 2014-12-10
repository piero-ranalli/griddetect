package XMMSAS::Extract;
use 5.010;

use Moose qw/has after with/;
with 'XMMSAS::Call';

use Carp;
use PDL;

no if $] >= 5.018, warnings => "experimental::smartmatch";


=head1 NAME

XMMSAS::Extract  --  Perl interface to XMM-Newton SAS to extract data products

=head1 VERSION

Version 2.01;

=cut

our $VERSION = '2.01';

=head1 SYNOPSIS

 my $sas = XMMSAS::Extract->new;

 $sas->evtfile("eventfile.fits");  # input evt

 my $boolean = $sas->camera_is_pn;    # boolean

 $sas->ccf("path/to/ccf.cif");    # provided by XMMSAS::Call

 $sas->odf("path/to/...SUM.SAS"); # provided by XMMSAS::Call

 $sas->attitude("path/to/...AttHk.fits");

 # $sas->verbose([01]); # set chatter level; default: 1

 $sas->addexpr('expr1','expr2',...); # adds filtering expressions

 $sas->add_predefined_expr($filter);
   # (or $sas->add_predefired_expr("not $filter");)
   # adds an expression from a library, appropriate for the camera.
   # For $filter, see B<EXPRESSION LIBRARY> below.
   # The filter can be negated by putting "not" in front of it.

$sas->resetexpr;  # resets filtering to standard pattern only

$sas->excludesrc(@xylist);

$sas->evtextract("outfile.fits",{ SELFREPLACE => 0 });
  # SELFREPLACE=>1 replaces the main event file with the newly filtered one

$sas->addbadpixels;

$sas->mosaic_attcalc;  # needed for mosaic-mode data

$sas->reproject($RA,$DEC);

$sas->imgextract("outfile.fits",[ {DETCOORDS=>1,
                                   BINSIZE=>32,
                                   XYIMGMINMAX=>[$xmin,$xmax,$ymin,$ymax]
                                  } ]);

$sas->attitude($attfile);
$sas->eexpmap($img,"outfile.fits",$pimin,$pimax,$opt);

$expr = $sas->formatexpr; # return selection expression used by
          # evtextract and similars. Useful for debug purposes.

=head1 DESCRIPTION

=over 4

=cut

# public
has 'evtfile' => ( is => 'rw', isa => 'Str' );
has 'attitude'=> ( is => 'rw', isa => 'Str', predicate => 'has_attitude' );

has 'verbose' => ( is => 'rw', isa => 'Num' );

has 'hdr'     => ( is => 'rw', isa => 'HashRef' );
has 'camera'  => ( is => 'rw', isa => 'Str' );
has 'submode' => ( is => 'rw', isa => 'Str' );
has 'revolut' => ( is => 'rw', isa => 'Str' );


# private
has 'exprlist' => ( is => 'rw', isa => 'ArrayRef', predicate => 'has_exprlist' );




after 'evtfile' => sub {
    my $self = shift;
    my $file = shift;

    # reads evtfile's header and sets basic things
    if ($file) {
	$self->verbose(1);
	$self->hdr( rfitshdr($file) );

	$self->camera( $self->hdr->{INSTRUME} );
	$self->submode( $self->hdr->{SUBMODE} );
	$self->revolut( $self->hdr->{REVOLUT} );

	# only setup exprlist if we are initializing the objects
	# (don't do it if this is a evtfile chang made by
	# evtextract(..., SELFREPLACE=>1}) )
	$self->resetexpr unless ($self->has_exprlist);
    }
};

sub camera_is_pn {
    my $self = shift;

    return( $self->camera eq 'EPN' );
}

sub resetexpr {
    my $self = shift;
    $self->exprlist( [] );
    $self->setstdexpr;
}


sub setstdexpr {

=item setstdexpr()

Sets standard PATTERN expressions appropriate for the camera.  (Not
FLAG nor XMMEA, or the corner events would be lost).

If you want also #XMMEA and FLAG, use: $sas->add_predefined_expr('stdfilter')

=cut

    my $self = shift;
    if ($self->camera eq 'EPN') {
	push(@{ $self->exprlist },
	     'PATTERN<=4'#,
	    );
    } else {
	push(@{ $self->exprlist },
	     'PATTERN<=12'#,
	    );
    }
}


sub addexpr {
    my $self = shift;
    push(@{ $self->exprlist }, @_);
}

sub evtextract {
    my $self = shift;
    my $out = shift;
    my $opts = shift;

    my $expr = $self->formatexpr;
    my $cmd = "evselect table=".$self->evtfile.":EVENTS withfilteredset=yes ".
	"expression=$expr ".
	"filtertype=expression keepfilteroutput=yes updateexposure=yes ".
	"filterexposure=yes filteredset=$out";
    $self->call($cmd);

    $self->evtfile($out) if ($$opts{SELFREPLACE});
}

sub imgextract {
    # only imagebinning=binSize for now

    my $self = shift;
    my $out = shift;
    my $opt = shift;
    my $expr = $self->formatexpr;
    my $xycol = $$opt{DETCOORDS} ?
	"xcolumn='DETX' ycolumn='DETY'" :
	    "xcolumn='X' ycolumn='Y'";
    my $binsize = $$opt{BINSIZE} ?
	"ximagebinsize=$$opt{BINSIZE} yimagebinsize=$$opt{BINSIZE}" :
	"ximagebinsize=32 yimagebinsize=32";

    my $minmax = $$opt{XYIMGMINMAX} ?
	"ximagemin=$$opt{XYIMGMINMAX}[0] ximagemax=$$opt{XYIMGMINMAX}[1] yimagemin=$$opt{XYIMGMINMAX}[2] yimagemax=$$opt{XYIMGMINMAX}[3]" :
	'';

    my $cmd = "evselect table=".$self->evtfile.":EVENTS imagebinning='binSize' ".
	"expression=$expr withimageset=yes ".
	"$binsize  $xycol $minmax ".
	"imageset=$out";
    $self->call($cmd);
}

sub eexpmap {
    my $self = shift;
    my ($img,$out,$pimin,$pimax,$opt) = @_;

    croak "ccf.cif, sum.sas and attitude must be set before calling eexpmap"
	unless ($self->has_ccf and $self->has_odf and $self->has_attitude);

    my $attitude = $self->attitude;

    my $cmd = "eexpmap attitudeset=$attitude ".
	" eventset=".$self->evtfile.
	" imageset=$img expimageset=$out ".
	"pimin=$pimin pimax=$pimax ";
    if ($$opt{NOVIGNETTING}) {
	$cmd .= "withvignetting=no ";
    }
    if ($$opt{FAST}) {
	$cmd .= "usefastpixelization=yes ";
    }
    $self->call($cmd);
}


sub formatexpr {
    my $self = shift;

    my @list = @{$self->exprlist};
    # case of empty list:
    return if ($#list == -1);

    my $expr = "'(".shift(@list).')';

    while ($#list >= 0) {
	$expr .= ' && ('.shift(@list).')';
    }

    $expr .= "'";
    return($expr);
}


sub add_predefined_expr {
    my $self = shift;
    my $what = shift;

    my $negate = 0;
    if ($what =~ s/^not //) {
	$negate = 1;
    }
    my $expr = $self->exprlibrary($what);
    if ($negate) {
	$expr = '! '.$expr;
    }

    $self->addexpr($expr);
}


=back

=head1 EXPRESSION LIBRARY

The actual expressions are different according to the camera.

=over 4

=item * fov (ESAS)

One (PN) or the union of more (MOS) circles.

=item * corners (ESAS)

! ( fov || a number of boxes for problematic detector regions )

=item * mfov, molendifov (De Luca & Molendi)

Not a circle, but a corona: it excludes the inner 12'. Corners are
excluded with (FLAG & 0x10000) == 0

=item * mcorners, molendicorners (De Luca & Molendi)

 PN:  ! ( ~esasfov )
 MOS: ! ( ~esasfov || boxes )

In all cameras, FOV is also excluded with (FLAG & 0x10000) == 0.


=item * quad[1-7] (MOS), quad[1-4] (PN)       (ESAS)

for the MOSes, quadrant==CCDNR. The regions are anyway defined in terms
of BOXes.

=item * fulldef (ESAS)

=item * ruffovdef (ESAS)

=item * lowbkg (CDFS)

Remove known instrumental lines.

 PN:  ! ((PI in [1450:1540])||(PI in [7200:7600])||(PI in [7800:8200]))
 MOS: ! (PI in [1450:1540])

=item * lowerbkg (CDFS)

A more aggressive line removal than lowbkg.

 PN:  ! ((PI in [1390:1550])||(PI in [7350:7600])||(PI in [7840:8280])||(PI in [8540:9000]))
 MOS: ! ((PI in [1390:1550])||(PI in [1690:1800]))

=item * cuhole (CDFS)

Like lowerkbg, but for the Cu complex (i.e. lines > 7 keV) in PN only
the inner area where the lines are present is filtered out.

=item * stdfilter

 PN:  #XMMEA_EP && (PATTERN<=4) && (FLAG==0)
 MOS: #XMMEA_EM && (PATTERN<=12) && (FLAG==0)

=back

=cut

sub exprlibrary {
    my $self = shift;
    my $what = shift;

    if ($self->camera eq 'EPN') {
	given ($what) {
	    when ('fov') {
		return '((DETX,DETY) IN circle(-2200,-1110,18200))';
	    }
	    when ('corners') {
		return '!((DETX,DETY) IN circle(-2200,-1110,18200))';
	    }
	    when ([qw/mfov molendifov/]) {
		return '((FLAG & 0x10000) == 0) && !((DETX,DETY) IN circle(-2203.5,-1167.5,12000))';
	    }
	    when ([qw/mcorners molendicorners/]) {
		return '((FLAG & 0x10000) != 0) && !((DETX,DETY) IN circle(-2200,-1000,19000))';
	    }
	    when ('quad1') {
		return '((DETX,DETY) in BOX(-10241.5,7115.0,8041.5,8210.0,0))';
	    }
	    when ('quad2') {
		return '((DETX,DETY) in BOX(5840.0,7115.0,8040.0,8210.0,0))';
	    }
	    when ('quad3') {
		return '((DETX,DETY) in BOX(5840.0,-9311.0,8040.0,8216.0,0))';
	    }
	    when ('quad4') {
		return '((DETX,DETY) in BOX(-10241.5,-9311.0,8041.5,8216.0,0))';
	    }
	    when ('fulldef') {
		return '((DETX,DETY) in BOX(-2196,-1110,16060,15510,0))';
	    }
	    when ('ruffovdef') {
		return '((DETX,DETY) IN circle(-2200,-1110,17980))';
	    }
	    when ('lowbkg') {
		return '! ((PI in [1450:1540])||(PI in [7200:7600])||(PI in [7800:8200]))';
	    }
	    when ('lowerbkg') {
		return '! ((PI in [1390:1550])||(PI in [7350:7600])||(PI in [7840:8280])||(PI in [8540:9000]))';
	    }
	    when ('cuhole') {
		return '(! (((PI in [7350:7600])||(PI in [7840:8280])||(PI in [8540:9000])) && ! ( ellipse(-2196,1970,5472,3685,0,DETX,DETY) || ellipse(-2196,-4217,5472,3685,0,DETX,DETY) || box(-2196,-1178,5472,3400,0,DETX,DETY) ) ))';
	    }
	    when ('stdfilter') {
		return '#XMMEA_EP && (PATTERN<=4) && (FLAG==0)';
	    }
	}

    } elsif ($self->camera eq 'EMOS1') {
	my $esasfov = ' ((DETX,DETY) in CIRCLE(100,-200,17700))'.
	        '|| ((DETX,DETY) in CIRCLE(834,135,17100))'.
		'|| ((DETX,DETY) in CIRCLE(770,-803,17100))';

	given ($what) {
	    when ('fov') {
		return "($esasfov)";
	    }
	    when ('corners') {
		return "! ($esasfov".
	     '||((DETX,DETY) in BOX(-20,-17000,6500,500,0))'.
             '||((DETX,DETY) in BOX(5880,-20500,7500,1500,10))'.
             '||((DETX,DETY) in BOX(-5920,-20500,7500,1500,350))'.
             '||((DETX,DETY) in BOX(-20,-20000,5500,500,0))'.
             '||((DETX,DETY) in BOX(-6450,19000,6700,925,0)))';
	    }
	    when ([qw/mfov molendifov/]) {
		return '((FLAG & 0x10000) == 0) && !((DETX,DETY) IN circle(191.5,-345.5,12000))';
	    }
	    when ([qw/mcorners molendicorners/]) {
		return '((FLAG & 0x10000) != 0) && !((DETX,DETY) IN circle(-50,-180,17540)||(DETX,DETY) IN box(110,-17090,11460,880,0)||(DETX,DETY) IN box(-7418.5,-19485.5,5880,1520,0)||(DETX,DETY) IN box(-118.5,-19805.5,8720,880,0)||(DETX,DETY) IN box(7311.5,-19485.5,6140,1520,0)||(DETX,DETY) IN box(-12488.5,-18315.5,1580,940,0)||(DETX,DETY) IN box(11841.5,-18475.5,2800,780,0))';
	    }

	    when ('quad1') {
		return '(((DETX,DETY) in BOX(48,-255,6580,6525,0))||((DETX,DETY) in BOX(-3270,5020,3270,1373,0)))';
	    }
	    when ('quad2') {
		return '((DETX,DETY) in BOX(6635,-13625,6505,6545,0))';
	    }
	    when ('quad3') {
		return '((DETX,DETY) in BOX(13295,-306,6599,6599,0))';
	    }
	    when ('quad4') {
		return '((DETX,DETY) in BOX(6529,13027,6599,6599,0))';
	    }
	    when ('quad5') {
		return '((DETX,DETY) in BOX(-6435.5,13094,6633,6599,0))';
	    }
	    when ('quad6') {
		return '((DETX,DETY) in BOX(-13169,-105,6599,6599,0))';
	    }
	    when ('quad7') {
		return '((DETX,DETY) in BOX(-6520,-13438,6590,6599,0))';
	    }
	    when ('fulldef') {
		return '(((DETX,DETY) IN box(-2683.5,-15917,2780.5,1340,0))'.
		    '||((DETX,DETY) IN box(2743.5,-16051,2579.5,1340,0))'.
		    '||((DETX,DETY) IN circle(97,-172,17152)))';
	    }
	    when ('lowbkg') {
		return '! (PI in [1450:1540])';
	    }
	    when ([qw/lowerbkg cuhole/]) {
		return '! ((PI in [1390:1550])||(PI in [1690:1800]))';
	    }
	    when ('stdfilter') {
		return '#XMMEA_EM && (PATTERN<=12) && (FLAG==0)';
	    }
	}

    } elsif ($self->camera eq 'EMOS2') {
	my $realfov = '((DETX,DETY) IN CIRCLE(435,1006,17100))'.
	    '||((DETX,DETY) IN CIRCLE(-34,68,17700))';

	given ($what) {
	    when ('fov') {
		return "($realfov)";
	    }
	    when ('corners') {
		return "! ($realfov".
             '||((DETX,DETY) IN BOX(-20,-17000,6500,500,0))'.
             '||((DETX,DETY) IN BOX(5880,-20500,7500,1500,10))'.
             '||((DETX,DETY) IN BOX(-5920,-20500,7500,1500,350))'.
             '||((DETX,DETY) IN BOX(-20,-20000,5500,500,0)))';
	    }
	    when ([qw/mfov molendifov/]) {
		return '((FLAG & 0x10000) == 0) && !((DETX,DETY) IN circle(191.5,-345.5,12000))';
	    }
	    when ([qw/mcorners molendicorners/]) {
		return '((FLAG & 0x10000) != 0) && !((DETX,DETY) IN circle(-50,-180,17540)||(DETX,DETY) IN box(110,-17090,11460,880,0)||(DETX,DETY) IN box(-7418.5,-19485.5,5880,1520,0)||(DETX,DETY) IN box(-118.5,-19805.5,8720,880,0)||(DETX,DETY) IN box(7311.5,-19485.5,6140,1520,0)||(DETX,DETY) IN box(-12488.5,-18315.5,1580,940,0)||(DETX,DETY) IN box(11841.5,-18475.5,2800,780,0))';
	    }
	    when ('quad1') {
		return '((DETX,DETY) IN BOX(5,-100,6599,6530,0))';
	    }
	    when ('quad2') {
		return '((DETX,DETY) IN BOX(6673,-13427,6633,6599,0))';
	    }
	    when ('quad3') {
		return '((DETX,DETY) IN BOX(13372,-228,6633,6599,0))';
	    }
	    when ('quad4') {
		return '((DETX,DETY) IN BOX(6571,13104,6599,6599,0))';
	    }
	    when ('quad5') {
		return '((DETX,DETY) IN BOX(-6628,13172,6599,6599,0))';
	    }
	    when ('quad6') {
		return '((DETX,DETY) IN BOX(-13226,-61,6633,6633,0))';
	    }
	    when ('quad7') {
		return '((DETX,DETY) IN BOX(-6628,-13427,6599,6599,0))';
	    }
	    when ('fulldef') {
		return '(((DETX,DETY) IN circle(-61,-228,17085))'.
		    '||((DETX,DETY) IN box(14.375,-16567.6,5552.62,795.625,0)))';
	    }
	    when ('lowbkg') {
		return '! (PI in [1450:1540])';
	    }
	    when ([qw/lowerbkg cuhole/]) {
		return '! ((PI in [1390:1550])||(PI in [1690:1800]))';
	    }
	    when ('stdfilter') {
		return '#XMMEA_EM && (PATTERN<=12) && (FLAG==0)';
	    }
	}
    }
}


sub excludesrc {
    my $self = shift;
    my @xy = @_;

    while ($#xy>0) {
	my $x = shift @xy;
	my $y = shift @xy;
	$self->addexpr("! ((X,Y) IN CIRCLE($x,$y,500))");
	print "! ((X,Y) IN CIRCLE($x,$y,500))" if $self->verbose;
    }
}


# sub attitude {
#     my $self = shift;

#     my $obsid = $self->{HDR}->{OBS_ID};
#     my $attitude_dir = "/Volumes/data/XMM-CDFS/$obsid/10.0.0Reprocessed";
#     my @atthk_files = grep(/_corr/,glob( $attitude_dir.'/*AttHk*.ds' ));

#     if (@atthk_files > 1) {
# 	croak "too many attitude files: @atthk_files in obsid $obsid\n";
#     }
#     return $atthk_files[0];
# }



sub addbadpixels {
    # should actually use File::Temp sooner or later..
    my $self = shift;

    my $evt = $self->evtfile;

    # generate table of custom bad pixels
    my $badpixset="bpix$evt";
    my $cmd = "badpixfind eventset=$evt searchbadpix=n userflagbadpix=y ".mos1badpixels()." badpixset=$badpixset ccd=4";
    $self->call($cmd);

    # update table in the event set
    $badpixset =~ s[\.((fits)|(ds))][04.$1];
    $cmd = "ebadpixupdate eventset=$evt badpixtables='$badpixset'";
    $self->call($cmd);

    # refilter the event set
    $cmd = "evselect table=$evt withfilteredset=yes filteredset=tmp$evt expression='#XMMEA_EM'";
    $self->call($cmd);

    # replace the event file with the badpix'ed one
    $cmd = "mv -f tmp$evt $evt";
    $self->call($cmd);
}


sub mos1badpixels {
    # NOT A METHOD

    # sets MOS1 bad pixels in Atlas
    # values are in RAWX/Y coordinates and come from an inspection of
    # obsid 0725290101

    my $xmin = 1;
    my $xmax = 200;
    my $ymin = 1;
    my $ymax = 60;

    my @x = my @y = my @yext = ();
    mos1badpixelscalc($xmin,$xmax,$ymin,$ymax,\@x,\@y,\@yext);

    $xmin = 201;
    $xmax = 238;
    $ymin = 1;
    $ymax = 40;
    mos1badpixelscalc($xmin,$xmax,$ymin,$ymax,\@x,\@y,\@yext);

    my $string = 'rawxlist="'.join(' ',@x).'" rawylist="'.join(' ',@y).
	'" typelist="'.join(' ',('1') x @x).'" yextentlist="'.join(' ',@yext).'"';

    return $string;
}

sub mos1badpixelscalc {
    # NOT A METHOD

    my ($xmin,$xmax,$ymin,$ymax,$xlist,$ylist,$yextlist) = @_;

    my $yext = $ymax-$ymin;
    my $npix = $xmax-$xmin+1;
    push(@$xlist,    $xmin .. $xmax);
    push(@$ylist,    ($ymin) x $npix);
    push(@$yextlist, ($yext) x $npix);
}


sub mosaic_attcalc {
    my $self = shift;
    my $evt = shift;

    my $cmd = "attcalc eventset=".$self->evtfile." calctlmax=yes";
    $self->call($cmd);
}


sub reproject {
    my $self = shift;
    my $ra = shift;
    my $dec = shift;

    croak 'attitude not set' unless ($self->has_attitude);

    my $cmd = " attcalc eventset=".$self->evtfile.
	" withatthkset=yes atthkset=".$self->attitude.
	" nominalra=$ra nominaldec=$dec imagesize=0.36 ".
	" refpointlabel=user ";
    $self->call($cmd);

}

__PACKAGE__->meta->make_immutable;

1;

=head1 TODO

 # $sas->logfile([$file]); # set log to file (or to screen if file is not
                           # specified;  not yet implemented


=head1 AUTHOR

Piero Ranalli   piero.ranalli (at) noa.gr

=head1 LICENSE AND COPYRIGHT

Copyright 2011-2014 Piero Ranalli.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see http://www.gnu.org/licenses/.

=head1 HISTORY

1.0   2012/05       used for XMM-CDFS simulations
1.1   2012/07       added Cu-hole to the library
1.11  2013/08/04    added this history notice
1.2   2013/08/04    added XYIMGMINMAX and BINSIZE to imgextract()
                    added addbadpixels()
2.0   2013/08/08    refactored into XMMSAS::Extract with role XMMSAS::Exec
                    to allow XMMSAS::Detect to be put in the same distribution
2.01  2014/11/12    improved docs
