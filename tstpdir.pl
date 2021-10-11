#!/usr/bin/env perl
#

for my $arg (@ARGV) {
    settstpdir($arg);
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
            # print stderr "DIRECTORY: path/$f\n";
            $t =settstpdir("$path/$f");
        }
        else {
            $t = (stat("$path/$f"))[9] ;
            # print stderr "FILE: path/$f\n";
        }
        $maxtime = $t if $t>$maxtime;
    }
    close($dir);
    print stderr "Setting directory time: $maxtime $path\n";
    utime($maxtime, $maxtime, $path);
    return $maxtime;
}
