# Test to see if a Geo::ReadGRIB object can return the 
# expected parameter data.
#
# In this case there are two 180 degree places for each lat,
# one on each edge of the flat grid, and 
# this test makes sure they are the same value
# 
# For this to work there needs to be a specific sample GRIB file
# and the module has to be able to find wgrib.exe 

BEGIN{ unshift @INC, '.'}


use Test::More tests => 9;
use strict;
use warnings;
use Config;

my $nvtype = $Config{nvtype};
my $nvsize = $Config{nvsize};

###########################################################################
# Test for 64bit uselongdouble strangeness 
############################################################################

use Geo::ReadGRIB;

## Find path to test file
my $TEST_FILE;
foreach my $inc (@INC) {
   if (-e "$inc/Geo/Sample-GRIB/2009100900_P000.grib") {
      $TEST_FILE = "$inc/Geo/Sample-GRIB/2009100900_P000.grib";
      last;
   }  
}

ok(-e "$TEST_FILE") or
   diag("Path to sample GRIB file not found");

my $w = Geo::ReadGRIB->new("$TEST_FILE");

diag("This platform includes nvtype $nvtype, nvsize $nvsize and will fail some tests")
    if $nvtype =~ /long double/;

my $lat = 63;
my $calc = ((($lat - -90)/.6) * 601) + (360 /.6);
ok( $calc == 153855 ) or
    diag ("raw (($lat - -90)/.6) * 601) + (360 /.6) = 153855 not $calc  ");

my $calcPC = sprintf "%d", $calc;
ok( $calcPC == 153855 ) or
    diag ("sprintf %d, (($lat - -90)/.6) * 601) + (360 /.6) = 153855 not $calcPC  ");

my $calcInt = int( $calc );
ok( $calcInt == 153855 ) or
    diag ("int (($lat - -90)/.6) * 601) + (360 /.6) = 153855 not $calcInt  ");

$calc = 153 / .6;
ok( $calc == 255 ) or diag("153 / .6 = 255 not $calc");

$calc = (153 / .6) * 601;
ok( $calc == 153255 ) or diag("153 / .6 * 600 = 153255 not $calc");

$calc = ($lat - -90)/.6;
ok( $calc == 255 ) or diag("($lat - -90)/.6 = 255 not $calc");

$calc = ((($lat - -90)/.6) * 601);
ok( $calc == 153255 ) or diag("((($lat - -90)/.6) * 601) = 153255 not $calc");

$calc = (360 / .6);
ok( $calc == 600 ) or diag("360 / .6 = 600 not $calc");
