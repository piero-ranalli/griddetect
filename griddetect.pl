#!/usr/bin/env perl

=head1 NAME

griddetect.pl - grid-based detection with emldetect

=head1 SYNOPSYS

This program should be called thrice. The first time, to ingest the
list of images and exposure maps, and the grid definition:
 ./griddetect --ingest --imglist=mylist.txt --grid=mygrid.txt --srclist=mysrclist.fits --ccf=ccf.cif --odf=xxxxSUM.SAS

The second time to create the bkg files:
 ./griddetect --bkg

The third time to actually run the detection:
 ./griddetect --detect --ecf=1.162

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
manual|http://www.astro.lu.se/~piero/griddetect> and the article
"The XMM-Newton survey in the H-ATLAS field" by Ranalli et al., 2016
A&A 590, 80.

=head1 PARAMETERS

=over 4

=item --ingest

Read the list of images and exposure maps, and the grid
definition. This information is processed and stored and will be used
in the following runs.

=item --imglist=mylist.txt

Specify the image/expmap list filename.

=item --grid=mygrid.txt

Specify the grid definition filename.

=item --srclist=mysrclist.fits

Specify the input catalogue, to be used for both the background fit
and the emldetect runs.

=item --bkg

Fit a background model to the images and exposure maps, according to
the method developed for XMM-COSMOS (Cappelluti et al. 2009).


=item --ecf=1.162

The energy conversion factor (ecf). If F is the flux in 10^-11
erg/s/cm2 corresponding to a count rate of 1 s**-1, then ecf=1/F (see
the emldetect manual).

If more than one band is being analysed, the ecf will be used for all
bands, leading to wrong flux values. Therefore, fluxes in the
catalogue should better be recomputed from the count rates after
griddetect has run. Multiple ecfs will be implemented in a future
version.

=back

=head1 INPUT FILES

=head2 List of images and exposure maps

This should be a text file containing, in one row for each pointing,
the following columns:

=over 4

=item path of the image file

=item path of the exposure map

=item path of the unvignetted exposure map ("novign" option in
eexpmap)

=item path of the background file

=item band name

=item pimin

=item pimax

=item exposure id

=back

The columns should be separated by spaces (or tabs) and value should
be missing. Rows can contain comments if they start with a #.

All files are checked for their existence. Images, expmaps and
unvignetted expmaps have to exist in order to succesfully ingest the
list.  Background files are checked but it is allowed that they do not
exist, because usually they will be created in the second stage with
the --bkg option.

The exposure ids should be strings uniquely identifying the
pointing. In a mosaic-mode obsid, each pointing has the same obsid
number but a different EXPIDSTR in the header; this can be used as
exposure id if only one obsid is being analysed. In the case of
multiple mosaic-mode obsids, the user should choose exposure ids which
are different also among obsids.  In the case of multiple,
non-mosaic-mode obsid, the obsid number should be fine.

In stage 2 (background files), the band names will be used to look for
columns named EXTENTbandname in the input srclist.  The FITS standard
restricts the set of characters which can be used in column names to
letters, numbers, and the underscore character; therefore the
following rules will be applied: 1) any dash in the name will be
converted to an underscore (i.e. if the band name is 05-2, griddetect
will look for column EXTENT05_2); 2) any other non-alphanumeric
character will be dropped.


=head2 Grid definition

This should be a text file containing a series of key/value pairs, as
in the following example, which defines a 3x5 grid with cracks
rotated by 35 degrees with respect to the RA,Dec framework:

 rotation=35   #  grid rotation in degrees (positive: clockwise)
 ra_centre=53.12345    #  RA of rotation centre
 dec_centre=24.6543    #  Dec of rotation centre
 x=52.8        # grid boundary (along the rotated RA axis)
 x=53.07       # a crack
 x=53.17       # another crack
 x=53.5        # grid boundary
 y=24.2        # grid boundary (along the rotated Dec axis)
 y=24.5        # crack
 y=24.6        # crack
 y=24.7        # crack
 y=25          # grid boundary

If only one row (or column) is desired in the grid, then only the
boundaries should be specified.

The conversion between equatorial coordinates (ra,dec) and the rotated
(x,y) used here is:

 x = (ra-ra_centre)*cos(rotation) - (dec-dec_centre)*sin(rotation)
 y = (ra-ra_centre)*sin(rotation) + (dec-dec_centre)*cos(rotation)

