#!/bin/bash

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
                sed -i '' ''"$lineNum"'s/[0-9]/0/g' $filename;
            fi
        fi
    done
}

install_scheme () {
    #open terminal with scheme loaded and close its corresponding window.

    #open file at first argument
    open -F -n $1;
    pkill -n Terminal;
    #TODO: close file that was opened 
}

#set_exit_action

#call only one file for testing
install_scheme ../schemes/Alucard.terminal

#TODO: un-comment when test works^
#for scheme in ../schemes/*.terminal;
#do
#    install_scheme $scheme &
#done
