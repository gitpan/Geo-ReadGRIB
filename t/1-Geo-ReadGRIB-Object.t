# Test to see if a Geo::ReadGRIB object can be created
# For this to work there needs to be a sample GRIB file
# and the module has to be able to find wgrib.exe 


use Test::More tests => 1;

###########################################################################
# Object create test
###########################################################################

use Geo::ReadGRIB;

my $o = new Geo::ReadGRIB "lib/Geo/Sample-GRIB/akw.HTSGW.grb";
ok(ref $o eq "Geo::ReadGRIB") or
   diag("Test for object creation FAILED: Not an object ref to Geo::ReadGRIB");


