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


use Test::More tests => 7;
use strict;
use warnings;


###########################################################################
# Object create test
###########################################################################

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

$w->getFullCatalog();

ok(  not $w->getError ) or 
    diag( $w->getError );

my $plit = $w->extract( "WIND", 89.4, -180, 1255046400 );
print $w->getError, "\n" if defined $w->getError;

ok( not $w->getError ) or
    diag( $w->getError );

my $plit2 = $w->extract( "WIND", 89.4, 180, 1255046400 );
print $w->getError, "\n" if defined $w->getError;

ok( not $w->getError ) or
    diag( $w->getError );

#use Data::Dumper; 
#print STDERR Dumper $tpit;


while ( (my $place = $plit->current and $plit->next ) 
        and ( my $place2 = $plit2->current and $plit2->next ) ) {

    ok( $place->data( 'WIND' ) == $place2->data( 'WIND' ) )
        or diag("Not equal on extract() for lat ",$place->lat," got: ",$place->data('WIND')," and ",$place2->data('WIND') );
}

my $offset1 = $w->lalo2offset( 89.4, -180 );
my $offset2 = $w->lalo2offset( 89.4, 180 );

ok( $offset1 == 179699 ) or
    diag( "lalo2offset( 89.4, -180 ) should be 179699 not $offset1");

ok( $offset2 == 180299 ) or
    diag( "lalo2offset( 89.4, 180 ) should be 180299 not $offset2");

