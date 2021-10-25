#!/bin/bash

# This script should be CI agnostic

set -e

SUBLIME_TEXT_VERSION=${SUBLIME_TEXT_VERSION:-4}
SUBLIME_TEXT_ARCH=${SUBLIME_TEXT_ARCH:-x64}

FULL_CONSOLE_PATH="$STP/full_console"

if [ $SUBLIME_TEXT_VERSION -ge 4 ]; then
    if [ $(uname) = 'Darwin' ]; then
        STP="$HOME/Library/Application Support/Sublime Text/Packages"
    else
        STP="$HOME/.config/sublime-text/Packages"
    fi
else
    if [ $(uname) = 'Darwin' ]; then
        STP="$HOME/Library/Application Support/Sublime Text $SUBLIME_TEXT_VERSION/Packages"
    else
        STP="$HOME/.config/sublime-text-$SUBLIME_TEXT_VERSION/Packages"
    fi
fi

Bootstrap() {
    local SkipPackageCopy="$1"

    # Disable warnings about detached HEAD
    # https://stackoverflow.com/questions/36794501
    git config --global advice.detachedHead false

    # Copy plugin files to Packages/<Package> folder.
    if [ -z "$SkipPackageCopy" ]; then
        CopyTestedPackage
    fi

    DEBUG_TOOLS_PATH="$STP/debugtools"
    if [ ! -d "$DEBUG_TOOLS_PATH" ]; then

        if [ -z $DEBUG_TOOLS_URL ]; then
            DEBUG_TOOLS_URL="https://github.com/evandrocoan/debugtools"
        fi

        if [ ! -z $DEBUG_TOOLS_TAG ]; then
            DEBUG_TOOLS_TAG="--branch $DEBUG_TOOLS_TAG"
        fi

        echo "download debugtools tag: $DEBUG_TOOLS_TAG, $DEBUG_TOOLS_URL $DEBUG_TOOLS_PATH"
        git clone --depth 1 $DEBUG_TOOLS_TAG "$DEBUG_TOOLS_URL" "$DEBUG_TOOLS_PATH"
        git -C "$DEBUG_TOOLS_PATH" rev-parse HEAD
        echo
    fi

    local UT_NAME="UnitTesting"
    local UT_PATH="$STP/$UT_NAME"
    if [ ! -d "$UT_PATH" ]; then
        if [ ! -z $UNITTESTING_TAG ]; then
            UNITTESTING_TAG="--branch $UNITTESTING_TAG"
        fi
        InstallPackage "$UT_NAME" "$UNITTESTING_TAG" "https://github.com/evandrocoan/UnitTesting"
    fi

    InstallPackage "coverage" "$COVERAGE_TAG" "https://github.com/codexns/sublime-coverage"

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

from debugtools.all.debug_tools import getLogger
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

    printf 'Start capturing all Sublime Text console with debugtools: %s\n' "$fullConsoleDebugToolsFullConsolePackage"
    printf "%s\n" "$debugToolsConsoleScript" > "$fullConsoleDebugToolsFullConsoleScript"
    tail -100 "$fullConsoleDebugToolsFullConsoleScript"

    printf 'Create it as Packed file because they are loaded first by Sublime Text\n'
    zip -v -j "$fullConsoleDebugToolsFullConsoleZip" "$fullConsoleDebugToolsFullConsoleScript"

    printf 'Renaming the zip file to %s\n' "$fullConsoleDebugToolsFullConsolePackage"
    mv "$fullConsoleDebugToolsFullConsoleZip" "$fullConsoleDebugToolsFullConsolePackage"

    printf '\n'
    unzip -v "$fullConsoleDebugToolsFullConsolePackage"

    printf '\n'

    InstallSublimeText

    if [ -n "$CI" ] && [ $SUBLIME_TEXT_VERSION -le 3 ]; then
        # block update popup
        if [ $(uname) = 'Darwin' ]; then
            sudo route -n add -host 45.55.41.223 127.0.0.1
        else
            sudo apt install -y net-tools
            sudo route add -host 45.55.41.223 reject || echo "See https://github.com/SublimeText/UnitTesting/issues/190#issuecomment-850133753"
        fi
    fi
}

gitGetHeadRevisionName() {
    git -C "$1" rev-parse HEAD
}

getLatestUnitTestingBuildTag() {
    local PreferredTag="$1"
    local SUBLIME_TEXT_VERSION="$2"
    local UrlToUnitTesting="$3"
    if [ -z "$PreferredTag" ]; then
        if [ $SUBLIME_TEXT_VERSION -eq 2 ]; then
            local TAG="0.10.6"
        else
            local TAG=$(gitFetchLatestTagFromRepository "$UrlToUnitTesting")
        fi
    else
        local TAG="$PreferredTag"
    fi
    echo "$TAG"
}

gitCloneTag() {
    local TAG="$1"
    local URL="$2"
    local DEST="$3"
    git clone --quiet --depth 1 --branch "$TAG" "$URL" "$DEST"
}

gitFetchLatestTagFromRepository() {
    local URL="$1"
    local LSTAGS
    LSTAGS=`git ls-remote --tags "$URL"`
    local TAG=$(echo "$LSTAGS" | grep -E '/v?[0-9]+\.[0-9]+\.[0-9]+$' |
      sed -E 's|.*/v?([^/]*)$|\1|' |
      sort -t. -k1,1nr -k2,2nr -k3,3nr | head -n1)
    echo "$LSTAGS" | grep -F "$TAG" | sed -E 's|.*/([^/]*)$|\1|' | grep -v '\^' | head -n1
}

