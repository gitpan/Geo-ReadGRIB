###########################################################################
# Geo::ReadGRIB 
# 
# - A Perl extension that gives read access to GRIB "GRIdded Binary" 
#   format Weather data files.
#
# - Copyright (C) 2006 by Frank Cox
###########################################################################

package Geo::ReadGRIB;
$VERSION = .60;

use 5.6.1;
use strict;


my $LIB_DIR = "./";

# try to find wgrib.exe
foreach my $inc (@INC) {
   if (-e "$inc/Geo/wgrib.exe") {
      $LIB_DIR = "$inc/Geo";
      last;
   }  
}

unless (-e "$LIB_DIR/wgrib.exe") {
   die "CAN'T CONTINUE: Path to  wgrib.exe not found"
}

## Set some signal handlers to clean up temp files in case of interruptions
#  it does this by calling exit(0) which will run the END block

$SIG{INT} = $SIG{QUIT} = $SIG{TERM} = 
   sub {
      print "ReadGRIB attempting cleanup...\n";
      exit(0);
   };

END {
   unlink glob("wgrib.tmp.*");
}


###########################################################################
# new()
###########################################################################
sub new {

   my $class = shift;
   my $gFile = shift;
   unless (defined $gFile) {
      die "new(): Usage: Geo::ReadGRIB->new(GRIB_FILE)"
   }
   my $self = {};
   bless $self, $class;

   $self->{fileName} = $gFile;
   $self->{DEBUG} = 0; 
   
   $self->openGrib();
   
   return $self;
}


###########################################################################
# openGrib()
#
# Open grib file using wgrib.exe and extract header data
###########################################################################
sub openGrib {

   use Time::Local;
   
   my $self = shift;

   my $tmp = $self->tempfile();
   my $cmd = "$LIB_DIR/wgrib.exe $self->{fileName} -d 1 -4yr -PDS10 -GDS10 -text -nh -o $tmp";

   my $header = qx($cmd);
   unlink $tmp;
 
   if ($?) {
      die "Error in $cmd: $?";
   }

   my @inv = split /:/, $header;

   my ($arg,$val, %head);

   $head{recNum} = $inv[0];
   $head{offset} = $inv[1];
   $head{name} = $inv[3];
   $head{level} = $inv[11];
   $head{fcst} = $inv[12];

   foreach my $invel (@inv) {
      chomp $invel;
      # print "$invel \n";
      if ($invel =~ /=/) {
         ($arg,$val) = split /=/, $invel;
         $val =~ s/^\s+//;
         $head{$arg} = $val;
         # print "    ($arg,$val) \n";
      }
   }

   foreach (sort keys %head) {
#     print " $_: $head{$_}\n";
      $self->{$_} = $head{$_};
   }
   
   foreach (keys %head) {
#     $self->{$_} = $head{$_};
   }

   # reduce date string to 'time' format
   my ($yr, $mo, $day, $hr) = unpack 'A4A2A2A2', $self->{d};
   $self->{TIME} = timegm(0,0,$hr,$day,$mo -1,$yr -1900);
   
   $self->{LAST_TIME} = $self->{THIS_TIME} = $self->{TIME};
   
   $self->parseGDS($head{GDS10});
}

###########################################################################
# getFullCatalog()
#
# Just runs getCatalog() and getCatalogVerbose() in one command
# since these will usually be run together...
###########################################################################
sub getFullCatalog {
   
   my $self = shift;
   
   $self->getCatalog();
   $self->getCatalogVerbose();	
}
	
###########################################################################
# getCatalog()
###########################################################################
sub getCatalog {

   my $self = shift;
   
   my $tmp = $self->tempfile();
   my $cmd = "$LIB_DIR/wgrib.exe $self->{fileName} -o $tmp";

   my @cat = qx($cmd);
   unlink $tmp;
   
   if ($?) {
      die "Error in \$cmd: $?";
   }

   my @line;
   foreach (@cat) {
      @line = split /:/;
      $line[8] =~ s/P1=//;
      $line[8] = $line[8] * 3600 + $self->{TIME};
      $self->{LAST_TIME} = $line[8] if $line[8] >  $self->{LAST_TIME};
      $self->{catalog}->{$line[8]}->{$line[3]} = $line[0];
   }
}

