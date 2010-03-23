use 5.6.1;
use ExtUtils::MakeMaker;
use Config;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my @ppd;

if ($] >= 5.00503) {
  @ppd = (
    ABSTRACT     => 'Perl extension that gives read access to GRIB weather data files',
    AUTHOR       => 'Frank Cox <frank.l.cox@gmail.com>',
  );
}

eval {system("gcc", "-dumpversion")};
if ($?) {
    print STDERR <<EOF;
    #--------------------------- shucks! ---------------------------------
    #
    # The gcc compiler was not found in you PATH.
    #
    # A C compiler is required by this installer and only gcc is
    # currently supported. 
    #
    # Sorry about that.
    #
    # If you use another compiler and would like this modules maintainers
    # to add support for it, please post a bug by sending email to: 
    #
    #     bug-Geo-ReadGRIB\@rt.cpan.org
    #
    # Please mention the compiler you use and the options required to 
    # compile a simple, single file, C program if you know them. It would 
    # also be helpful if you are able to help with testing. Particularly 
    # if your compiler isn't free and/or the maintainers don't have easy
    # access to your OS.
    #
    #---------------------------------------------------------------------

EOF

    print "//\$Config{cc}: $Config{cc}//\n";
    die "OS unsupported";
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

