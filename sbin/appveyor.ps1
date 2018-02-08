[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$command,
    [Parameter(Mandatory = $false, Position = 1)]
    [string]$package_url,
    [Parameter(Mandatory = $false, Position = 2)]
    [string]$package_name,
    [Parameter(Mandatory = $false)]
    [switch] $coverage
)

$STP = "C:\st\Data\Packages"

function Bootstrap {
    [CmdletBinding()]
    param(
        [switch] $with_color_scheme_unit
    )

    new-item -itemtype directory "$STP\${env:PACKAGE}" -force >$null

    if (${env:PACKAGE} -eq "__all__"){
        write-verbose "copy all subfolders to sublime package directory"
        copy * -recurse -force "$STP"
    } else {
        write-verbose "copy the package to sublime text Packages directory"
        copy * -recurse -force "$STP\${env:PACKAGE}"
    }

    git config --global advice.detachedHead false

    $UT_PATH = "$STP\UnitTesting"
    if (!(test-path -path "$UT_PATH")){
        $UT_URL = "https://github.com/evandroforks/UnitTesting"

        write-verbose "download UnitTesting package: $UNITTESTING_TAG"
        git clone --depth 1 $UT_URL "$UT_PATH" 2>$null
        write-verbose ""
    }

    $COV_PATH = "$STP\coverage"
    if ((${env:SUBLIME_TEXT_VERSION} -eq 3) -and (!(test-path -path "$COV_PATH"))){

        $COV_URL = "https://github.com/codexns/sublime-coverage"

        if ( ${env:COVERAGE_TAG} -eq $null){
            # the latest tag
            $COVERAGE_TAG = git ls-remote --tags $COV_URL | %{$_ -replace ".*/(.*)$", '$1'} `
                    | where-object {$_ -notmatch "\^"} |%{[System.Version]$_} `
                    | sort | select-object -last 1 | %{ "$_" }
        } else {
            $COVERAGE_TAG = ${env:COVERAGE_TAG}
        }

        write-verbose "download sublime-coverage tag: $COVERAGE_TAG"
        git clone --depth 1 --branch=$COVERAGE_TAG $COV_URL "$COV_PATH" 2>$null
        git -C "$COV_PATH" rev-parse HEAD | write-verbose
        write-verbose ""
    }


    & "$STP\UnitTesting\sbin\install_sublime_text.ps1" -verbose

}

function InstallPackageControl {
    $COV_PATH = "$STP\coverage"
    remove-item $COV_PATH -Force -Recurse
    & "$STP\UnitTesting\sbin\install_package_control.ps1" -verbose
}

function InstallColorSchemeUnit {
    $CSU_PATH = "$STP\ColorSchemeUnit"
    if ((${env:SUBLIME_TEXT_VERSION} -eq 3) -and (!(test-path -path "$CSU_PATH"))){
        $CSU_URL = "https://github.com/gerardroche/sublime-color-scheme-unit"

        if ( ${env:COLOR_SCHEME_UNIT_TAG} -eq $null){
            # the latest tag
            $COLOR_SCHEME_UNIT_TAG = git ls-remote --tags $CSU_URL | %{$_ -replace ".*/(.*)$", '$1'} `
                    | where-object {$_ -notmatch "\^"} |%{[System.Version]$_} `
                    | sort | select-object -last 1 | %{ "$_" }
        } else {
            $COLOR_SCHEME_UNIT_TAG = ${env:COLOR_SCHEME_UNIT_TAG}
        }
        write-verbose "download ColorSchemeUnit tag: $COLOR_SCHEME_UNIT_TAG"
        git clone --depth 1 --branch=$COLOR_SCHEME_UNIT_TAG $CSU_URL "$CSU_PATH" 2>$null
        git -C "$CSU_PATH" rev-parse HEAD | write-verbose
        write-verbose ""
    }
}

function InstallKeypress {
    $KP_PATH = "$STP\Keypress"
    if ((${env:SUBLIME_TEXT_VERSION} -eq 3) -and (!(test-path -path "$KP_PATH"))){
        $KP_URL = "https://github.com/randy3k/Keypress"

        if ( ${env:KEYPRESS_TAG} -eq $null){
            # the latest tag
            $KEYPRESS_TAG = git ls-remote --tags $KP_URL | %{$_ -replace ".*/(.*)$", '$1'} `
                    | where-object {$_ -notmatch "\^"} |%{[System.Version]$_} `
                    | sort | select-object -last 1 | %{ "$_" }
        } else {
            $KEYPRESS_TAG = ${env:KEYPRESS_TAG}
        }
        write-verbose "download ColorSchemeUnit tag: $KEYPRESS_TAG"
        git clone --depth 1 --branch=$KEYPRESS_TAG $KP_URL "$KP_PATH" 2>$null
        git -C "$KP_PATH" rev-parse HEAD | write-verbose
        write-verbose ""
    }
}

function RunTests {
    [CmdletBinding()]
    param(
        [switch] $syntax_test,
        [switch] $color_scheme_test
    )

    if ( $syntax_test.IsPresent ){
        & "$STP\UnitTesting\sbin\run_tests.ps1" "${env:PACKAGE}" -verbose -syntax_test
    } elseif ( $color_scheme_test.IsPresent ){
        & "$STP\UnitTesting\sbin\run_tests.ps1" "${env:PACKAGE}" -verbose -color_scheme_test
    } elseif ( $coverage.IsPresent ) {
        & "$STP\UnitTesting\sbin\run_tests.ps1" "${env:PACKAGE}" -verbose -coverage
    } else {
        & "$STP\UnitTesting\sbin\run_tests.ps1" "${env:PACKAGE}" -verbose
    }

    stop-process -force -processname sublime_text -ea silentlycontinue
    start-sleep -seconds 2
}

function CloneGitPackage {
    $PACKAGE_PATH = "$STP\$package_name"

    write-verbose "Downloading package: $package_url $PACKAGE_PATH"
    git clone --depth 1 $package_url $PACKAGE_PATH 2>$null
    write-verbose ""
}

try{
    switch ($command){
        "bootstrap" { Bootstrap }
        "install_package_control" { InstallPackageControl }
        "install_color_scheme_unit" { InstallColorSchemeUnit }
        "install_keypresss" { InstallKeypress }
        "run_tests" { RunTests }
        "run_syntax_tests" { RunTests -syntax_test}
        "run_color_scheme_tests" { RunTests -color_scheme_test}
        "clone_git_package" { CloneGitPackage }
    }
}catch {
    throw $_
}
