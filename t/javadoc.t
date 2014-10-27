#!perl

#
# Copyright 2014 Chris West (Faux)
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

use File::Temp 'tempdir';
use Test::More tests => 2;
use File::StripNondeterminism;

$dir = tempdir( CLEANUP => 1 );
$path = "$dir/a.html";
open(my $fh, '>', $path) or die("error opening $path");
print $fh <<'ORIGINAL';
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">
<!-- NewPage -->
<html lang="en">
<head>
<!-- Generated by javadoc (1.8.0_20) on Mon Oct 27 21:31:13 GMT 2014 -->
<title>Generated Documentation (Untitled)</title>
<script type="text/javascript">;
ORIGINAL

close $fh;

$normalizer = File::StripNondeterminism::get_normalizer_for_file($path);
isnt(undef, $normalizer);
$normalizer->($path);

open FILE,$path or die("error opening $path");
binmode FILE;
local $/ = undef;
is(<FILE>, <<'EXPECTED');
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">
<!-- NewPage -->
<html lang="en">
<head>
<title>Generated Documentation (Untitled)</title>
<script type="text/javascript">;
EXPECTED

