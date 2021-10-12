#! /bin/env perl
#

use Getopt::Long qw(:config no_ignore_case :config bundling);
sub usage {
print <<EOF ;
#------------------------------------------------------------------------------
#
#                   gitstp.pl : set timestamp of files at their first commit time
#                   -------------------------------------------------------------
#
#      MIT License
#
#           Copyright (c) 2021 Arnaud Bertrand
#
#           Permission is hereby granted, free of charge, to any person obtaining a copy
#           of this software and associated documentation files (the "Software"), to deal
#           in the Software without restriction, including without limitation the rights
#           to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#           copies of the Software, and to permit persons to whom the Software is
#           furnished to do so, subject to the following conditions:
#
#           The above copyright notice and this permission notice shall be included in all
#           copies or substantial portions of the Software.
#
#           THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#           IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#           FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#           AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#           LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#           OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#           SOFTWARE.
#
#
#
#
#      Description: gitstp.pl : set timestamp of files at their first commit time
#
#      Usage:     gitstp.pl [-h] [-d] [-f|F] [-D [-q] [-R] [-t filepath]
#
#           --directory, -d       : perform changetime of directory (by default
#                                   the directory timestamps are not modified)
#           --files, -f           : perform changetime of files based on the index
#                                   (by default, file timestamps are not modified)
#           --files-hash, -F      : perform changetime of files based on all git files
#                                   it is more time consuming because for files not present
#                                   in index, git-hash must be calculated
#                                   (by default, file timestamps are not modified)
#           --debug, -D           : add debugging information
#           --gentouch, -g        : generate a shell scripts to touch the file to stdout
#           --quiet,q             : do not show progress
#           --rebuild, -R         : rebuild of tstp cache (normally never necessary)
#           --tstpfile, -t path   : define the path of tstpfile (by default GIRDIR/gittstp)
#
#     Examples:
#              gitstp.pl -fd
#------------------------------------------------------------------------------
EOF
exit;
} #end sun usage
use strict;

my $flDebug=0;
my $flDir=0;
my $flFiles=0;
my $flHash=0;
my $flRebuild=0;
my $flTouch=0;
my $flQuiet=0;
my $TstpFile="";
GetOptions("directory|d",\$flDir,
           "debug|D",\$flDebug,
           "files|f",\$flFiles,
           "files-hash|F",\$flHash,
           "rebuild|R",\$flRebuild,
           "gentouch|g",\$flTouch,
           "tstpfile|t=s",\$TstpFile,
           "quiet|q",\$flQuiet,
           "help|h", \&usage) or usage;
my %tstp=();
my $gitdir=`git rev-parse --git-common-dir` ;
$gitdir =~ s/[\r\n]//g;
my $toplevel = `git rev-parse --show-toplevel`;
$toplevel =~ s/[\r\n]//g;
my $flupdate =0; # flag of new commit (not in git stsp cache)
my @cl=(); # the commit list
$TstpFile = "$gitdir/gittstp" unless $TstpFile;
 
not($flRebuild) && open(T, $TstpFile) && do {
    print STDERR "Reading existing tstpfile\n" unless $flQuiet;
    while(<T>) {
       s/[\r\n]+//g;
       my ($h,$t1,$t2) = split;
       $tstp{$h}="$t1 $t2";
    }
    close (T);
};

my %dc=(); 
   print STDERR "Listing all commits\n" unless $flQuiet;
