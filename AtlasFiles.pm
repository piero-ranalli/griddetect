package AtlasFiles;

=head1 NAME

AtlasFiles.pm

=head1 SYNOPSYS

my $atlas = AtlasFiles->new;
$atlas->use_astrometry_corr(1);
$atlas->obsid('0725290101');

my $attitude = $atlas->attitude;
my $ccf = $atlas->ccf;
my $odf = $atlas->odf;

=cut




use Carp;
use Moose;

has 'obsid'      => (is => 'rw', isa => 'Str');

has 'use_astrometry_corr' => (is => 'rw', isa => 'Bool', default => 0 );
has 'attitude_regexp' =>     (is => 'rw', isa => 'RegexpRef', builder => 'attre_nocorr' );

has 'attitude'   => (is => 'rw', isa => 'Str');
has 'ccf'        => (is => 'rw', isa => 'Str');
has 'odf'        => (is => 'rw', isa => 'Str');

has 'baseline'   => (is => 'ro', isa => 'Str',
		     default => '/home/pranalli/Data/Atlas/' );

after 'obsid' => sub {
    my $self  = shift;
    my $obsid = shift;

    if ($obsid) {
	my $globexpr = sprintf('%s/%s/13.0Proc/*AttHk*.ds',
			       $self->baseline,$obsid);
	$self->attitude( $self->find($globexpr, $self->attitude_regexp) );


	$globexpr =  sprintf('%s/%s/odf/ccf.cif',
			     $self->baseline,$obsid);
	$self->ccf( $self->find($globexpr) );

	$globexpr =  sprintf('%s/%0s/odf/*SUM.SAS',
			     $self->baseline,$obsid);
	$self->odf( $self->find($globexpr) );
    }
};


after 'use_astrometry_corr' => sub {
    # look for a particular attitude file
    my $self = shift;
    my $corr = shift;

    if ($corr) {
	$self->attitude_regexp( attre_corr() );
    } else {
	$self->attitude_regexp( attre_nocorr() );
    }
};

# sub choose_attitude_regexp {
#     my $self = shift;

#     if ($self->use_astrometry_corr) {
# 	$self->attitude_regexp( qr/\d+_\d+_AttHk_corr\.ds/ );
#     } else {
# 	$self->attitude_regexp( qr/\d+_\d+_AttHk\.ds/ );
#     }
# };


sub attre_nocorr {
    return qr/\d+_\d+_AttHk\.ds/;
}
sub attre_corr {
    return qr/\d+_\d+_AttHk_corr\.ds/;
}


sub find {
    my $self = shift;
    my $expr = shift;
    my $filter_re = shift;

    my @files = glob( $expr );

    # if asked to filter, then take the right one
    if (defined $filter_re) {
	@files = grep (/$filter_re/, @files);
    }

    if ($#files >= 1) {
	croak "ERROR - More than 1 file found with glob expression $expr\n";
    } elsif ($#files == -1) {
	croak "ERROR - No file found with glob expression $expr\n";
    }
    return $files[0];
}



1;



__END__

# old code that was in img-extractor-expmap.pl, left here for future reference
# (e.g. for future support of SAS v. 11 and 12)


# override ccfcif/sumsas/attitude detection logic if the files are specified as options
unless (defined($atthk) and (
			     (defined($ccf_cif) and defined($sum_sas)) or
			     $simpipeline ))  {

    # are we working with files in /GTI/ or in /ESAS/?  (in ESAS there are
    # the oot)
    my $gti;
    if ($evtname =~ m/GTI/) {
	$gti = 'GTI';
    } elsif ($evtname =~ m/ESAS/) {
	$gti = 'ESAS';
    } elsif ($evtname =~ m/bootstrap/ or $evtname =~ m/simulated/ or $evtname =~ m/particle/) {
	$gti = 'SIMULATION';
    } else {
	# zeus default: use 'GTI'
	$gti = 'GTI';
	#die "Cannot find GTI or ESAS in the path of file $evtname.\n";
    }

    # first, find the AttHk file by removing the /GTI/filename.fits tail
    # in #evtname and performing a glob
    my $attitude_dir = $evtname;
    #if ($gti ne 'SIMULATION') {
	#$attitude_dir =~ s|/$gti/.*$||;
    #} else {
	# get obsid
	my $obsid = $evthdr->{OBS_ID}; #($evtname =~ m/[-_](\d{10}?)[-_]/);
	$attitude_dir = "/home/pranalli/Data/Atlas/$obsid/13.0Proc";
    #}
    my @atthk_files = glob( $attitude_dir.'/*AttHk*.ds' );


    # then take the right one
    if ($attitude_regexp) {
	@atthk_files = grep( /$attitude_regexp/, @atthk_files );
    }
    if ($#atthk_files >= 1) {
	die "ERROR - More than 1 attitude file in ${attitude_dir}! \n";
    } elsif ($#atthk_files == -1) {
	die "ERROR - No attitude file found in $attitude_dir\n";
    }
    $atthk = $atthk_files[0];

    # now find ccf.cif  (it's in the odf dir)
    my $odf_dir  = $attitude_dir;
    if ($gti ne 'SIMULATION') {
	$odf_dir =~ s|/13.0Proc.*$|/odf/|;
    } else {
	$odf_dir = $attitude_dir;
	$odf_dir =~ s|/10.0.0Reprocessed.*$|/odf/|;
    }
    my @cif_files = glob( $odf_dir.'/ccf.cif' );
    if ($#cif_files >= 1) {
	die "ERROR - More than 1 ccf.cif file in ${odf_dir}! \n";
    } elsif ($#cif_files == -1) {
	die "ERROR - No ccf.cif file found in ${odf_dir}\n";
    }
    $ccf_cif = $cif_files[0];
    if ($SAS_VER >= 11 and $SAS_VER<=12) {
	$ccf_cif =~ s|/ccf.cif$||;
    }

    # and finally the *SUM.SAS
    my @sumsas_files = glob( $odf_dir.'/*SUM.SAS' );
    if ($#sumsas_files >= 1) {
	die "ERROR - More than 1 *SUM.SAS file in ${odf_dir}! \n";
    } elsif ($#sumsas_files == -1) {
	die "ERROR - No *SUM_SAS file found in ${odf_dir}\n";
    }

    $sum_sas = $sumsas_files[0];
    if ($SAS_VER >= 11 and $SAS_VER<=12) {
	$sum_sas = $ccf_cif;
    }
}
