# Test to see if a Geo::ReadGRIB object can return the 
# expected data.
# 
# For this to work there needs to be a specific sample GRIB file
# and the module has to be able to find wgrib.exe 


use Test::More tests => 2;

###########################################################################
# Object create test
###########################################################################

use Geo::ReadGRIB;

my $w = Geo::ReadGRIB->new("lib/Geo/Sample-GRIB/akw.HTSGW.grb");

#$w->getCatalog();
#$w->getCatalogVerbose();

$w->getFullCatalog();

my ($type, $lat, $long, $time) = ("HTSGW", 45, 160, 1142564400);
$w->extract($type, $lat, $long, $time); $w->dumpit();

$err = $w->getError();

diag("ERROR: $err") if defined $err;

my $data = $w->getDataHash();

ok(defined $data->{$time}->{$lat}->{$long}->{$type})
   or diag("\$data->{$time}->{$lat}->{$long}->{$type} is not defined");


ok($data->{$time}->{$lat}->{$long}->{$type} == 3.43)
 or diag("\$data->{$time}->{$lat}->{$long}->{$type}: 
         \$data->{1142564400}->{45}->{160}->{\'HTSGW\'} should return 3.43");


