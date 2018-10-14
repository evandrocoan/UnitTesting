<#
.SYNOPSIS
The ci.ps1 script controls the execution of Unittesting-related commands in a CI
environment.

.DESCRIPTION
The ci.ps1 script controls the execution of commands related to the Unittesting
package used to write tests for Sublime Text packages and plugins. The ci.ps1
script is meant to be used in a CI server (Windows-only at present). The ci.ps1
script is the entry point for users.

.PARAMETER Command
The name of the command to be executed.

.PARAMETER Coverage
If true, coverage statistics will be calculated.

.NOTES
The ci.ps1 script supersedes the appveyor.ps1 script. If you can choose, use
ci.ps1 from now on. The ci.ps1 script is a drop-in replacement for appveyor.ps1.

On first execution, ci.ps1 bootstraps itself by downloading required files and
copying them to a temp directory from which they are then used. Therefore, this
is the only script you need to download from a CI configuration if you want to
use it.

#>
[CmdletBinding()]
param(
    [Parameter(Position=0, Mandatory=$true)]
    [ValidateSet('bootstrap', 'install_package_control', 'install_color_scheme_unit',
        'install_keypress', 'run_tests', 'run_syntax_tests', 'run_syntax_compatibility',
        'run_color_scheme_tests', 'clone_git_package')]
    [string]$command,
    [switch]$coverage,
    [Parameter(Mandatory = $false, Position = 1)]
    [string]$package_url,
    [Parameter(Mandatory = $false, Position = 2)]
    [string]$package_name,
    [Parameter(Mandatory = $false, Position = 3)]
    [string]$package_tag
)

# Stop execution on any error. PS default is to continue on non-terminating errors.
$ErrorActionPreference = 'stop'

$global:UnitTestingPowerShellScriptsDirectory = $env:TEMP

# Do one-time environment initialization if needed.
if (!$env:UNITTESTING_BOOTSTRAPPED) {
    write-output "[UnitTesting] bootstrapping environment..."

    # Download scripts for basic operation.
    invoke-webrequest "https://raw.githubusercontent.com/evandroforks/UnitTesting/master/sbin/ps/ci_config.ps1" -outfile "$UnitTestingPowerShellScriptsDirectory\ci_config.ps1"
    invoke-webrequest "https://raw.githubusercontent.com/evandroforks/UnitTesting/master/sbin/ps/utils.ps1" -outfile "$UnitTestingPowerShellScriptsDirectory\utils.ps1"
    invoke-webrequest "https://raw.githubusercontent.com/evandroforks/UnitTesting/master/sbin/ps/ci.ps1" -outfile "$UnitTestingPowerShellScriptsDirectory\ci.ps1"

    $env:UNITTESTING_BOOTSTRAPPED = 1
}

. $UnitTestingPowerShellScriptsDirectory\ci_config.ps1
. $UnitTestingPowerShellScriptsDirectory\utils.ps1

$fullConsoleDebugToolsFullConsoleOutput = "$SublimeTextPackagesDirectory\full_console"
$fullConsoleDebugToolsFullConsoleScript = "$SublimeTextDirectory\0_0full_console_output.py"
$fullConsoleDebugToolsFullConsoleZip = "$SublimeTextInstalledPackagesDirectory\0_0full_console_output.zip"
$fullConsoleDebugToolsFullConsolePackage = "0_0full_console_output.sublime-package"

$debugToolsConsoleScript = @"
#! /usr/bin/env python
# -*- coding: utf-8 -*-
import sys
import time
import threading

from DebugTools.all.debug_tools import getLogger
log = getLogger("full_console_output", file=r"$fullConsoleDebugToolsFullConsoleOutput", stdout=True)

print("")
print("Testing print")
sys.stderr.write("Testing sys.stderr for %s\n" % r"$fullConsoleDebugToolsFullConsoleOutput")
sys.stdout.write("Testing sys.stdout for %s\n" % r"$fullConsoleDebugToolsFullConsoleOutput")

log(1, "TESTING!")
log(1, "TESTING! logfile to: %s", r"$fullConsoleDebugToolsFullConsoleOutput")

def time_passing():

    while(True):
        log(1, "The time is passing...")
        time.sleep(1)

thread = threading.Thread( target=time_passing )
thread.start()
"@

