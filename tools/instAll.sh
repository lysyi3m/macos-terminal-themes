#!/bin/bash

install_scheme () {
    # Parse the xml contained in the terminal profile, for preference data.
    # Add the profile to the Terminal plist.
    # Window Settings is a dictionary of installed terminal profiles.
    XML=$(xmllint --xpath '/plist/dict' "$1")
    NAME=$(echo $1 | awk '{split($0,a,"../schemes/"); print a[2]}'| sed -e 's/(//g' | sed -e 's/)//g' | cut -d'.' -f1)
    defaults write com.apple.Terminal "Window Settings" -dict-add "$NAME" "$XML"
}


#loop through schemes
for scheme in ../schemes/*.terminal;
do    
    install_scheme "$scheme"
done