###########################################################################
# getCatalogVerbose() 
#
# recovers the verbose catalog which has text discriptions 
# of data items
###########################################################################
sub getCatalogVerbose {

   my $self = shift;
   
   my $tmp = $self->tempfile();
   my $cmd = "$LIB_DIR/wgrib.exe -v $self->{fileName} -o $tmp";

   my @cat = qx($cmd);
   unlink $tmp;
   
   if ($?) {
      die "Error in \$cmd: $?";
   }

   my @line;
   foreach (@cat) {
      chomp;
      @line = split /:/;
      $line[7] =~ s/"//g;
      $self->{v_catalog}->{$line[3]} = $line[7];
   }
}


###########################################################################
# parseGDS()
#
# Assumes gds is dumped in "decimal" (-GDS10)
###########################################################################
sub parseGDS {

   my $self = shift;
   my $gds = shift;
 
   $gds =~ s/^\s+//;
   
   my @GDS = split /\s+/, $gds;

   my @slice = @GDS[6,7];
   $self->{Ni} = $self->toDecimal(\@slice);

   @slice = @GDS[8,9];
   $self->{Nj} = $self->toDecimal(\@slice);

   @slice = @GDS[10,11,12];
   $self->{La1} = $self->toDecimal(\@slice)/1000;

   @slice = @GDS[13,14,15];
   $self->{Lo1} = $self->toDecimal(\@slice)/1000;

   @slice = @GDS[17,18,19];
   $self->{La2} = $self->toDecimal(\@slice)/1000;

   @slice = @GDS[20,21,22];
   $self->{Lo2} = $self->toDecimal(\@slice)/1000;

   $self->{LaInc} = $self->calInc($self->{La1}, $self->{La2}, $self->{Nj});
   $self->{LoInc} = $self->calInc($self->{Lo1}, $self->{Lo2}, $self->{Ni});
}


###########################################################################
# toDecimal()
# 
# helper method for parseGDS()
###########################################################################
sub toDecimal {

   my $self = shift;
   my $inArray = shift;

   # if the most segnificant bit is one it's negative...
   my $isNeg = 0;
   if ($$inArray[0] >= 128) {
      $isNeg = 1;
      $$inArray[0] -= 128;
   }

#  print "===== " . $$inArray[0] . " -- " . 2**((@$inArray -1) *8) . "\n";
   
   my ($result, $m);
   for (my $i = @$inArray -1, my $j = 0; $i >= 0; $i--, $j++ ) {
      $m = 2**($j*8);
      $result += $$inArray[$i] * $m;
   }

   $result *= -1 if $isNeg;
   return sprintf "%.2d", $result;
}

###########################################################################
# dumpit()
###########################################################################
sub dumpit {

   my $self = shift;

   use Data::Dumper;
   print Dumper($self);
}

###########################################################################
# calInc( cord1, cord2, points)
#
# finds degrees between grid points given the start and end and 
# number of points. If one cord is negative South or west long/lat assumed
############################################################################ 
sub calInc {

   my $self = shift;
   my $c1 = shift;
   my $c2 = shift;
   my $pts = shift;

   my $size;
   if ($pts == 0) {
      $size = 0;
      $self->{ERROR} = "calInc: \$pts = 0";
   }
   elsif ($c1 < 0 or $c2 < 0) {
#     print "$size = (abs($c1) + abs($c2) +1) / $pts;\n";
      $size = (abs($c1) + abs($c2) +1) / $pts;
   }
   else {
#     print "$size = (abs($c1 - $c2)) / $pts\n";
      $size = (abs($c1 - $c2)) / $pts;
   }
   return sprintf "%.2f", $size;
}

###########################################################################
# lalo2offset(lat, long)
#
# converts long/lat pairs in degrees to grib table offset
###########################################################################
sub lalo2offset {

   my $self = shift;
   my $lat  = shift;
   my $long = shift;
   
   undef $self->{ERROR};

   # First check if values are out of range...
   if ($lat > $self->{La1} or $lat < $self->{La2}) {
      $self->{ERROR} = "lalo2offset(): LAT >$lat< out of range ";
      $self->{ERROR} .= "$self->{La1} to $self->{La2}";
      return;
   }
   
   if ($long < $self->{Lo1} or $long > $self->{Lo2}) {
      $self->{ERROR} = "lalo2offset(): LONG: >$long< out of range ";
      $self->{ERROR} .= "$self->{Lo1} to $self->{Lo2}";
      return;
   }

   my $out = (($self->{La1} - $lat) / $self->{LaInc}) * $self->{Ni} 
          + (($long - $self->{Lo1}) / $self->{LoInc});

   return sprintf "%d", $out;          

}


