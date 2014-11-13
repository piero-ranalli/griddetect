#!/usr/bin/env perl

=head1 NAME

griddetect.pl - grid-based detection with emldetect

=head1 SYNOPSYS

This program should be called twice. The first time, to create the bkg files:
 ./griddetect --bkg

The second time to run the detection:
 ./griddetect

=head1 DESCRIPTION

This program takes a number of XMM-Newton pointings, divides them
according to a grid specified by the user, and repeatedly performs
source detection with emldetect in all cells of the grid.

At each emldetect run, all pointings overlapping within a cell are
used, but only the sources within the cells are kept. The final
catalogue is the union of the sources detected in each cell.

The grid is defined by specifiying the coordinates of the cracks
(i.e., the lines dividing the cells) and a rotation angle.

For more information, please see the L<griddetect
manual|http://members.noa.gr/piero.ranalli/griddetect> and the article
"The XMM-Newton survey in the H-ATLAS field" by Ranalli et al., 2014
(submitted to A&A).

=head1 WORKFLOW

The typical workflow for a wide survey should be as follows:

=over 4

=item # correct the relative astrometry between different obsids;

=item # obtain an input catalogue (e.g., by running ewavelet on the
mosaic image);

=item # run emosaic_prep on astrometry-corrected event files to split
each obsid into individual pointings;

=item # run mosaicfix.pl to put the coordinates in the individual pointings;

=item # create reprojected event files, images and expmaps (e.g.,
using evtlist2makefile.pl and img-extractor-expmap.pl);

=item # fix again pointing info (mosaicrefix.pl);

=item # sum the images and expmaps over camera  (addcameras.pl);

=item # make the backgrounds:  griddetect.pl --bkg ;

=item # do the detection:  griddetect.pl ;

=item # check for sources close to the cracks;

=item # join the individual catalogues.

=back

A detailed description of the above steps can be found in the L<griddetect
manual|http://members.noa.gr/piero.ranalli/griddetect>.

=head1 DEPENDENCIES

(to be filled with info from XMMSAS::Extract)

=head1 VERSION

1.0

=head1 AUTHOR

(c) 2013 Piero Ranalli   piero.ranalli (at) noa.gr

=head1 LICENSE

Affero GPL v.3.0  (full details: http://www.gnu.org/licenses/agpl-3.0.html)

This license applies to these file, and to all packages in the XMMSAS::
and Atlas:: namespaces called by this program.

=head1 HISTORY

 0.1  2013/5/      Development version used for XMM-ATLAS
 1.0  2014/11/12   First public version

=cut


use XMMSAS::Detect;
use Modern::Perl;
use Getopt::Long;
use Parallel::ForkManager;
#use List::MoreUtils 'apply';

use AtlasFiles;
use Atlas::Grid;


my $dobkg = 0;
my $doonlybkgsum = 0;
my $dosensmap = 0;
my $maxproc = 0;
my $srclist = '/home/pranalli/Data/Atlas/Det-emldetect/atlas-wavcat-extract-v2.fits';
my $eband = '05-8';
	# ecf: gamma=1.7 nh=2.3e20
	# .5-8 =>      9.197e-12
	# 1.39-1.55 => 3.221e-13
	# 7.35-7.60 => 1.645e-13
	# 7.84-8.00 => 1.011e-13
	#  tot-lines: 8.609e-12
my $ecf = 1/.8609;
my $pimin = 2000;
my $pimax = 8000;

GetOptions( 'bkg'     => \$dobkg,
	    'onlybkgsum' => \$doonlybkgsum,
	    'sensmap' => \$dosensmap,
	    'srclist=s' => \$srclist,
	    'maxproc=i' => \$maxproc,
	    'ecf=f'     => \$ecf,
	    'pimin=f'   => \$pimin,
	    'pimax=f'   => \$pimax,
	    'eband=s'   => \$eband,
	  );


say "Eband $eband using ecf=$ecf pimin=$pimin pimax=$pimax";

my $grid = Atlas::Grid->new;
my $sas = XMMSAS::Detect->new;

my ($nrows,$ncols) = $grid->griddims;    # $matrix of list of objects

my $atlas = AtlasFiles->new;
$atlas->use_astrometry_corr(1);

$grid->eband($eband);
if ($dobkg) {
    $grid->camera('single');
} else {
    $grid->camera('sum');
}

goto SUMBKG if $doonlybkgsum;

#my $pm = Parallel::ForkManager->new($maxproc);

for my $i (0..$nrows-1) {
    for my $j (0..$ncols-1) {

#	$pm->start and next;

	say "Starting detection on cell $i,$j";
	$grid->selectcell($i,$j);
	$sas->cellname(sprintf("%03i-%03i",$i,$j));

	$grid->findimg;
	$grid->findexpmap;
	$grid->findnovign;
	$grid->findbkg  unless $dobkg;

	$grid->calc_radec_span;

	$sas->img( $grid->img );
	$sas->expmap( $grid->expmap );
	$sas->novign( $grid->novign );
	$sas->bkg( $grid->bkg ) unless $dobkg;
	$sas->emlcat( sprintf("emlcat-%s.fits",$sas->cellname) );

	my $nimg = @{ $sas->img };

	$sas->ecf(   [ ($ecf)   x $nimg ] );
	$sas->pimin( [ ($pimin) x $nimg ] );
	$sas->pimax( [ ($pimax) x $nimg ] );

	$atlas->obsid($grid->get1stobsid);
	$sas->odf($atlas->odf);
	$sas->ccf($atlas->ccf);

	$sas->srclist( $srclist );

	if ($dobkg) {
	    $sas->fitbkg;                 # or bkg is fitted here
#	    $pm->finish;
	    next;
	}




	if ($dosensmap) {
	    $sas->make_srcmasks;
	    $sas->fudge_obsid_instr_in_detmasks;
	    $sas->sensmap( sprintf("sensmap-%s.fits",$sas->cellname) );
	    $sas->esensmap;
#	    $pm->finish;
	    next;
	}

	# frame everything in a common WCS reference
	# or otherwise emldetect will complain
	$sas->framesizex( $grid->framesizex );
	$sas->framesizey( $grid->framesizey );
	$sas->framera(  $grid->centre_ra  );
	$sas->framedec( $grid->centre_dec );

	$sas->reframe;
	$sas->fudge_obsid_instr;

	$sas->emldetect;

	$grid->catfile( $sas->emlcat );
	$grid->cleancat( $sas );
	#$grid->dbupload;

#	$pm->finish;
    }
}

SUMBKG:
$grid->sumbkgs if ($dobkg);


# merge cats manually?
