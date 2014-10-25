#
# Copyright 2014 Andrew Ayer
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
package File::StripNondeterminism::handlers::jar;

use strict;
use warnings;

use Archive::Zip;
use File::StripNondeterminism::handlers::zip;
use File::StripNondeterminism::handlers::javadoc;

sub _jar_filename_cmp ($$) {
	my ($a, $b) = @_;
	# META-INF/ and META-INF/MANIFEST.MF are expected to be the first entries in the Zip archive.
	return 0 if $a eq $b;
	for (qw{META-INF/ META-INF/MANIFEST.MF}) {
		return -1 if $a eq $_;
		return  1 if $b eq $_;
	}
	return $a cmp $b;
}

sub _jar_normalize_manifest {
	my ($filename) = @_;

	open(my $fh, '<', $filename) or die "Unable to open $filename for reading: $!";
	my $tempfile = File::Temp->new(DIR => dirname($filename));

	my $modified = 0;

	while (defined(my $line = <$fh>)) {
		# Bnd-LastModified contains a timestamp.
		# Built-By contains the system username.
		if ($line =~ /^(Bnd-LastModified|Built-By):/) {
			$modified = 1;
			next;
		}
		print $tempfile $line;
	}

	if ($modified) {
		# Rename temporary file over the file
		chmod((stat($fh))[2] & 07777, $tempfile->filename);
		rename($tempfile->filename, $filename) or die "$filename: unable to overwrite: rename: $!";
		$tempfile->unlink_on_destroy(0);
	}
	return $modified;
}

sub _jar_normalize_member {
	my ($member) = @_; # $member is a ref to an Archive::Zip::Member
	return if $member->isDirectory();

	if ($member->fileName() =~ /\.html$/ &&
			File::StripNondeterminism::handlers::zip::peek_member($member, 1024) =~ /\<!-- Generated by javadoc/) {
		# javadoc header should be within first 1kb of file
		File::StripNondeterminism::handlers::zip::normalize_member($member,
				\&File::StripNondeterminism::handlers::javadoc::normalize);
	} elsif ($member->fileName() eq 'META-INF/MANIFEST.MF') {
		File::StripNondeterminism::handlers::zip::normalize_member($member,
				\&_jar_normalize_manifest);
	}
}

sub normalize {
	my ($jar_filename) = @_;
	return File::StripNondeterminism::handlers::zip::normalize($jar_filename,
							filename_cmp => \&_jar_filename_cmp,
							member_normalizer => \&_jar_normalize_member);
}

1;