open(C, 'cd "'.$gitdir.'/.."; git log --all --date-order --oneline --pretty="format:%H %cI %ct" |') || die $!;

    while(<C>) {
       s/[\r\n]+//g;
       my ($c,$t1,$t2) = split;
       my $t="$t1 $t2";
       push(@cl, $c);
       $dc{$c} = $t;
    }
    close(C);
    print "Update/build the tstp file\n" unless $flQuiet;
    my $i=0;
    for my $c (sort { $dc{$a} cmp $dc{$b} } @cl) {
        $i++;
       print STDERR int(.5 + ($i / @cl)*1000)/10 . " %             \r" unless $flQuiet;
       my $t=$dc{$c};
       next if $tstp{$c};
       $flupdate  = 1;
       $tstp{$c}=$t;
       print STDERR "\nProcess comit $c $t\n" if $flDebug;
       open(T, "git ls-tree -r $c |") && do {
          while(<T>) {
             my $tree = substr($_,12, 40);
             $tstp{$tree}=$t if (not(defined($tstp{$tree}))) or ($t lt $tstp{$tree}) ;
          }
       }
    }
    if ($flupdate) {
        print STDERR "save the new tstp file: $TstpFile\n" unless $flQuiet;
        open(O,"> $TstpFile");
        for my $k (keys(%tstp)) {
            print O "$k $tstp{$k}\n";
        }
        close(O);
    }

my %donttouch=();
open(M,'cd "' . $toplevel . '"; git ls-files --modified |') || die $!;
while(<M>) {
    s/[\r\n]+//g;
    $donttouch{$_}=1;       
}
my %filetoprocess = ();
open(I,'cd "' . $toplevel . '"; git ls-files -s |') || die $!;

while(<I>) {
    s/[\r\n]+//g;
    my ($h,$p) = ($1,$2) if /^\S+\s+(\S+)\s+\S+\s+(.+)$/;
    next if $donttouch{$p} or not(defined($tstp{$h} ));
    $filetoprocess{$p}=$h;
}
close(I);

if ($flHash) {
    print STDERR "Processing the object hashes\n";
    my @files = map {s|$toplevel/||;$_;} dirlist($toplevel);
    for my $f (@files) {
        next if $filetoprocess{$f};
        my $hid = `git hash-object "$toplevel/$f"`;
        $hid = substr($hid,0,40);
        print STDERR "   Hash $hid : $f\n" if $flDebug;
        $filetoprocess{$f} = $hid if $tstp{$hid};
    }
}


print STDERR "Setting timestamp of files\n" unless not($flFiles) or $flQuiet;

for my $p (sort(keys(%filetoprocess))) {
    my $h = $filetoprocess{$p};
    print STDERR "Set Time " . $tstp{$h} . " to file $p \n" if $flDebug;
    print "touch -d '".substr($tstp{$h},0,25)."' \"$toplevel/$p\"\n" if $flTouch;
    my $maxtime=0+substr($tstp{$h},26);
    utime($maxtime, $maxtime, "$toplevel/$p") if $flFiles;
    
}
my @files = map {s|$toplevel/||;$_;} dirlist($toplevel);
if ($flDir) {
    print STDERR "Setting timestamp of directories\n" unless $flQuiet;
    settstpdir($toplevel) ;
}


sub settstpdir($) {
    my ($path) = @_;
    return 0 if not(-d "$path");
    my $maxtime=0;
    my $dir;
    opendir($dir,"$path") || die $!;
    while(my $f=readdir($dir)){
        my $t;
        next if $f eq "..";
        next if $f eq ".";
        if ( -d "$path/$f"){
            $t =settstpdir("$path/$f");
        }
        else {
            $t = (stat("$path/$f"))[9] ;
        }
        $maxtime = $t if $t>$maxtime;
    }
    close($dir);
    print STDERR "Setting directory time: $maxtime $path\n" if $flDebug and $maxtime;
    utime($maxtime, $maxtime, $path) if $maxtime;
    return $maxtime;
}
sub dirlist($) {
    my ($path) = @_;
    my @files;
    my $dir;
    opendir($dir,$path) || die $!;
    while(my $f=readdir($dir)) {
        next if($f eq "" || $f eq '.' || $f eq '..' || $f eq '.git');
        if ( -d "$path/$f" ) {
            push(@files, dirlist("$path/$f"));
        }
        else {
            push(@files, "$path/$f");
        }
    }
    return @files;
}
