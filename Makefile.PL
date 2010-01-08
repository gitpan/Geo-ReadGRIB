use 5.6.1;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my @ppd;

if ($] >= 5.00503) {
  @ppd = (
    ABSTRACT     => 'Perl extension that gives read access to GRIB weather data files',
    AUTHOR       => 'Frank Cox <frank.l.cox@gmail.com>',
  );
}


WriteMakefile(
    NAME         => 'Geo::ReadGRIB',
    VERSION_FROM => 'lib/Geo/ReadGRIB.pm', # finds $VERSION
    PREREQ_PM    => {}, # e.g., Module::Name => 1.1
    LICENSE      => 'perl',
    SKIP         => [qw(static static_lib dynamic_lib)],
    clean        => {FILES => "wgrib.exe"},
    @ppd,
);

sub MY::dynamic {
'
dynamic :: $(INST_LIB)/Geo/wgrib.exe
	@$(NOOP)

$(INST_LIB)/Geo/wgrib.exe: $(C_FILES)
	$(CC) -o $(INST_LIB)/Geo/wgrib.exe wgrib.c
';
}

sub MY::libscan {
    my $path = $_[1];
    return '' if $path =~ /\B\.svn\b/;
    return $path;
}

