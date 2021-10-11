# gitstp
set timestamp of files and directory according to commit timestamp

It is a simple perl script that will
1. Read the .git/gittstp file if it exist
2. parse all the commit and create/update the
   gittstp file in the .git directory
this file contains all early timestamp og each git objects. The early timestamp
is defined as the timestamp of the first commit that contains this object.
3. It will then update the modified time of the files and directories
   according to the options used.
   with -f : based on the index only (the timestamp of modified file compared to the index
   are of course not changed... except if it is an known version and the -F option is used.
   with -F : the script will calculate all the hash id of the objects in the repository and
   compare it to the gittstp "database". It allows the script to match an old version
4. It will update the directory timestamp if -d option is used.

