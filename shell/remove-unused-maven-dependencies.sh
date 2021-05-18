#!/bin/bash 

# +21600 is the duration since the file was Read, in minutes (here is it 15 days)
find ./.m2/some-repo-to-clean -amin +21600 -iname '*.pom' | while read pom; do parent=`dirname "$pom"`; rm -Rf "$parent"; done
