#!/bin/bash

# obviously outdated, need to be updated

set -e

Provision() {
    STP=/home/vagrant/.config/sublime-text-$SUBLIME_TEXT_VERSION/Packages

    if [ -z $(which subl) ]; then
        apt-get update
        apt-get install python-software-properties -y
        apt-get install git -y
        apt-get install zip -y
        apt-get install unzip -y
        apt-get install xvfb libgtk2.0-0 -y
        if [ $SUBLIME_TEXT_VERSION -eq 2 ]; then
            echo installing sublime 2
            add-apt-repository ppa:webupd8team/sublime-text-2 -y
            apt-get update
            apt-get install sublime-text -y
        elif [ $SUBLIME_TEXT_VERSION -eq 3 ]; then
            echo installing sublime 3
            add-apt-repository ppa:webupd8team/sublime-text-3 -y
            apt-get update
            apt-get install sublime-text-installer -y
        fi
    fi

    if [ ! -d $STP ]; then
        mkdir -p "$STP/User"
        # disable update check
        echo '{"update_check": false }' > "$STP/User/Preferences.sublime-settings"
    fi

    if [ ! -d $STP/$PACKAGE ]; then
        ln -s /vagrant $STP/$PACKAGE
    fi

    if [ ! -d $STP/DebugTools ]; then
        git clone https://github.com/evandrocoan/DebugTools $STP/DebugTools
    fi

    if [ ! -d $STP/UnitTesting ]; then
        git clone https://github.com/randy3k/UnitTesting $STP/UnitTesting
    fi

    SublimeTextInstalledPackagesDirectory="$STP/../Installed Packages"
    fullConsoleDebugToolsFullConsoleOutput="$STP/full_console"
    fullConsoleDebugToolsFullConsoleScript="$STP/../0_0full_console_output.py"
    fullConsoleDebugToolsFullConsoleZip="$SublimeTextInstalledPackagesDirectory/0_0full_console_output.zip"
    fullConsoleDebugToolsFullConsolePackage="$SublimeTextInstalledPackagesDirectory/0_0full_console_output.sublime-package"

    debugToolsConsoleScript="\
#! /usr/bin/env python
# -*- coding: utf-8 -*-
import os
import sys
import time
import threading

from DebugTools.all.debug_tools import getLogger
log = getLogger('full_console_output', file=r'$fullConsoleDebugToolsFullConsoleOutput', stdout=True)

print('')
log(1, 'Sublime Text has just started...')
log(1, 'Starting Capturing the Sublime Text Console...')
sys.stderr.write('Testing sys.stderr for %s\n' % r'$fullConsoleDebugToolsFullConsoleOutput')
sys.stdout.write('Testing sys.stdout for %s\n' % r'$fullConsoleDebugToolsFullConsoleOutput')

log(1, 'TESTING!')
log(1, 'TESTING! logfile to: %s', r'$fullConsoleDebugToolsFullConsoleOutput')
log(1, 'TESTING! logfile from: %s', os.path.abspath(__file__))

def time_passing():

    while(True):
        log(1, 'The time is passing...')
        time.sleep(1)

thread = threading.Thread( target=time_passing )
thread.start()
"

    mkdir -p "$SublimeTextInstalledPackagesDirectory"

    printf 'Start capturing all Sublime Text console with DebugTools: %s\n' "$fullConsoleDebugToolsFullConsoleScript"
    printf "%s\n" "$debugToolsConsoleScript" > "$fullConsoleDebugToolsFullConsoleScript"
    tail -100 "$fullConsoleDebugToolsFullConsoleScript"

    printf 'Create it as Packed file because they are loaded first by Sublime Text\n'
    zip -v -j "$fullConsoleDebugToolsFullConsoleZip" "$fullConsoleDebugToolsFullConsoleScript"

    printf 'Renaming the zip file to %s\n' "$fullConsoleDebugToolsFullConsolePackage"
    mv "$fullConsoleDebugToolsFullConsoleZip" "$fullConsoleDebugToolsFullConsolePackage"

    printf '\n'
    unzip -v "$fullConsoleDebugToolsFullConsolePackage"

    printf '\n'
    if [ ! -f /etc/init.d/xvfb ]; then
        echo installing xvfb controller
        wget -O /etc/init.d/xvfb https://gist.githubusercontent.com/randy3k/9337122/raw/xvfb
        chmod +x /etc/init.d/xvfb
    fi

    if [ -z $DISPLAY ]; then
        export DISPLAY=:1
    fi

    if [ $DISPLAY ]; then
        sh -e /etc/init.d/xvfb start
    fi

    if ! grep DISPLAY /etc/environment > /dev/null; then
        echo "DISPLAY=$DISPLAY" >> /etc/environment
    fi

    if ! grep SUBLIME_TEXT_VERSION /etc/environment > /dev/null; then
        echo "SUBLIME_TEXT_VERSION=$SUBLIME_TEXT_VERSION" >> /etc/environment
    fi

    if ! grep PACKAGE /etc/environment > /dev/null; then
        echo "PACKAGE=$PACKAGE" >> /etc/environment
    fi

    chown vagrant -R /home/vagrant/.config
}

RunTests() {
    STP=/home/vagrant/.config/sublime-text-$SUBLIME_TEXT_VERSION/Packages

    UT="$STP/UnitTesting"
    if [ -z "$1" ]; then
        python "$UT/sbin/run.py" "$PACKAGE"
    else
        python "$UT/sbin/run.py" "$1" "$PACKAGE"
    fi
    killall sublime_text
}


COMMAND=$1
echo "Running command: ${COMMAND}"
shift
case $COMMAND in
    "provision")
        Provision
        ;;
    "run_tests")
        RunTests "$@"
        ;;
esac
