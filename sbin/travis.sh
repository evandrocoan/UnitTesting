#!/bin/bash

set -e

if [ $(uname) = 'Darwin' ]; then
    STP="$HOME/Library/Application Support/Sublime Text $SUBLIME_TEXT_VERSION/Packages"
else
    STP="$HOME/.config/sublime-text-$SUBLIME_TEXT_VERSION/Packages"
fi

Bootstrap() {
    if [ "$TRAVIS_OS_NAME" = "linux" ] && [ -z $DISPLAY ]; then
        echo "Xvfb is not running"
        echo "check https://github.com/SublimeText/UnitTesting/issues/74"
        exit 1
    fi
    if [ "$PACKAGE" = "__all__" ]; then
        echo "copy all subfolders to sublime package directory"
        mkdir -p "$STP"
        cp -r ./ "$STP"
    else
        if [ ! -d "$STP/$PACKAGE" ]; then
            # symlink does not play well with coverage
            echo "copy the package to sublime package directory"
            mkdir -p "$STP/$PACKAGE"
            cp -r ./ "$STP/$PACKAGE"
        fi
    fi

    # Disable warnings about detached HEAD
    # https://stackoverflow.com/questions/36794501
    git config --global advice.detachedHead false

    DEBUG_TOOLS_PATH="$STP/DebugTools"
    if [ ! -d "$DEBUG_TOOLS_PATH" ]; then

        if [ -z $DEBUG_TOOLS_URL ]; then
            DEBUG_TOOLS_URL="https://github.com/evandrocoan/DebugTools"
        fi

        if [ ! -z $DEBUG_TOOLS_TAG ]; then
            DEBUG_TOOLS_TAG=--branch $DEBUG_TOOLS_TAG
        fi

        echo "download DebugTools tag: $DEBUG_TOOLS_TAG, $DEBUG_TOOLS_URL $DEBUG_TOOLS_PATH"
        git clone --depth 1 $DEBUG_TOOLS_TAG "$DEBUG_TOOLS_URL" "$DEBUG_TOOLS_PATH"
        git -C "$DEBUG_TOOLS_PATH" rev-parse HEAD
        echo
    fi

    UT_PATH="$STP/UnitTesting"
    if [ ! -d "$UT_PATH" ]; then

        if [ -z $UT_URL ]; then
            UT_URL="https://github.com/evandroforks/UnitTesting"
        fi

        if [ ! -z $UNITTESTING_TAG ]; then
            UNITTESTING_TAG=--branch $UNITTESTING_TAG
        fi

        echo "download UnitTesting tag: $UNITTESTING_TAG, $UT_URL $UT_PATH"
        git clone --depth 1 $UNITTESTING_TAG "$UT_URL" "$UT_PATH"
        git -C "$UT_PATH" rev-parse HEAD
        echo
    fi

    COV_PATH="$STP/coverage"
    if [ "$SUBLIME_TEXT_VERSION" -eq 3 ] && [ ! -d "$COV_PATH" ]; then

        COV_URL="https://github.com/codexns/sublime-coverage"

        if [ -z $COVERAGE_TAG ]; then
            # latest tag
            COVERAGE_TAG=$(git ls-remote --tags "$COV_URL" |
                  sed 's|.*/\(.*\)$|\1|' | grep -v '\^' |
                  sort -t. -k1,1nr -k2,2nr -k3,3nr | head -n1)
        fi

        echo "download sublime-coverage tag: $COVERAGE_TAG"
        git clone --depth 1 --branch $COVERAGE_TAG "$COV_URL" "$COV_PATH"
        git -C "$COV_PATH" rev-parse HEAD
        echo
    fi

    sh "$STP/UnitTesting/sbin/install_sublime_text.sh"
}

InstallPackageControl() {
    sh "$STP/UnitTesting/sbin/install_package_control.sh"
}

InstallColorSchemeUnit() {
    CSU_PATH="$STP/ColorSchemeUnit"
    if [ "$SUBLIME_TEXT_VERSION" -eq 3 ] && [ ! -d "$CSU_PATH" ]; then

        CSU_URL="https://github.com/gerardroche/sublime-color-scheme-unit"

        if [ -z $COLOR_SCHEME_UNIT_TAG ]; then
            # latest tag
            COLOR_SCHEME_UNIT_TAG=$(git ls-remote --tags "$CSU_URL" |
                  sed 's|.*/\(.*\)$|\1|' | grep -v '\^' |
                  sort -t. -k1,1nr -k2,2nr -k3,3nr | head -n1)
        fi

        echo "download ColorSchemeUnit tag: $COLOR_SCHEME_UNIT_TAG"
        git clone --depth 1 --branch $COLOR_SCHEME_UNIT_TAG "$CSU_URL" "$CSU_PATH"
        git -C "$CSU_PATH" rev-parse HEAD
        echo
    fi
}

InstallKeypress() {
    KP_PATH="$STP/Keypress"
    if [ "$SUBLIME_TEXT_VERSION" -eq 3 ] && [ ! -d "$KP_PATH" ]; then

        KP_URL="https://github.com/randy3k/Keypress"

        if [ -z $KEYPRESS_TAG ]; then
            # latest tag
            KEYPRESS_TAG=$(git ls-remote --tags "$KP_URL" |
                  sed 's|.*/\(.*\)$|\1|' | grep -v '\^' |
                  sort -t. -k1,1nr -k2,2nr -k3,3nr | head -n1)
        fi

        echo "download Keypress tag: $KEYPRESS_TAG"
        git clone --depth 1 --branch $KEYPRESS_TAG "$KP_URL" "$KP_PATH"
        git -C "$KP_PATH" rev-parse HEAD
        echo
    fi
}

RunTests() {
    if [ -z "$1" ]; then
        python "$STP/UnitTesting/sbin/run_tests.py" "$PACKAGE"
    else
        python "$STP/UnitTesting/sbin/run_tests.py" "$@" "$PACKAGE"
    fi

    pkill "[Ss]ubl" || true
    pkill 'plugin_host' || true
    sleep 2
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


COMMAND=$1
shift
echo "Running command: ${COMMAND} $@"
case $COMMAND in
    "bootstrap")
        Bootstrap "$@"
        ;;
    "install_package_control")
        InstallPackageControl "$@"
        ;;
    "install_color_scheme_unit")
        InstallColorSchemeUnit "$@"
        ;;
    "install_keypress")
        InstallKeypress "$@"
        ;;
    "run_tests")
        RunTests "$@"
        ;;
    "run_syntax_tests")
        RunTests "--syntax-test" "$@"
        ;;
    "run_syntax_compatibility")
        RunTests "--syntax-compatibility" "$@"
        ;;
    "run_color_scheme_tests")
        RunTests "--color-scheme-test" "$@"
        ;;
    "clone_git_package")
        CloneGitPackage "$@"
        ;;
esac
