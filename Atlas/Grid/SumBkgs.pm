package Atlas::Grid::SumBkgs;

use 5.010;
use Moose::Role;
use Carp;
# sum background files

sub sumbkgs {
    my $self = shift;

    unless ($self->camera eq 'single') {
	carp 'Resetting camera in Atlas::Grid to "single"';
	$self->camera('single');
    }

    my $obsid = $self->getallobsid;
    for my $o (@$obsid) {

	my $pointings = $self->getpointings($o);
	for my $p (@$pointings) {

	    $self->obsid([$o]);
	    $self->pointing([$p]);
	    $self->findbkg;

	    $p =~ s/\s+$//;
	    my $sum = sprintf("%010i_all_clean_corr_%s-%s_%s.ds",
			      $o,
			      'bkg',
			      $self->eband,
			      $p
			     );

	    unlink ($sum) if (-e $sum);

	    my $cmd = "addimages ".join(' ',@{$self->bkg})." $sum";
	    say $cmd;
	    #system($cmd);
	    `$cmd`;

	    if ($?) {
		croak "Error ($?) while calling:\n$cmd";
	    }
	}

    }


}


1;