function Bootstrap {
    ensureCreateDirectory $SublimeTextPackagesDirectory
    ensureCreateDirectory $SublimeTextInstalledPackagesDirectory

    # Copy plugin files to Packages/<Package> folder.
    if ($PackageUnderTestName -eq $SymbolCopyAll){
        logVerbose "creating directory for package under test at $PackageUnderTestSublimeTextPackagesDirectory..."
        ensureCreateDirectory $PackageUnderTestSublimeTextPackagesDirectory
        logVerbose "copying current directory contents to $PackageUnderTestSublimeTextPackagesDirectory..."
        # TODO: create junctions for all packages.
        ensureCopyDirectoryContents . $SublimeTextPackagesDirectory
    } else {
        logVerbose "creating directory junction to package under test at $PackageUnderTestSublimeTextPackagesDirectory..."
        ensureCreateDirectoryJunction $PackageUnderTestSublimeTextPackagesDirectory .
    }

    # Clone UnitTesting into Packages/UnitTesting.
    if (pathExists -Negate $UnitTestingSublimeTextPackagesDirectory) {
        # $UNITTESTING_TAG = getLatestUnitTestingBuildTag $env:UNITTESTING_TAG $SublimeTextVersion $UnitTestingRepositoryUrl
        # logVerbose "download UnitTesting tag: $UNITTESTING_TAG"
        # gitCloneTag $UNITTESTING_TAG $UnitTestingRepositoryUrl $UnitTestingSublimeTextPackagesDirectory
        logVerbose "download UnitTesting: $UnitTestingRepositoryUrl $UnitTestingSublimeTextPackagesDirectory $env:UNITTESTING_TAG"
        cloneRepository $UnitTestingRepositoryUrl $UnitTestingSublimeTextPackagesDirectory $env:UNITTESTING_TAG
        logVerbose "SUCCESSFULLY CLONED UNITTESTING!"
        gitGetHeadRevisionName $UnitTestingSublimeTextPackagesDirectory | logVerbose
        logVerbose ""
    }

    # Clone DebugTools into Packages/DebugTools.
    if (pathExists -Negate $DebugToolsSublimeTextPackagesDirectory) {
        logVerbose "download DebugTools: $DebugToolsRepositoryUrl $DebugToolsSublimeTextPackagesDirectory $env:DEBUG_TOOLS_TAG"
        cloneRepository $DebugToolsRepositoryUrl $DebugToolsSublimeTextPackagesDirectory $env:DEBUG_TOOLS_TAG
        logVerbose "SUCCESSFULLY CLONED DEBUG TOOLS!"
        gitGetHeadRevisionName $DebugToolsSublimeTextPackagesDirectory | logVerbose
        logVerbose ""
    }

    logVerbose "Start capturing all Sublime Text console with DebugTools"
    "$debugToolsConsoleScript" | Out-File -FilePath "$fullConsoleDebugToolsFullConsoleScript" -Encoding ASCII

    logVerbose "Create it as Packed file because they are loaded first by Sublime Text"
    Compress-Archive -Path "$fullConsoleDebugToolsFullConsoleScript" -DestinationPath "$fullConsoleDebugToolsFullConsoleZip" -CompressionLevel Optimal -Force

    logVerbose "Renaming the zip file to $fullConsoleDebugToolsFullConsolePackage"
    Rename-Item "$fullConsoleDebugToolsFullConsoleZip" -NewName "$fullConsoleDebugToolsFullConsolePackage"

    logVerbose ""
    logVerbose "Clone coverage plugin into Packages/coverage"
    installPackageForSublimeTextVersion3IfNotPresent $CoverageSublimeTextPackagesDirectory $env:COVERAGE_TAG $CoverageRepositoryUrl

    & "$UnitTestingSublimeTextPackagesDirectory\sbin\install_sublime_text.ps1" -verbose
}

function InstallPackageControl {
    & "$UnitTestingSublimeTextPackagesDirectory\sbin\install_package_control.ps1" -verbose
}

function InstallColorSchemeUnit {
    installPackageForSublimeTextVersion3IfNotPresent $ColorSchemeUnitSublimeTextPackagesDirectory $env:COLOR_SCHEME_UNIT_TAG $ColorSchemeUnitRepositoryUrl
}

function InstallKeypress {
    installPackageForSublimeTextVersion3IfNotPresent $KeyPressSublimeTextPackagesDirectory $env:KEYPRESS_TAG $KeyPressRepositoryUrl
}

function RunTests {
    [CmdletBinding()]
    param([switch]$syntax_test, [switch]$syntax_compatibility, [switch]$color_scheme_test, [switch]$coverage)

    # TODO: Change script name to conform to PS conventions.
    # TODO: Do not use verbose by default.
    & "$UnitTestingSublimeTextPackagesDirectory\sbin\run_tests.ps1" $PackageUnderTestName -verbose @PSBoundParameters

    stop-process -force -processname sublime_text -ea silentlycontinue
    start-sleep -seconds 2
}

function CloneGitPackage {
    $PACKAGE_PATH = "$SublimeTextPackagesDirectory\$package_name"
    logVerbose "Downloading package: $package_url $PACKAGE_PATH $package_tag"

    cloneRepository $package_url "$PACKAGE_PATH" $package_tag
    logVerbose ""
}

switch ($command){
    'bootstrap' { Bootstrap }
    'install_package_control' { InstallPackageControl }
    'install_color_scheme_unit' { InstallColorSchemeUnit }
    'install_keypress' { InstallKeypress }
    'run_tests' { RunTests -coverage:$coverage }
    'run_syntax_tests' { RunTests -syntax_test }
    'run_syntax_compatibility' { RunTests -syntax_compatibility }
    'run_color_scheme_tests' { RunTests -color_scheme_test }
    'clone_git_package' { CloneGitPackage }
}
