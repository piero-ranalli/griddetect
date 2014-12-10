# NAME

griddetect.pl - grid-based detection with emldetect

# SYNOPSYS

This program should be called thrice. The first time, to ingest the
list of images and exposure maps, and the grid definition:
 ./griddetect --ingest --imglist=mylist.txt --grid=mygrid.txt --srclist=mysrclist.fits --ccf=ccf.cif --odf=xxxxSUM.SAS

The second time to create the bkg files:
 ./griddetect --bkg

The third time to actually run the detection:
 ./griddetect --eband="05-8" --ecf=8.61e-12 --pimin=500 pimax=8000

# DESCRIPTION

This program takes a number of XMM-Newton pointings, divides them
according to a grid specified by the user, and repeatedly performs
source detection with emldetect in all cells of the grid.

At each emldetect run, all pointings overlapping within a cell are
used, but only the sources within the cells are kept. The final
catalogue is the union of the sources detected in each cell.

The grid is defined by specifiying the coordinates of the cracks
(i.e., the lines dividing the cells) and a rotation angle.

For more information, please see the [griddetect manual](http://members.noa.gr/piero.ranalli/griddetect) and the article
"The XMM-Newton survey in the H-ATLAS field" by Ranalli et al., 2014
(submitted to A&A).

# PARAMETERS

- \--ingest

    Read the list of images and exposure maps, and the grid
    definition. This information is processed and stored and will be used
    in the following runs.

- \--imglist=mylist.txt

    Specify the image/expmap list filename.

- \--grid=myrgid.txt

    Specify the grid definition filename.

- \--srclist=mysrclist.fits

    Specify the input catalogue, to be used for both the background fit
    and the emldetect runs.

- \--bkg

    Fit a background model to the images and exposure maps, according to
    the method developed for XMM-COSMOS (Cappelluti et al. 2009).

- \--eband="05-8"

    A string describing the energy band, to be used as part of the name of
    file produced in the detection.

- \--ecf=8.6e-12

    The energy conversion factor (ecf), defined as the flux (in erg/s/cm2)
    corresponding to a count rate of 1 s\*\*-1.

- \--pimin=500 --pimax=8000

    Minimun and maximum values of the energy band, in eV.

- \--sensmap

    Compute a sensitivity map.

# INPUT FILES

## List of images and exposure maps

This should be a text file containing, in one row for each pointing,
the following columns:

- path of the image file
- path of the exposure map
- path of the unvignetted exposure map ("novign" option in
eexpmap)
- path of the background file
- XXX (is this really needed?) path of the relevant attitude file

The columns should be separated by spaces (or tabs) and value should
be missing. Rows can contain comments if they start with a \#.

All files are checked for their existence. Images, expmaps and
unvignetted expmaps have to exist in order to succesfully ingest the
list.  Background files are checked but it is allowed that they do not
exist, because usually they will be created in the second stage with
the --bkg option.

## Grid definition

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

Rotation, ra\_centre and dec\_centre are optional: in their absence, the
(x,y) coordinates will be interpreted as (ra,dec).

Any number (including zero) of "x" and "y" lines can be specified in
the file; however, at least one x or one y should be present.

A sample grid is present in the distribution in the file
sample\_grid.txt.



# WORKFLOW

A typical workflow for a wide survey could be as follows (the first 8
steps are meant to prepare the input for griddetect):

1. correct the relative astrometry between different obsids;
2. obtain an input catalogue (e.g., by running ewavelet on the
mosaic image);
3. run emosaic\_prep on astrometry-corrected event files to split
each obsid into individual pointings;
4. run mosaicfix.pl to put the coordinates in the individual pointings;
5. create reprojected event files, images and expmaps (e.g.,
using evtlist2makefile.pl and img-extractor-expmap.pl);
6. fix again pointing info (mosaicrefix.pl);
7. sum the images and expmaps over camera  (addcameras.pl);
8. prepare the list of images/expmaps and the grid definition
(see below);
9. ingest the list and the grid definition:
 griddetect --ingest --list=mylist.txt --grid=mygrid.txt
10. make the backgrounds:
 griddetect.pl --bkg
11. do the detection:
 griddetect.pl
12. check for sources close to the cracks;
- \# join the individual catalogues.

A detailed description of the above steps can be found in the [griddetect manual](http://members.noa.gr/piero.ranalli/griddetect).

# DEPENDENCIES

(to be filled with info from XMMSAS::Extract)

# VERSION

1.0

# AUTHOR

(c) 2013-2014 Piero Ranalli   piero.ranalli (at) noa.gr

# LICENSE

Affero GPL v.3.0  (full details: http://www.gnu.org/licenses/agpl-3.0.html)

This license applies to these file, to all files in the git
repository, and to all packages in the XMMSAS:: and Detection::
namespaces called by this program.

# HISTORY

    0.1  2013/5/      Development version used for XMM-ATLAS
    1.0  2014/12/10   First public version