Rotation, ra_centre and dec_centre are optional: in their absence, the
(x,y) coordinates will be interpreted as (ra,dec).

Any number (including zero) of "x" and "y" lines can be specified in
the file; however, at least one x or one y should be present.

A sample grid is present in the distribution in the file
sample_grid.txt.


=head1 OUTPUT FILES

Griddetect will produce a number of output files. The following
are the important ones:

=over 4

=item 1.  ok_emlcat-iii-jjj.fits

=item 2.  crack_emlcat-iii-jjj.fits

=back

Where (iii,jjj) is the cell.  The ok_emlcat files are the detected
sources falling in the cell. The crack_emlcat ones are the sources
falling within 3" from the cracks.  After inspecting the crack_emlcats
for duplicate/missing sources, the ok_emlcat should be merged
(e.g. with fmerge) to produce the final catalogue.

Many other files are produced in the current directory, which may
be regarded as temporary. A good practice may be to run griddetect in
a different directory than the one where the images/expmaps/bkgs are.


=head1 WORKFLOW

A typical workflow for a wide survey could be as follows (the first 8
steps are meant to prepare the input for griddetect):

=over 4

=item 1. correct the relative astrometry between different obsids;

=item 2. obtain an input catalogue (e.g., by running ewavelet on the
mosaic image);

=item 3. run emosaic_prep on astrometry-corrected event files to split
each obsid into individual pointings;

=item 4. run mosaicfix.pl to put the coordinates in the individual pointings;

=item 5. create reprojected event files, images and expmaps (e.g.,
using evtlist2makefile.pl and img-extractor-expmap.pl);

=item 6. fix again pointing info (mosaicrefix.pl);

=item 7. sum the images and expmaps over camera  (addcameras.pl);

=item 8. prepare the list of images/expmaps and the grid definition
(see below);

=item 9. ingest the list and the grid definition:
 griddetect --ingest --list=mylist.txt --grid=mygrid.txt

=item 10. make the backgrounds:
 griddetect.pl --bkg

=item 11. do the detection:
 griddetect.pl

=item 12. check for sources close to the cracks;

=item 13 join the individual catalogues (e.g. with fmerge).

=back

A detailed description of the above steps can be found in the L<griddetect
manual|http://www.astro.lu.se/~piero/griddetect>.

=head1 DEPENDENCIES

(to be filled with info from XMMSAS::Extract)

=head1 VERSION

2.1

=head1 AUTHOR

(c) 2013-2016 Piero Ranalli   piero (at) lu.se

=head1 LICENSE

