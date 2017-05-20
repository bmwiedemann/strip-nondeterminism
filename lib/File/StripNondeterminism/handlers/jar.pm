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

use File::StripNondeterminism::Common qw(copy_data);
use Archive::Zip;
use File::Basename;
use File::StripNondeterminism::handlers::zip;
use File::StripNondeterminism::handlers::javadoc;
use File::StripNondeterminism::handlers::javaproperties;

sub _jar_filename_cmp($$) {
	my ($a, $b) = @_;
	# META-INF/ and META-INF/MANIFEST.MF are expected to be the first
	# entries in the Zip archive.
	return 0 if $a eq $b;
	for (qw{META-INF/ META-INF/MANIFEST.MF}) {
		return -1 if $a eq $_;
		return  1 if $b eq $_;
	}
	return $a cmp $b;
}

sub _jar_normalize_manifest($) {
	my ($filename) = @_;

	open(my $fh, '<', $filename)
	  or die "Unable to open $filename for reading: $!";
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
		$tempfile->close;
		copy_data($tempfile->filename, $filename)
		  or die "$filename: unable to overwrite: copy_data: $!";
	}
	return $modified;
}

sub _jar_normalize_member($) {
	my ($member) = @_; # $member is a ref to an Archive::Zip::Member
	return if $member->isDirectory();

	if ($member->fileName() =~ /\.html$/
		&&File::StripNondeterminism::handlers::zip::peek_member($member, 1024)
		=~ /\<!-- Generated by javadoc/) {
		# javadoc header should be within first 1kb of file
		File::StripNondeterminism::handlers::zip::normalize_member($member,
			\&File::StripNondeterminism::handlers::javadoc::normalize);
	} elsif ($member->fileName() eq 'META-INF/MANIFEST.MF') {
		File::StripNondeterminism::handlers::zip::normalize_member($member,
			\&_jar_normalize_manifest);
	} elsif (
		$member->fileName() =~ /(pom|version)\.properties$/
		&&File::StripNondeterminism::handlers::javaproperties::is_java_properties_header(
			File::StripNondeterminism::handlers::zip::peek_member(
				$member, 1024
			))
	  ) {
		# maven header should be within first 1kb of file
		File::StripNondeterminism::handlers::zip::normalize_member($member,
			\&File::StripNondeterminism::handlers::javaproperties::normalize);
	} elsif ($member->fileName() =~ /\.jar$/) {
		File::StripNondeterminism::handlers::zip::normalize_member($member,
			\&normalize);
	}

	return 1;
}

sub _jar_archive_filter($) {
	my ($zip) = @_;

	# Don't normalize signed JARs, since our modifications will break the
	# signature.  Alternatively, we could strip the signature.  However, if
	# a JAR file is signed, it is highly likely that the JAR file was part
	# of the source and not produced as part of the build, and therefore
	# contains no nondeterminism.  Thus, ignoring the file makes more
	# sense.
	#
	# According to the jarsigner(1) man page, a signed JAR has a .SF file
	# in the META-INF directory.
	#
	if (scalar($zip->membersMatching('^META-INF/.*\.SF$')) > 0) {
		warn "strip-nondeterminism: "
		  . $zip->fileName()
		  . ": ignoring signed JAR file\n";
		return 0;
	}

	return 1;
}

sub normalize {
	my ($jar_filename) = @_;
	return File::StripNondeterminism::handlers::zip::normalize(
		$jar_filename,
		archive_filter => \&_jar_archive_filter,
		filename_cmp => \&_jar_filename_cmp,
		member_normalizer => \&_jar_normalize_member
	);
}

1;
