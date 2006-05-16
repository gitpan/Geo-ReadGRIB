use 5.006;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Geo::ReadGRIB',
    VERSION_FROM      => 'lib/Geo/ReadGRIB.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Geo/ReadGRIB.pm', # retrieve abstract from module
       AUTHOR         => 'NULL <lyon@vwh.net>') : ()),
    SKIP              => [qw(static static_lib dynamic_lib)],
    clean             => {FILES => "wgrib.exe"},
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