Affero GPL v.3.0  (full details: http://www.gnu.org/licenses/agpl-3.0.html)

This license applies to these file, to all files in the git
repository, and to all packages in the XMMSAS:: and Detection::
namespaces called by this program.

=head1 HISTORY

 0.1  2013/5/      Development version used for XMM-ATLAS
 1.0  2014/12/10   First public version
 2.0  2015/1/19    Detection over multiple bands
 2.1  2016/12/18   Bug fixes

=cut


use FindBin;
use lib "$FindBin::Bin/lib";

use XMMSAS::Detect;
use Modern::Perl;
use Getopt::Long;
#use Parallel::ForkManager;
#use List::MoreUtils 'apply';

#use AtlasFiles;
use Detection::Grid;

# no defaults
my $srclist;
my $imglist;
my $griddef;
my $ccf;
my $odf;

my $dobkg = 0;
my $doingest = 0;
my $dodetect = 0;
my $doonlybkgsum = 0;
my $dosensmap = 0;
my $maxproc = 0;

#my $eband = '05-8';
	# ecf: gamma=1.7 nh=2.3e20
	# .5-8 =>      9.197e-12
	# 1.39-1.55 => 3.221e-13
	# 7.35-7.60 => 1.645e-13
	# 7.84-8.00 => 1.011e-13
	#  tot-lines: 8.609e-12
my $ecf = 1/.8609;
#my $pimin = 2000;
#my $pimax = 8000;


GetOptions( 'bkg'        => \$dobkg,
	    'ingest'     => \$doingest,
	    'detect'     => \$dodetect,
	    'imglist=s'  => \$imglist,
	    'grid=s'     => \$griddef,
	    'onlybkgsum' => \$doonlybkgsum,
	    'sensmap'    => \$dosensmap,
	    'srclist=s'  => \$srclist,
	    'maxproc=i'  => \$maxproc,
	    'ecf=f'      => \$ecf,
#	    'pimin=f'    => \$pimin,
#	    'pimax=f'    => \$pimax,
#	    'eband=s'    => \$eband,
	    'ccf=s'      => \$ccf,
	    'odf=s'      => \$odf,
	  );


# check for the srclist, ccf, and odf parametrs
if ($doingest and not (
     defined($srclist) and defined($ccf) and defined($odf) and defined($griddef))) {
    die "The --grid, --srclist, --ccf, and --odf parameters need to be specified for the ingest stage.\n";
}


# warning for third stage
unless ($doingest or $dobkg or $dodetect) {
    die "Please choose which stage to run, by specifying any of the --ingest, --bkg, or --detect switches.\n";
}


#say "Eband $eband using ecf=$ecf pimin=$pimin pimax=$pimax";

my $grid = Detection::Grid->new;

$grid->imglist($imglist) if (defined($imglist));
$grid->griddef($griddef) if (defined($griddef));
$grid->srclist($srclist) if (defined($srclist));
$grid->ccf($ccf)         if (defined($ccf));
$grid->odf($odf)         if (defined($odf));

# STAGE 1 -- INGEST (& exit)
if ($doingest) {
    $grid->ingest;
    $grid->dbstore;
    exit;
}

# for later stages, get filenames and grid from storage
$grid->dbreload;

my $sas = XMMSAS::Detect->new;

my ($nrows,$ncols) = $grid->griddims;    # $matrix of list of objects

#my $atlas = AtlasFiles->new;
#$atlas->use_astrometry_corr(1);

#$grid->eband($eband);

# to be removed
#
# if ($dobkg) {
#     $grid->camera('single');
# } else {
#     $grid->camera('sum');
# }

#goto SUMBKG if $doonlybkgsum;

#my $pm = Parallel::ForkManager->new($maxproc);

for my $i (0..$nrows-1) {
    for my $j (0..$ncols-1) {

#	$pm->start and next;

	print "Checking cell $i,$j ... ";
	$grid->selectcell($i,$j);
	if ($grid->cellisempty) {
	    say "empty, skipping this cell.";
	    next;
	}

	say "start processing.";
	$sas->cellname(sprintf("%03i-%03i",$i,$j));

	# no longer needed,new ingest/selectcell mechanism takes care of this
	#$grid->findimg;
	#$grid->findexpmap;
	#$grid->findnovign;
	#$grid->findbkg  unless $dobkg;

	$grid->calc_radec_span;

	$sas->img( $grid->img );
	$sas->expmap( $grid->expmap );
	$sas->novign( $grid->novign );
	$sas->bkg( $grid->bkg );
	$sas->emlcat( sprintf("emlcat-%s.fits",$sas->cellname) );

	my $nimg = @{ $sas->img };

	$sas->ecf(   [ ($ecf)   x $nimg ] );
#	$sas->pimin( [ ($pimin) x $nimg ] );
#	$sas->pimax( [ ($pimax) x $nimg ] );
	$sas->eband( $grid->eband  );
	$sas->pimin( $grid->pimin );
	$sas->pimax( $grid->pimax );
	$sas->expid( $grid->expid );

	#$atlas->obsid($grid->get1stobsid);
	$sas->odf($grid->odf);
	$sas->ccf($grid->ccf);

	$sas->srclist( $grid->srclist );

	if ($dobkg) {
	    # STAGE 2: fit bkg (& exit)

	    $sas->fitbkg;
#	    $pm->finish;
	    next;
	}

	# sensitivity maps are disabled, this is not the way to do it
# 	if ($dosensmap) {
# 	    # OPTIONAL STAGE: sensitivity map (& exit)

# 	    $sas->make_srcmasks;
# 	    $sas->fudge_obsid_instr_in_detmasks;
# 	    $sas->sensmap( sprintf("sensmap-%s.fits",$sas->cellname) );
# 	    $sas->esensmap;
# #	    $pm->finish;
# 	    next;
# 	}

	# ...if we get here, it's time for
	# STAGE 3: DETECTION

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

#SUMBKG:
#$grid->sumbkgs if ($dobkg);


# merge cats manually?
