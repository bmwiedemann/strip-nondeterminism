#
# Copyright 2014 Chris West (Faux)
# Copyright 2016 Chris Lamb <lamby@debian.org>
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
package File::StripNondeterminism::handlers::javaproperties;

use strict;
use warnings;

use File::Temp;
use File::Basename;

sub is_java_properties_header {
	my ($contents) = @_;
	return $contents =~ /#Generated by( Apache)? Maven|#Build Number for ANT|#Generated by org.apache.felix.bundleplugin|#POM properties|#.* runtime configuration/;
}

sub is_java_properties_file {
	my ($filename) = @_;

	# If this is a java properties file, '#Generated by Maven', '#Build Number for ANT',
	# or other similar build-tool comment headers should appear in first 1kb
	my $fh;
	my $str;
	return open($fh, '<', $filename) && read($fh, $str, 1024)
		&& is_java_properties_header($str);
}

sub normalize {
	my ($filename) = @_;

	open(my $fh, '<', $filename) or die "Unable to open $filename for reading: $!";
	my $tempfile = File::Temp->new(DIR => dirname($filename));

	# Strip the generation date comment, which contains a timestamp.
	# It should appear within first 10 lines.
	while (defined(my $line = <$fh>) && $. <= 10) {
		# Yes, there really is no comma here
		if ($line =~ /^#\w{3} \w{3} \d{2} \d{2}:\d{2}:\d{2} \w{3,4}([+-]\d{2}:\d{2})? \d{4}\s*$/) {
			$line = '';
			print $tempfile $line;

			# Copy through rest of file
			my $bytes_read;
			my $buf;
			while ($bytes_read = read($fh, $buf, 4096)) {
				print $tempfile $buf;
			}
			defined($bytes_read) or die "$filename: read failed: $!";

			# Rename temporary file over the file
			chmod((stat($fh))[2] & 07777, $tempfile->filename);
			rename($tempfile->filename, $filename) or die "$filename: unable to overwrite: rename: $!";
			$tempfile->unlink_on_destroy(0);
			return 1;
		}
		print $tempfile $line;
	}

	return 0;
}

1;
