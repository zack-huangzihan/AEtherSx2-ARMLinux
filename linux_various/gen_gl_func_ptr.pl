#!/usr/bin/perl
#
# PCSX2 - PS2 Emulator for PCs
# Copyright (C) 2019  PCSX2 Dev Team
#
# PCSX2 is free software: you can redistribute it and/or modify it under the terms
# of the GNU Lesser General Public License as published by the Free Software Found-
# ation, either version 3 of the License, or (at your option) any later version.
#
# PCSX2 is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
# PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with PCSX2.
# If not, see <http://www.gnu.org/licenses/>.

# Generate glfunction pointer for GS

use File::Basename;
use strict;
use warnings;

use Data::Dumper;

my $g_allowed_ext = "(GL_VERSION\|GL_ARB\|GL_KHR)";
my $g_fh_cpp;
my $g_fh_hpp;
my $g_fh_wnd;

sub to_PFN {
    my $f = shift;
    return "PFN" . uc($f) . "PROC";
}

sub header {
    my $y = `date +%Y`;
    chomp $y;
    if ($y ne "2019") {
        $y = "2019-$y";
    }
    my $str = <<EOS;
/*
 *  Copyright (C) $y PCSX2 Dev Team
 *
 *  This Program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2, or (at your option)
 *  any later version.
 *
 *  This Program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with GNU Make; see the file COPYING.  If not, write to
 *  the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA USA.
 *  http://www.gnu.org/copyleft/gpl.html
 *
 *  This file was generated by gen_gl_func_ptr.pl
 *
 */

EOS
    return $str;
}

sub open_file {
    my $filename = shift;
    open(my $fh, ">$filename") or die $!;
    print $fh header();
    return $fh;
}

sub print_all {
    my $str = shift;
    print $g_fh_cpp $str;
    print $g_fh_hpp $str;
    print $g_fh_wnd $str;
}

sub read_glext {
    my $gl_h = scalar(@ARGV) == 0 ? "/usr/include/GL/glcorearb.h" : $ARGV[0];
    open(my $gl, $gl_h) or die $!;

    my $db;
    my $ext;
    my $line;
    while ($line = <$gl>) {

        if ($line =~ /#ifndef\s+(.*)/) {
            $ext = $1;
            my @data;
            $db->{$ext} = \@data;
        }

        next unless ($ext =~ /$g_allowed_ext/);

        if ($line =~ /^GLAPI.*API\w*\s(gl[\w\d]*)[\s\(]/) {
            push(@{$db->{$ext}}, $1);
        }
    }

    # Trim empty extension
    foreach my $ext (sort(keys(%{$db}))) {
        my @funcs = @{$db->{$ext}};
        if (scalar (@funcs) == 0) {
            delete $db->{$ext};
        }
    }

    return $db;
}

######################################################################

my $glext = read_glext();

# Helper to enable only a part of GL
foreach my $ext (sort(keys(%{$glext}))) {
    print "// #define ENABLE_$ext 1\n";
}
print "\n";

$g_fh_cpp = open_file("PFN_GLLOADER_CPP.h");
$g_fh_hpp = open_file("PFN_GLLOADER_HPP.h");
$g_fh_wnd = open_file("PFN_WND.h");

foreach my $ext (sort(keys(%{$glext}))) {
    print_all "#if defined(ENABLE_$ext) && defined($ext)\n";
    foreach my $f (@{$glext->{$ext}}) {
        my $p = to_PFN($f);
        print $g_fh_cpp "$p $f = NULL;\n";
        print $g_fh_hpp "extern $p $f;\n";
        print $g_fh_wnd "GL_EXT_LOAD_OPT($f);\n";
    }
    print_all  "#endif\n";
}
