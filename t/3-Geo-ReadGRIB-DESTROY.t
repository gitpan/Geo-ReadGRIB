# Test to see if a Geo::ReadGRIB removes the temp file used by
# wgrib.exe when the object ceases to exist
#
# 
# For this to work there needs to be a sample GRIB file
# and the module has to be able to find wgrib.exe 


use Test::More tests => 3;

###########################################################################
# Object create test
###########################################################################

use Geo::ReadGRIB;

## Find path to test file
my $TEST_FILE;
foreach my $inc (@INC) {
   if (-e "$inc/Geo/Sample-GRIB/akw.HTSGW.grb") {
      $TEST_FILE = "$inc/Geo/Sample-GRIB/akw.HTSGW.grb";
      last;
   }  
}

ok(-e "$TEST_FILE") or
   diag("Path to sample GRIB file not found");

my $w = Geo::ReadGRIB->new("$TEST_FILE");

ok(-e "WGRIB.tmp") or
   diag("Temp file WGRIB.tmp should exist at this point");

undef $w;

ok(not -e "WGRIB.tmp") or
   diag("Temp file WGRIB.tmp should not exist at this point");

