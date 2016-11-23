package Detection::Grid::Ingest;

use Moose::Role;
use Carp;
use 5.010;

has imglist => (is => 'rw', isa => 'Str');
has griddef => (is => 'rw', isa => 'Str');
# also uses the following attributes defined in D::Grid:
# srclist, ccf, odf

no if $] >= 5.018, warnings => "experimental::smartmatch";

sub ingest {
    my $self = shift;

    # check that files exist
    $self->check_file($_) for ($self->griddef, $self->srclist, $self->ccf, $self->odf);

    # read griddef first and imglist after, because imglist will need
    # the rotation value to compute rot_ra_pnt, rot_dec_pnt
    $self->read_griddef;
    $self->read_imglist;
    $self->checkgrid;
}


sub read_imglist {
    my $self = shift;

    open (my $fh, '<', $self->imglist);

    my $errors = 0;
    my $nrow = 0;

    while (my $row = <$fh>) {

	$nrow++;
	next if ($row =~ m/^\s*\#/); # skip comments

	chomp($row);
	my @files = split(' ',$row);

	# check that nothing is missing
	if (@files != 8) {
	    say "Incomplete list of files or bands at row $nrow in img/expmap list ".$self->imglist."\n";
	    $errors++;
	}

	# check if files exist!
	for my $f (@files[0..2]) {
	    unless (-e $f) {
		say "Could not find file $f, listed at row $nrow in img/expmap list ".$self->imglist."\n";
		$errors++;
	    }
	}
	# bkg files are treated slightly different
	if (-e $files[3]) {
	    say "Warning: background file $files[3] already exists on the disc.\nWill be overwritten if --bkg option is used at the next stage.";
	}

	# store
	$self->dbstoreimgexp( img=>$files[0], exp=>$files[1],
			      expnovign=>$files[2], bkg=>$files[3],
			      band=>$files[4], pimin=>$files[5],
			      pimax=>$files[6], expid=>$files[7],
			    );
    }
    close($fh);

    if ($errors) {
	die "There where $errors errors. Image/expmap list not ingested.\n";
    }

}


sub read_griddef {
    my $self = shift;

    my @keys = qw/rotation ra_centre ra_center dec_centre dec_center x y/;

    open (my $fh, '<', $self->griddef);

    my $errors = 0;
    my $nrow = 0;
    my @x;
    my @y;

    while (my $row = <$fh>) {

	$nrow++;
	next if ($row =~ m/\s*\#/); # skip comments

	# chomp and trim
	chomp($row);
	$row =~ s|^\s+||;
	$row =~ s|\s+$||;

	unless ($row =~ m/=/) {
	    say "Syntax error at row $nrow in grid definition ".$self->griddef."\n";
	    $errors++;
	}

	my ($k,$v) = split('=',$row);

	unless ($k ~~ @keys) {
	    say "Unrecognized parameter at row $nrow in grid definition ".$self->griddef."\n";
	    $errors++;
	    next;
	}

	given ($k) {
	    when (/rotation/) {  $self->rotation( $v ); }
	    when (/ra_cent[re]{2}/) { $self->ra_cen( $v ); }
	    when (/dec_cent[re]{2}/) { $self->dec_cen( $v ); }
	    when (/x/) { push @x, $v; }
	    when (/y/) { push @y, $v; }
	}
    }

    @x = sort { $a <=> $b } @x;   # force numeric sorting, because
    @y = sort { $a <=> $b } @y;   # selectcell() is expecting it
    $self->x_bound( \@x );
    $self->y_bound( \@y );
}


sub check_file {
    my $self = shift;
    my $f = shift;

    unless (-e $f) {
	die "Could not find file $f\n";
    }
}


sub checkgrid {
    my $self = shift;

    my $nx = -1+@{$self->x_bound};
    my $ny = -1+@{$self->y_bound};

    printf("Grid consists of %i x %i cells.\n",$nx,$ny);

    # count how many pointings in each grid cell
    for my $i (0..$nx-1) {
	for my $j (0..$ny-1) {
	    $self->selectcell($i,$j);
	    printf("Grid element (%2i,%2i) contains %2i pointings.\n",
		   1+$i, 1+$j, 1+$#{$self->img}
		  );
	}
    }

}

1;
