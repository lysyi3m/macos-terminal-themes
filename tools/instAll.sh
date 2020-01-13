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
    #open terminal with scheme loaded and close its corresponding window.

    #open file at first argument
    open -n -g "$1" && echo "$1" && sleep 2  && pkill -n Terminal;
}

#this might not even be needed
set_exit_action

#bug in this loop/install_scheme function: not all are installed
for scheme in ../schemes/*.terminal;
do
    install_scheme "$scheme"
done
