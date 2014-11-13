package Atlas::Grid::GlobFiles;

use Moose::Role qw/has/;
use PDL;

use Carp;

# methods for globbing files


sub findimg {
    my $self = shift;

    my $imgs = $self->find("img");
    $self->img( $imgs );

    my @ra; my @dec; my @cdelt1;
    for my $i (@$imgs) {
	my $hdr = rfitshdr($i."[0]");
	push @ra, $hdr->{RA_PNT};
	push @dec,$hdr->{DEC_PNT};
	push @cdelt1,$hdr->{CDELT1};
    }
    $self->ra( \@ra );
    $self->dec(\@dec);
    $self->cdelt1(\@cdelt1);
}

sub findexpmap {
    my $self = shift;
    $self->expmap( $self->find("exp") );
}

sub findnovign {
    my $self = shift;
    $self->novign( $self->find("exp_novign") );
}

sub findbkg {
    my $self = shift;
    $self->bkg(    $self->find("bkg") );
}


sub find {
    my $self = shift;
    my $what = shift;

    my @list;
    for my $i (0..$#{$self->pointing}) {

	my $point = ${$self->pointing}[$i];
	$point =~ s/\s+$//;

	my $glob = sprintf("%010i_*_clean_corr_%s-%s_%s.ds",
			   ${$self->obsid}[$i],
			   $what,
			   $self->eband,
			   $point
			  );
	my @files = glob($glob);

	if ($self->has_camera) {
	    if ($self->camera eq 'sum') {
		@files = grep(/_all_/,@files);
	    } elsif ($self->camera eq 'single') {
		@files = grep(!/_all_/,@files);
	    } else {
		my $cam = $self->camera;
		@files = grep(/$cam/,@files);
	    }
	}

	if (@files == 0) {
	    carp "no files found like $glob";
	}

	push(@list,@files);
    }

    return \@list;
}

1;
