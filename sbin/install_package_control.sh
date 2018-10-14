#! /usr/bin/env bash

set -e

while [ "$#" -ne 0 ]; do
    key="$1"
    case "$key" in
        --st)
            SUBLIME_TEXT_VERSION="$2"
            shift 2
        ;;
        *)
            echo "Unknown option: $1"
            exit 1
        ;;
    esac
done

if [ -z $SUBLIME_TEXT_VERSION ]; then
    echo "missing Sublime Text version"
    exit 1
fi

if [ $(uname) = 'Darwin' ]; then
    STP="$HOME/Library/Application Support/Sublime Text $SUBLIME_TEXT_VERSION/Packages"
else
    STP="$HOME/.config/sublime-text-$SUBLIME_TEXT_VERSION/Packages"
fi

STIP="${STP%/*}/Installed Packages"

if [ ! -d "$STIP" ]; then
    mkdir -p "$STIP"
fi


git_url="https://github.com/evandrocoan/PackagesManager"
package_name="PackagesManager"
package_full_path="$STP/$package_name"

if [ -d "$package_full_path" ]; then
    echo "ERROR: The directory $package_full_path already exists!"

else
    echo "download package $package_name: $git_url $package_full_path"
    git clone --depth 1 "$git_url" "$package_full_path"
    echo
fi



PCH_PATH="$STP/0_install_package_control_helper"

if [ ! -d "$PCH_PATH" ]; then
    mkdir -p "$PCH_PATH"
    BASE=`dirname "$0"`
    cp "$BASE"/pc_helper.py "$PCH_PATH"/pc_helper.py
fi


# launch sublime text in background
for i in {1..2}; do
    subl &

    ENDTIME=$(( $(date +%s) + 60 ))
    printf "Checking if Sublime Text has started and PackagesManager has ran.\n"
    while [ ! -f "$PCH_PATH/success" ] && [ $(date +%s) -lt $ENDTIME ]  ; do
        printf "The time limit is on $(date +%s) of $ENDTIME...\n"
        sleep 5
    done

    pkill "[Ss]ubl" || true
    pkill 'plugin_host' || true
    sleep 4
    [ -f "$PCH_PATH/success" ] && break
done

if [ -f "$PCH_PATH/log" ]; then
    cat "$PCH_PATH/log"
else
    echo "Log file not found on: $PCH_PATH/log"
fi

if [ ! -f "$PCH_PATH/success" ]; then
    echo "Timeout: Fail to install PackagesManager."
    exit 1
fi

rm -rf "$PCH_PATH"
echo ""

if [ ! -f "$STP/User/PackagesManager.sublime-settings" ]; then
    echo creating PackagesManager.sublime-settings
    # make sure PackagesManager does not complain
    echo '{"ignore_vcs_packages": true }' > "$STP/User/PackagesManager.sublime-settings"
fi

echo "PackagesManager installed."
