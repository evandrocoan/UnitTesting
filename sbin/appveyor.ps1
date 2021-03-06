# NOTE: These params need to mirror exactly those of ci.ps1
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

# Enable debug mode as the cmd `@echo on`
# Set-PSDebug -Trace 1

$ErrorActionPreference = 'stop'

# Scripts other than the bootstrapper are downloaded to and used from this directory.
$global:UnitTestingPowerShellScriptsDirectory = $env:TEMP

if (!$env:UNITTESTING_BOOTSTRAPPED) {
    write-output "[UnitTesting] bootstrapping environment..."

    invoke-webrequest "https://raw.githubusercontent.com/evandrocoan/UnitTesting/master/sbin/ps/ci_config.ps1" -outfile "$UnitTestingPowerShellScriptsDirectory\ci_config.ps1"
    invoke-webrequest "https://raw.githubusercontent.com/evandrocoan/UnitTesting/master/sbin/ps/utils.ps1" -outfile "$UnitTestingPowerShellScriptsDirectory\utils.ps1"
    invoke-webrequest "https://raw.githubusercontent.com/evandrocoan/UnitTesting/master/sbin/ps/ci.ps1" -outfile "$UnitTestingPowerShellScriptsDirectory\ci.ps1"

    . $UnitTestingPowerShellScriptsDirectory\ci_config.ps1

    $env:UNITTESTING_BOOTSTRAPPED = 1
}

# Dependencies are now available to this script.
. $UnitTestingPowerShellScriptsDirectory\utils.ps1

& $UnitTestingPowerShellScriptsDirectory\ci.ps1 @PSBoundParameters
