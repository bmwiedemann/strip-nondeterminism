#!perl

#
# Copyright 2014 Chris West (Faux)
# Copyright 2015 Andrew Ayer
#
# This file is part of strip-nondeterminism.
#
# strip-nondeterminism is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# strip-nondeterminism is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with strip-nondeterminism.  If not, see <http://www.gnu.org/licenses/>.
#

use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use File::Temp 'tempdir';
use Test::More tests => 6;
use File::StripNondeterminism;
use strict;
use warnings;

my $dir = tempdir( CLEANUP => 1 );
my $path;
my $fh;
my $normalizer;

#
# pom.properties
#

$path = "$dir/pom.properties";
open($fh, '>', $path) or die("error opening $path");

# note that the line has a load of random trailing whitespace (?!)
print $fh <<'ORIGINAL';
#Generated by Maven
#Mon Oct 27 09:12:51 UTC 2014                                                 
version=2.4
ORIGINAL
close($fh);

sub normalise {
    my $path = shift(@_);

    $normalizer = File::StripNondeterminism::get_normalizer_for_file($path);
    isnt(undef, $normalizer);
    $normalizer->($path);
}

normalise($path);

open($fh, '<', $path) or die("error opening $path");
is(do { local $/; <$fh> }, <<'EXPECTED');
#Generated by Maven
version=2.4
EXPECTED
close($fh);

#
# version.properties
#
$path = "$dir/version.properties";
open($fh, '>', $path) or die("error opening $path");

# note that the line has a load of random trailing whitespace (?!)
print $fh <<'ORIGINAL';
#Build Number for ANT. Do not edit!
#Wed Feb 04 03:46:03 UTC 2015                                                 
build.number=125
ORIGINAL
close($fh);

normalise($path);

open($fh, '<', $path) or die("error opening $path");
is(do { local $/; <$fh> }, <<'EXPECTED');
#Build Number for ANT. Do not edit!
build.number=125
EXPECTED
close($fh);

#
# felix bundle pom.properties
#

$path = "$dir/foo.jar";
my $zip = Archive::Zip->new();
$zip->addString(<<'ORIGINAL'
#Generated by org.apache.felix.bundleplugin
#Mon Aug 10 07:12:44 GMT-12:00 2015
version=1.5
ORIGINAL
, 'pom.properties');

unless ($zip->writeToFileNamed($path) == AZ_OK) {
    die("couldn't write test zip");
}

normalise($path);

my $afterzip = Archive::Zip->new();
unless ( $afterzip->read($path) == AZ_OK ) {
    die("couldn't read test zip");
}

is($afterzip->memberNamed('pom.properties')->contents(), <<'EXPECTED'
#Generated by org.apache.felix.bundleplugin
version=1.5
EXPECTED
);

