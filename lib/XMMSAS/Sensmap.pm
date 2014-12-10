package XMMSAS::Sensmap;

use Moose::Role;

=head1 NAME

XMMSAS::Sensmap --  sensitivity maps with esensmap

=head1 SYNOPSIS

 $d = XMMSAS::Detect->new;
 ...
 $d->make_srcmasks;   # makes source masks for each expmap in $d->exp
 $d->sensmap('sensmap-001-004.fits');
 $d->esensmap;        # calls esensmap

=cut

has 'detmask'     => ( is => 'rw', isa => 'ArrayRef[Str]' );
has 'sensmap'     => ( is => 'rw', isa => 'Str' );

# emask parameters, with defaults set to SAS 13 defaultsh
has mskthreshold1 => ( is => 'rw', isa => 'Num', default => 0.3 ); # fraction of max exposure
has mskthreshold2 => ( is => 'rw', isa => 'Num', default => 0.5 ); # gradient of exposure
has mskclobber    => ( is => 'rw', isa => 'Bool', default => 0 );  # overwrite already present masks? 

# esensmap parameters, with defaults set to SAS 13 defaults
has sensmlmin => ( is => 'rw', isa => 'Num', default => 10 ); # fraction of max exposure

sub make_srcmasks {
    my $self = shift;

    my @masks;
    for my $e ( @{ $self->expmap } ) {

	my $m = $e;
	$m =~ s/_exp-/_msk-/;

	my $cmd = sprintf("emask expimageset=%s detmaskset=%s threshold1=%s threshold2=%s",
			  $e,$m,$self->mskthreshold1,$self->mskthreshold2);

	$self->call($cmd) unless (! $self->mskclobber and -e $m);

	push (@masks, $m);
    }
    $self->detmask( \@masks );
}


sub fudge_obsid_instr_in_detmasks {
    my $self = shift;

    $self->do_fudge_o_i_in_detmasks( $self->detmask, 0 );  # primary extension
    $self->do_fudge_o_i_in_detmasks( $self->detmask, 1 );  # detmask
    $self->do_fudge_o_i_in_detmasks( $self->expmap, 0 );
    $self->do_fudge_o_i_in_detmasks( $self->bkg, 0 );
}


sub do_fudge_o_i_in_detmasks {
    my $self = shift;
    my $files = shift;
    my $e = shift // 0;

    my $expid = 1;

    #my $n = @$files;
    #my @inst = (('EPN') x 9,('EMOS2') x 9,('EMOS1') x 9);

    #@exp = map { $_ + 7252901
    my $i = 0;
    for my $f (@$files) {

	# rotate exposure values otherwise emldetect will think it's
	# the same instrument but different band, and will crash if
	# there are more than 6 "bands".

	my $cmd = "fthedit $f+$e INSTRUME add 'EPN'";
	$self->call($cmd);
	$cmd = sprintf("fthedit $f+$e EXP_ID add '%010i'",725290100+$expid);
	$self->call($cmd);
	$cmd = sprintf("fthedit $f+$e EXPIDSTR add '%03i'",$expid);
	$self->call($cmd);
	$cmd = sprintf("fthedit $f+$e OBS_ID add '%010i'",725290100+$expid);
	$self->call($cmd);

	$expid++;
	$i++;
	if ($i>5) {
	#    $expid=1;
	    $i=0;
	}
    }
}



sub esensmap {
    my $self = shift;

    my $cmd = sprintf("esensmap detmasksets=\"%s\" expimagesets=\"%s\" bkgimagesets=\"%s\" sensimageset=\"%s\" mlmin=%s",
		      join(' ',@{ $self->detmask }),
		      join(' ',@{ $self->expmap }),
		      join(' ',@{ $self->bkg }),
		      $self->sensmap,
		      $self->sensmlmin
	);

    $self->call( $cmd );
}




1;
