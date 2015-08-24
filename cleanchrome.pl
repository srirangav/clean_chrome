#!/usr/bin/perl -wT
#
# cleanchrome.pl - delete old versions of Chrome on MacOS X
# $Id: cleanchrome.pl 1199 2012-04-02 05:17:43Z ranga $
#
# History:
#
# v. 0.1.4 (01/20/2012) - Initial Release
# v. 0.1.5 (03/22/2012) - Add option for listing old versions
#
# Related links:
#
# http://shanegowland.com/software/2012/oldchromeremover-module/
# http://macdevcenter.com/pub/a/mac/2005/07/29/plist.html?page=all
#
# Copyright (c) 2012 Sriranga R. Veeraraghavan <ranga@calalum.org>
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# TODO:
#
# 1. Add support for Chromium
# 2. Use the spotlight db to find the Chrome install directory if
#    Chrome isn't found in /Applications
#

require 5.006_001;

use strict;
use Getopt::Std;
use File::chdir;
use File::Path 'remove_tree';
use Foundation;

#
# main
#

# secure the environment

$ENV{'PATH'} = '/bin:/usr/bin';
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};

# global variables

my $EC = 0;
my %OPTS = ();
my $VERBOSE = 0;
my $FORCE = 0;
my $LIST = 0;
my $CHROME_INST_DIR = "";
my $CHROME_DEF_INST_DIR = "/Applications";
my $CHROME_CONTENTS = "Google Chrome.app/Contents";
my $CHROME_PLISTF = "Info.plist";
my $CHROME_VERS = "";
my $CHROME_VERS_KEY = "KSVersion";
my $CHROME_VERS_DIR = "Versions";
my @OLDVERS = ();

#
# begin main
#

# parse the command line options:
#   -d - alternative install directory for Chrome
#   -f - force deletion of old Chrome versions
#   -l - list old Chrome versions
#   -n - list old Chrome versions
#   -v - verbose (debug) mode
#   -h - help (prints usage message)

getopts("d:fvhln?", \%OPTS);

# if help mode is requested, print the usage message and exit

if (defined($OPTS{'h'}) || defined($OPTS{'?'})) {
    printUsage();
    exit(0);
}

# check if verbose mode is requested

$VERBOSE = (defined($OPTS{'v'}) ? 1 : 0);

# check if list mode is requested

$LIST = (defined($OPTS{'l'}) || defined($OPTS{'n'}) ? 1 : 0);

# check if force mode (auto delete old versions) is requested

$FORCE = (defined($OPTS{'f'}) ? 1 : 0);

# check if a valid chrome install directory is specified

$CHROME_INST_DIR =
    (defined($OPTS{'d'}) ? $OPTS{'d'} : $CHROME_DEF_INST_DIR);
chomp($CHROME_INST_DIR);

if (isChromeInstalled($CHROME_INST_DIR, $CHROME_CONTENTS) != 1) {
    printError("Chrome not found in: " .
                "'$CHROME_INST_DIR', Exiting.");
    exit(1);
}

$CHROME_VERS =
    getChromeVers("$CHROME_INST_DIR/$CHROME_CONTENTS/$CHROME_PLISTF",
                  $CHROME_VERS_KEY);

if (!defined($CHROME_VERS) || $CHROME_VERS eq "") {
    printError("Cannot determine Chrome version, Exiting.");
    exit(1);
}

@OLDVERS =
    findOldChromeVers("$CHROME_INST_DIR/$CHROME_CONTENTS/$CHROME_VERS_DIR",
                      $CHROME_VERS);

if (scalar(@OLDVERS) >= 1) {

    if ($LIST == 1) {
        printOldChromeVers(@OLDVERS);
    } elsif (deleteOldChromeVers($FORCE,
            "$CHROME_INST_DIR/$CHROME_CONTENTS/$CHROME_VERS_DIR",
            @OLDVERS) < 0) {
        $EC = 1;
    }

}

exit($EC);

#
# end main
#

#
# subroutines
#

#
# isChromeInstalled - returns 1 if Chrome is installed in the specified
#                     directory
#

sub isChromeInstalled
{
    my $inst_dir = "";
    my $contents_dir = "";

    $inst_dir = shift @_;
    if (!defined($inst_dir) || $inst_dir eq "") {
        return 0;
    }

    $contents_dir = shift @_;
    if (!defined($contents_dir) || $contents_dir eq "") {
        return 0;
    }

    return (-d $inst_dir && -d "$inst_dir/$contents_dir" ? 1 : 0);
}

#
# getChromeVers - returns the current installed version for Chrome
#