###########################################################################
# extractLaLo(data_type, lat1, long1, lat2, long2, time)
#
# Extracts forecast data for a range of locations from (lat1, long1) to 
# (lat2, long2) for the given data_type and time. This will be much faster
# than repeated calls to extract() because only one call to wgrib and just
# one file open are required.
#
# require: lat1 >= lat2 and long1 <= long2 - that is, lat1 is north or lat2
#          and long1 is west of long2 (or is the same as)
#
###########################################################################
sub extractLaLo {

   my $self   = shift;
   my $type   = shift;
   my $lat1   = shift;
   my $long1  = shift;
   my $lat2   = shift;
   my $long2  = shift;
   my $time   = shift;

   my @times = sort keys  %{$self->{catalog}};

   # First see that requested values are in range...

   if (not $lat1 >= $lat2 or not $long1 <= $long2) {
     $self->{ERROR} = "ERROR extractLaLo() ";
     $self->{ERROR} .= "require: lat1 >= lat2 and long1 <= long2";
     return 1; 
   }

   if ($time < $self->{TIME} or $time > $self->{LAST_TIME}) {
      $self->{ERROR} = "ERROR extractLaLo() \$time \"$time\" out of range ";
      $self->{ERROR} .= scalar gmtime($times[0]) . " ($times[0]) to ";
      $self->{ERROR} .= scalar gmtime($times[$#times]) 
                     . " ($times[$#times])";
      return 1;
   }
   if ($lat1 > $self->{La1} or $lat1 < $self->{La2}
       or $lat2 > $self->{La1} or $lat2 < $self->{La2}) {
      $self->{ERROR} = "extractLaLo(): LAT >$lat1 or $lat2< out of range ";
      $self->{ERROR} .= "$self->{La1} to $self->{La2}";
      return 1;
   }
   
   if ($long1 < $self->{Lo1} or $long1 > $self->{Lo2}
       or $long2 < $self->{Lo1} or $long2 > $self->{Lo2}) {
      $self->{ERROR} = "extractLaLo(): LONG: >$long1 or $long2
      < out of range ";
      $self->{ERROR} .= "$self->{Lo1} to $self->{Lo2}";
      return 1;
   }

   # use nearest time in catalog...
   for (my $i=0, my $j=1; $j<= @times; $i++, $j++) {
      if ($time >= $times[$i] and $time <= $times[$j]) {
         if (($time - $times[$i]) <= ($times[$j] - $time)) {
            $self->{THIS_TIME} = $times[$i]
         }
         else {
            $self->{THIS_TIME} = $times[$j]
         }
         last;
      }
   }

   my $record = $self->{catalog}->{$time}->{$type};

   my $tmp = $self->tempfile();
   my $cmd = "$LIB_DIR/wgrib.exe $self->{fileName} -d $record -nh -o $tmp";
   my $res = qx($cmd);
   open F, $tmp;

   my ($offset, $dump);
   for (my $lo= $long1; $lo <= $long2; $lo += $self->{LoInc} ) {
      for (my $la= $lat1; $la >= $lat2; $la -= $self->{LaInc} ) {
         $offset = $self->lalo2offset($la, $lo);
         seek F, $offset *4, 0;
         read F, $dump, 4;
         $dump = unpack "f", $dump;
         $dump = sprintf "%.2f", $dump;
         $dump = "UNDEF" if $dump > 999900000000000000000;
         print gmtime($time) . ": $self->{v_catalog}->{$type}  $dump\n"
            if $self->{DEBUG};
         $self->{data}->{$time}->{$la}->{$lo}->{$type} = $dump;
      }
   }
   close F;
   unlink $tmp;   
}

###########################################################################
# $val = extract(data_type, lat, long, [time])
# 
# Extracts forecast data for given type and location. Ectracts data for all
# times in file unless a specific time is given in epoch seconds.
# 
# type will be one of the data types in the data
###########################################################################
sub extract {

   my $self   = shift;
   my $type   = shift;
   my $lat    = shift;
   my $long   = shift;
   my $time   = shift;

   my $offset = $self->lalo2offset($lat, $long);

   $time = 0 unless defined $time;
   
   undef $self->{ERROR};

   if ($time != 0 and $time < $self->{TIME} 
                      or $time > $self->{LAST_TIME}) {
      my @times = sort keys %{$self->{catalog}};
      $self->{ERROR} = "ERROR extract() \$time \"$time\" out of range ";
      $self->{ERROR} .= scalar gmtime($times[0]) . " ($times[0]) to ";
      $self->{ERROR} .= scalar gmtime($times[$#times]) 
                     . " ($times[$#times])";
      return 1;
   }
   
   # If a time is given find nearest in catalog
   if (defined $time) {
      my @times = sort keys  %{$self->{catalog}};
      for (my $i=0, my $j=1; $j<= @times; $i++, $j++) {
         if ($time >= $times[$i] and $time <= $times[$j]) {
            if (($time - $times[$i]) <= ($times[$j] - $time)) {
               $self->{THIS_TIME} = $times[$i]
            }
            else {
               $self->{THIS_TIME} = $times[$j]
            }

            last;
         }
      }
   }
   my ($record, $cmd, $res, $dump);

   unless ( defined $self->{v_catalog}->{$type} ) {
      $self->{ERROR} = "extract() Type not found: $type";
      return 1;
   }

   # Give avaiable data for type and offset.
   # All times returned unless $time is given.
   #
   # If record is alredy in $self->{data} use that
   # else go to disk...
   foreach my $tm (sort keys %{$self->{catalog}}) {
      if ($time != 0) {
         $tm = $self->{THIS_TIME};
      }
      if (defined $self->{data}->{$tm}->{$lat}->{$long}->{$type}) {
         if ($self->{DEBUG}) {
            print "[c]",gmtime($tm),": $self->{v_catalog}->{$type}  ";
            print "$self->{data}->{$tm}->{$lat}->{$long}->{$type}\n";
         }
         last if $time != 0;
         next;
      }
      $record = $self->{catalog}->{$tm}->{$type};

      my $tmp = $self->tempfile();
      $cmd = "$LIB_DIR/wgrib.exe $self->{fileName} -d $record -nh -o $tmp";
      $res = qx($cmd);
      print "$cmd - OFFSET: $offset " . $offset *4 . " bytes\n"
         if $self->{DEBUG};
      open F, "$tmp";
      seek F,$offset *4, 0;
      read F, $dump, 4;
      $dump = unpack "f", $dump;
      $dump = sprintf "%.2f", $dump;
      $dump = "UNDEF" if $dump > 999900000000000000000;
      print gmtime($tm) . ": $self->{v_catalog}->{$type}  $dump\n"
         if $self->{DEBUG}; 
      $self->{data}->{$tm}->{$lat}->{$long}->{$type} = $dump;
      close F;
      unlink $tmp;
      last if $time != 0;
   }
   return 0;
}

###########################################################################
# getDataHash()
#
# Returns a hash ref with all the data items in the object.
# This will be all the data extracted from the GRIB file for
# in the life of the object.
#  
# The structure is
#
#    $t->{time}->{lat}->{long}->{type}
###########################################################################
sub getDataHash {
   my $self = shift;
   return $self->{data}; 
}

###########################################################################
# getError()
#
# returns error string from $self->{ERROR}
###########################################################################
sub getError {

   my $self = shift;
   defined $self->{ERROR} ? $self->{ERROR} : undef;
}


###########################################################################
# m2ft(meters)
#
# convert meters to feet
###########################################################################
sub m2ft {
   
   my $self = shift;
   my $m    = shift;
   return $m * 3.28;
}

###########################################################################
# tempfile()
#
# return a  temp file name
###########################################################################
sub tempfile {

   my $self = shift;

   use File::Temp qw(:mktemp);

   my ($fh,$fn) = mkstemp("wgrib.tmp.XXXXXXXXX");
   return $fn;
}

###########################################################################
# $p = getParam(parm_name)
#
# getParam(param_name) returns a scalar with the value of param_name
# getParam("show") returns a scalar listing published parameter names.
###########################################################################
sub getParam {
   
   my $self = shift;
   my $arg  = shift;

   my @published = qw/TIME LAST_TIME La1 La2 LaInc Lo1 Lo2 LoInc fileName/;
      
   my $param;
   if (defined $arg) { 
      if ($arg =~ /show/i) {
         $param = "@published";
      }
      elsif (grep /$arg/, @published) {
         $param = $self->{$arg};
      }
      else {
         $self->{ERROR}  = "getParam(): ";
         $self->{ERROR} .= "$arg - Undefined or unpublished parameter";
         return 1;
      }
   }
   else {
      $self->{ERROR}  = "getParam(): Usage: getParam(param_name)";
      return 1;
   }

   return $param;
}


###########################################################################
# show()
# 
# Returns a scalar containing a string with some selected meta data 
# describing the GRIB file. 
###########################################################################
sub show {

   my $self = shift;
   my $arg  = shift;

   my $param;

   my @published = qw/LAST_TIME La1 La2 LaInc Lo1 Lo2 LoInc TIME fileName/;
      
   if (defined $arg) { 
      if ($arg =~ /show/i) {
         $param = "@published";
      }
      elsif (grep /$arg/, @published) {
         $param = $self->{$arg};
      }
      else {
         $self->{ERROR} = "show(): $arg - Undefined or unpublished parameter";
         return 1;
      }
   }
   else {
      my $types;
      foreach (sort keys %{$self->{v_catalog}}) {
         $types .= sprintf "%8s: %s\n", $_, $self->{v_catalog}->{$_};
      }
  
      my @times = sort keys %{$self->{catalog}};
      my $t = scalar gmtime($times[0]) . " ($times[0]) to ";
      $t   .= scalar gmtime($times[$#times]) . " ($times[$#times])";
  
      $param = <<"      PARAM";
     
      Locations:
     
      lat: $self->{La1} to $self->{La2}
      long: $self->{Lo1} to $self->{Lo2}
  
      Times:
  
      $t
     
      Types:
      \n$types
      PARAM
   }
   return $param;
}


1;

__END__

=head1 NAME

Geo::ReadGRIB - Perl extension that gives read access to GRIB "GRIdded
Binary" format Weather data files.

=head1 SYNOPSIS

  use Geo::ReadGRIB;
  $w = new Geo::ReadGRIB "grib-file";
  
  $w->getCatalog();         #
  $w->getCatalogVerbose();  # or just use $w->getFullCatalog() 
                            #
  
  # The object now contains the full inventory of the GRIB file
  # including the "verbose" text description of each parameter
  
  print $w->show(); 
  
  $w->extract(data_type, lat, long, time); 

  #
  # or $w->extractLaLo(data_type, lat1, long1, lat2, long2, time);
  # to extract a range of locations
  #

  print $w->getError(),"\n";    # undef if no error
  $data = $w->getDataHash();
  
  # $data contains a hash reference to all grib data extracted
  # by the object in its lifetime.
  #  
  # $data->{time}->{lat}->{long}->{data_type} now contains data 
  # for data_type at lat,long and time unless there was an error
  


=head1 DESCRIPTION

Geo::ReadGRIB is an object Perl module that provides read access to data
distributed in GRIB files. Specifically, I wrote it to access NOAA Wavewatch 
III marine weather model forecasts which are packaged as GRIB. Wavewatch GRIB's
can currently be found under 

ftp://polar.ncep.noaa.gov/pub/waves/

GRIB stands for "GRIdded Binary" and it's a format developed by the World
Meteorological Organization (WMO) for the exchange of weather product 
information. See for example 

http://www.nco.ncep.noaa.gov/pmb/docs/on388/

for more about the GRIB format.

=head2 wgrib.c

Geo::ReadGRIB uses the C program wgrib to retrieve the GRIB file catalog and
to extract the data. wgrib.c is included in the distribution and will
compile when you make the module. The resulting executable is named wgrib.exe
and should install in the same location as ReadGRIB.pm. ReadGRIB will search
for wgrib.exe at run time and die if it can't find it.

wgrib.c is known to compile and install correctly with Geo::ReadGRIB on 
FreeBSD, LINUX and Windows. In all cases the compiler was gcc and on Windows 
ActivePerl and nmake were used and the CC=gcc option was used with Makefile.PL
I've also been able to compile wgrib.c with gcc on Solaris Sparc and i386.

wgrib.exe creates a file called wgrib.tmp.XXXXXXXXX in the local directory where 
the X's are random chars. The id that runs a program using Geo::ReadGRIB needs
write access to work. This temp file will be removed after use by each method 
calling wgrib.exe

=head1 Methods

=over 4

=item $object = new Geo::ReadGRIB "grib_file";

Returns a Geo::ReadGRIB object that can open GRIB format file "grib_file".
wgrib.exe is used to extract full header info from the "self describing" GRIB
file. 

=item $object->getCatalog(); 

=item $object->getCatalogVerbose();

=item $object->getFullCatalog();

Retrieve Catalog info from the GRIB file. 

getCatalog() gets most of the info including the critical offset index for 
each data type and time in the file.

getCatalogVerbose() will get the full text descriptions of data items.

getFullCatalog() just runs both getCatalog() and getCatalogVerbose() . Each
method invocation needs to call wgrib.exe. Just running getCatalog() may save 
some cycles if full descriptions aren't needed.

=item $object->getParam(param);

=item $object->getParam("show");

I<getParam(param)> returns a scalar with the value of param where param is one
of TIME, LAST_TIME, La1, La2, LaInc, Lo1, Lo2, LoInc, fileName.

=over

=item

I<TIME> is the time of the earliest data items in epoch seconds. 

=item

I<LAST_TIME> is the time of the last data items in epoch seconds.

=item

I<La1> I<La2> First and last latitude points in the GRIB file (or most northerly and most southerly).

=item

I<LaInc> The increment between latitude points in the GRIB file. 

=item

I<Lo1> I<Lo2> First and last longitude points in the GRIB file (or most westerly and most easterly).

=item

I<LoInc> The increment between latitude points in the GRIB file.

=item

I<filename> The file name of the GRIB file this object will open to extract
data.

=back

I<getParam(show)> Returns a string listing the names of all published parameters.

=item $object->show();

Returns a formatted text string description of the data in the GRIB file.
This includes latitude, longitude, and time ranges, and data type text 
descriptions (if getCatalogVerbose() has run).

=item $object->extractLaLo(data_type, lat1, long1, lat2, long2, time);

Extracts forecast data for a given type and time for a range of locations. 
The locations will be all (lat, long) points in the GRIB file inside the 
rectangular area defined by (lat1, long1) and (lat2, long2) where lat1 >= lat2
and long1 <= long2. That is, lat1 is north or lat2 and long1 is west of long2
(or is the same as...)

Since extractLaLo() needs only one call to wgrib and one temp file open,
this is faster than using extract() to get the same data points.

=item $object->extract(data_type, lat, long, [time]);

Extracts forecast data for given type and location. Time is optional.
Extracts data for all times in file unless a specific time is given 
in epoch seconds.

lat and long will be in the range -90 to 90 degrees lat and 0 to 359 degrees
long. Longitude in GRIB files is 0 to 359 east. If you have degrees in 
longitude west you will need to convert it first. If lat or long is out of
range for the current file an error will be set ( see getError() ).

time will be in epoch seconds as returned, for example, by Time::Local. If the 
time requested is in the range of times in the file but not one of the exact 
times in the file, the nearest existing time will be used. An error will be set
if time is out of range.

type will be one of the data types in the data or an error is set.

=item $object->getError();

Returns string messages for the last error set. If no error is set getError()
returns undef. Any method that sets errors will clear errors first when called.
It's good practice to check errors after an extract().

=item $object->getDataHash();

Returns a hash ref with all the data items in the object. This will be all the 
data extracted from the GRIB file for in the life of the object.
 
The hash structure is

   $d->{time}->{lat}->{long}->{type}

=back

=head1 SEE ALSO

For more on wgrib.c see 

http://www.cpc.ncep.noaa.gov/products/wesley/wgrib.html

For more on Wavewatch III see

http://polar.ncep.noaa.gov/waves/wavewatch/wavewatch.html


=head1 AUTHOR

Frank Cox, E<lt>frank.l.cox@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Frank Cox

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.


=cut
