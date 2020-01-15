#!/bin/bash

# set exit action to 0 so that the terminal window/tab closes on ctrl+d/exit/logout
# Then open and close every tab

set_exit_action () {
    #set schemes so windows close when ctrl+d/exit/logout is sent
    for filename in ../schemes/*.terminal;
    do
        line=$(cat "$filename"| grep -n --context=1 'shellExitAction' | tail -2| grep "<integer>")
        if [ -z "$line" ]
        then
            #add shellExitAction to close window when exiting shell
            perl -i -p0e 's/<\/dict>\n<\/plist>/\t<key>shellExitAction<\/key>\n\t<integer>0<\/integer>\n<\/dict>\n<\/plist>/g' "$filename"
        else
            #set shellExitAction for those that already have it
            replace=$(echo "$line" | grep '<integer>0');
            if [ -z "$replace" ]
            then
                lineNum=$(echo "$line" | grep -Eo '^[0-9]*');
                sed -i '' ''"$lineNum"'s/[0-9]/0/g' "$filename";
            fi
        fi
    done
}


install_scheme () {
    # Does not work with the profile: Monokai Pro (Filter Spectrum).terminal because of the parentheses.
    # Parse the xml contained in the terminal profile, for preference data.
    # Add the profile to the Terminal plist.
    # Window Settings is a dictionary of installed terminal profiles. 
    XML=$(xmllint --xpath '/plist/dict' "$1")
    NAME=$(echo $1 | awk '{split($0,a,"../schemes/"); print a[2]}'| sed -e 's/(//g' | sed -e 's/)//g' | cut -d'.' -f1)
    defaults write com.apple.Terminal "Window Settings" -dict-add "$NAME" "$XML"
}

#uncomment the line below to set the exit action as "close window"
#set_exit_action

#bug in this loop/install_scheme function: not all are installed
for scheme in ../schemes/*.terminal;
do
    install_scheme "$scheme"
done