sub getChromeVers
{
    my $plistf = "";
    my $plist_dict = "";
    my $vers = "";
    my $vers_obj = "";
    my $vers_key = "";

    $plistf = shift @_;

    if (!defined($plistf) || ! -r $plistf) {
        printError("Cannot read plist file: '$plistf'");
        return $vers;
    }

    $vers_key = shift @_;
    if (!defined($vers_key) || $vers_key eq "") {
        printError("Invalid version key");
        return $vers;
    }

    $plist_dict =  NSDictionary->dictionaryWithContentsOfFile_($plistf);
    if (!defined($plist_dict) || !defined($$plist_dict)) {
        printError("Cannot read plist file: '$plistf'");
        return $vers;
    }

    $vers_obj = $plist_dict->objectForKey_($vers_key);
    if (defined($vers_obj)) {
        $vers = $vers_obj->description()->UTF8String();
        if (defined($vers)) {
            chomp($vers);
        }
    }

    printInfo("getChromeVers: version '$vers' installed.");

    return $vers;
}

#
# findOldChromeVers - returns an array of directories containing old
#                     Chrome version
#

sub findOldChromeVers
{
    my @versions = ();
    my $dir_entry = "";
    my $vers_dir = "";
    my $vers = "";

    $vers_dir = shift @_;
    $vers = shift @_;

    if (!defined($vers_dir) || ! -d $vers_dir) {
        printError("Invalid Chrome version directory: '$vers_dir'");
        return @versions;
    }

    if (!defined($vers) || $vers !~ /^[0-9]+\.[0-9\.]*[0-9]$/) {
        printError("Invalid installed Chrome version: '$vers'");
        return @versions;
    }

    if (!opendir(VDH, "$vers_dir")) {
        printError("Cannot read Chrome version directory: '$vers_dir'");
        return @versions;
    }

    while($dir_entry = readdir(VDH)) {
        if ($dir_entry =~ /^[0-9]+\.[0-9\.]*[0-9]$/ &&
            $dir_entry ne $vers) {
            chomp($dir_entry);
            push(@versions, $dir_entry);
        }
    }

    closedir(VDH);

    printInfo("findOldChromeVers: found versions: @versions");

    return @versions;
}

#
# printOldChromeVers - print out a list of old versions of Chrome
#

sub printOldChromeVers
{
    my $vers = "";

    if (scalar(@_) >= 1) {
        print "The following old versions of Chrome were found:\n";
        foreach $vers (@_) {
            print "\t$vers\n";
        }
    }
}

#
# deleteOldChromeVers - deletes old versions of Chrome
#

sub deleteOldChromeVers
{
    my $force = 0;
    my $vers_dir = "";
    my $dir = "";
    my $err = "";
    my $rc = 0;

    $force = shift @_;
    $force = (defined($force) && $force+0 == 1 ? 1 : 0);

    $vers_dir = shift @_;
    if (!defined($vers_dir) || ! -d ($vers_dir)) {
        printError("Invalid Chrome version directory: '$vers_dir'");
        return -1;
    }

    if (scalar(@_) >= 1) {

        local $CWD = $vers_dir;

        foreach $dir (@_) {

            if (! -d "$vers_dir/$dir") {
                next;
            }

            if ($dir =~ /^([0-9]+\.[0-9\.]+)$/) {
                $dir = $1;
            } else {
                next;
            }

            if ($force != 1 &&
                readYesNo("Delete Chrome version '$dir'") ne "Y") {
                printInfo("deleteOldChromeVers: skipping '$dir'");
                next;
            }

            printInfo("deleteOldChromeVers: deleting version: '$dir'");

            remove_tree($dir, {error => \my $err});
            if (@$err) {
                $rc = -1;
            }
        }
    }

    return $rc;
}

#
# readYesNo - reads a yes or no response to a specified question
#

sub readYesNo
{
    my $prompt = shift @_;
    my $response = "";

    if (!defined($prompt)) {
        $prompt = "";
    }

    print "$prompt" . "? [Y/N] ";
    $response = <STDIN>;

    if (defined($response)) {
        chomp($response);
        if ($response =~ /^[Yy][Ee][Ss]$|^[Yy]$/) {
            return "Y";
        }
    }

    return "N";
}

#
# printError - print an error message
#

sub printError
{
    print STDERR "ERROR: @_\n";
}

#
# printInfo - print an informational message
#

sub printInfo
{
    if ($VERBOSE != 0) { print "INFO: @_\n"; }
}

#
# printUsage - prints the usage statement
#

sub printUsage
{
    my $pgm = $0;
    $pgm =~ s/^.*\///;
    print "usage: $pgm [-lvf] [-d dir]\n";
    print "         -v - enable verbose / debug mode\n";
    print "         -f - force deletion of old versions\n";
    print "         -d - alternate install directory " .
          "(default $CHROME_DEF_INST_DIR)\n";
    print "         -l - list old version\n";
}