getRepositoryTag() {
    local PreferredTag="$1"
    local URL="$2"
    if [ -z "$PreferredTag" ]; then
        local TAG=$(gitFetchLatestTagFromRepository "$URL")
    else
        local TAG="$PreferredTag"
    fi
    echo "$TAG"
}

cloneRepositoryTag() {
    local PreferredTag="$1"
    local URL="$2"
    local DEST="$3"
    local TAG=$(getRepositoryTag "$PreferredTag" "$URL")
    echo "cloning $URL tag: $TAG into $DEST..."
    gitCloneTag "$TAG" "$URL" "$DEST"
    gitGetHeadRevisionName "$DEST"
}

CopyTestedPackage() {
    local OverwriteExisting="$1"
    if [ -d "$STP/$PACKAGE" ] && [ -n "$OverwriteExisting" ]; then
        rm -rf "${STP:?}/${PACKAGE:?}"
    fi
    if [ ! -d "$STP/$PACKAGE" ]; then
        # symlink does not play well with coverage
        echo "copy the package to sublime package directory"
        mkdir -p "$STP/$PACKAGE"
        cp -r ./ "$STP/$PACKAGE"
    fi
}

InstallPackage() {
    local DEST="$STP/$1"
    local PreferredTag="$2"
    local URL="$3"
    if [ ! -d "$DEST" ]; then
        mkdir -p "$DEST"
        cloneRepositoryTag "$PreferredTag" "$URL" "$DEST"
    fi
}

InstallColorSchemeUnit() {
    local CSU_URL="https://github.com/gerardroche/sublime-color-scheme-unit"
    if [ "$SUBLIME_TEXT_VERSION" -ge 3 ]; then
        InstallPackage "ColorSchemeUnit" "$COLOR_SCHEME_UNIT_TAG" "$CSU_URL"
    fi
}

InstallKeypress() {
    local KP_URL="https://github.com/randy3k/Keypress"
    if [ "$SUBLIME_TEXT_VERSION" -ge 3 ]; then
        InstallPackage "Keypress" "$KEYPRESS_TAG" "$KP_URL"
    fi
}

InstallSublimeText() {
    sh "$STP/UnitTesting/sbin/install_sublime_text.sh" "--st" "$SUBLIME_TEXT_VERSION"
}

InstallPackageControl() {
    COV_PATH="$STP/coverage"
    rm -rf "$COV_PATH"

    sh "$STP/UnitTesting/sbin/install_package_control.sh" "--st" "$SUBLIME_TEXT_VERSION"
}

CloneGitPackage() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "ERROR: You must provide an valid git URL $1 and package name $2"
    fi

    git_url=$1
    package_name=$2
    package_full_path="$STP/$package_name"

    if [ -d "$package_full_path" ]; then
        echo "ERROR: The directory $package_full_path already exists!"

    else
        echo "download package $package_name: $git_url $package_full_path"
        git clone --depth 1 "$git_url" "$package_full_path"
        echo
    fi
}

ShowFullSublimeTextConsole() {
    printf "\n"
    printf "\n"

    if [ -f "$FULL_CONSOLE_PATH" ]; then
        printf "Full Sublime Text Console output...\n"
        printf "%s\n" "$(<$FULL_CONSOLE_PATH)"

    else
        printf "Log file not found on: %s\n" $FULL_CONSOLE_PATH
    fi

    exit 1
}

RunTests() {
    # if [ -n "$(echo "$@" | grep -e '--coverage\b')" ] && [ "$SUBLIME_TEXT_VERSION" -eq 4 ]; then
    #     echo "Coverage is not yet supported in Sublime Text 4"
    #     exit 1
    # fi
    if [ -z "$1" ]; then
        python "$STP/UnitTesting/sbin/run_tests.py" "$PACKAGE"
    else
        python "$STP/UnitTesting/sbin/run_tests.py" "$@" "$PACKAGE"
    fi

    pkill "[Ss]ubl" || true
    pkill 'plugin_host' || true
    sleep 1
}


COMMAND=$1
shift
echo "Running command: ${COMMAND} $@"
case $COMMAND in
    "bootstrap")
        Bootstrap "$@" || ShowFullSublimeTextConsole
        ;;
    "copy_tested_package")
        CopyTestedPackage "$@" || ShowFullSublimeTextConsole
        ;;
    "install_package")
        InstallPackage "$@" || ShowFullSublimeTextConsole
        ;;
    "install_package_control")
        InstallPackageControl "$@" || ShowFullSublimeTextConsole
        ;;
    "install_color_scheme_unit")
        InstallColorSchemeUnit "$@" || ShowFullSublimeTextConsole
        ;;
    "install_keypress")
        InstallKeypress "$@" || ShowFullSublimeTextConsole
        ;;
    "run_tests")
        RunTests "$@" || ShowFullSublimeTextConsole
        ;;
    "run_syntax_tests")
        RunTests "--syntax-test" "$@" || ShowFullSublimeTextConsole
        ;;
    "run_syntax_compatibility")
        RunTests "--syntax-compatibility" "$@" || ShowFullSublimeTextConsole
        ;;
    "run_color_scheme_tests")
        RunTests "--color-scheme-test" "$@" || ShowFullSublimeTextConsole
        ;;
    "clone_git_package")
        CloneGitPackage "$@" || ShowFullSublimeTextConsole
        ;;
    "show_full_sublime_text_console")
        ShowFullSublimeTextConsole "$@"
        ;;
esac
