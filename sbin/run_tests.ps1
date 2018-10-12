[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$PackageToTest="UnitTesting",
    [Parameter(Mandatory = $false)]
    [switch] $syntax_test,
    [Parameter(Mandatory = $false)]
    [switch] $syntax_compatibility,
    [Parameter(Mandatory = $false)]
    [switch] $color_scheme_test,
    [Parameter(Mandatory = $false)]
    [switch] $coverage
)

# UTF8 encoding without preamble (default in .NET is with preamble).
new-variable -name 'UTF8Encoding' -option CONSTANT -scope 'script' `
             -value (new-object System.Text.UTF8Encoding -argumentlist $false)

# todo(guillermooo): Make this configurable.
$packagesPath = 'C:\st\Data\Packages'
$stPath = 'C:\st\sublime_text.exe'

write-verbose "RUNNING HERE 4"
write-verbose "RUNNING HERE 4"
write-verbose "RUNNING HERE 4"
write-verbose "RUNNING HERE 4"

$outDir = "$packagesPath\User\UnitTesting\$PackageToTest"
$outFile = "$outDir\result"
$coverageFile = "$outDir\coverage"
[void] (new-item -itemtype file $outFile -force)

remove-item $outFile -force -erroraction silentlycontinue

write-verbose "RUNNING HERE 5"
write-verbose "RUNNING HERE 5"
write-verbose "RUNNING HERE 5"
write-verbose "RUNNING HERE 5"
write-verbose "RUNNING HERE 5"
write-verbose "RUNNING HERE 5"

# Configure packages to be tested.
$jpath = "$packagesPath\User\UnitTesting\schedule.json"
if (test-path $jpath) {
    $schedule = convertfrom-json "$(get-content $jpath)"
}
else {
    [void] (new-item -itemtype file -path $jpath -force)
    # Only way of using encoding object.
    [System.IO.File]::WriteAllText($jpath, "[]", $UTF8Encoding)
    $schedule = convertfrom-json "$(get-content $jpath)"
}

write-verbose "RUNNING HERE 6"
write-verbose "RUNNING HERE 6"
write-verbose "RUNNING HERE 6"
write-verbose "RUNNING HERE 6"
write-verbose "RUNNING HERE 6"
write-verbose "RUNNING HERE 6"

$found = (@($schedule | foreach-object { $_.package }) -eq $PackageToTest).length
if ($found -eq 0) {
    $schedule_info = @{
        "package" = $PackageToTest;
        "output" = $outFile;
        "syntax_test" = $syntax_test.IsPresent;
        "syntax_compatibility" = $syntax_compatibility.IsPresent;
        'color_scheme_test' = $color_scheme_test.IsPresent;
        "coverage" = $coverage.IsPresent
    }
    write-verbose "Schedule:"
    foreach ($h in $schedule_info.GetEnumerator()) {
        write-verbose "  $($h.Name): $($h.Value)"
    }

    $schedule += $schedule_info
}

write-verbose "RUNNING HERE 7"
write-verbose "RUNNING HERE 7"
write-verbose "RUNNING HERE 7"
write-verbose "RUNNING HERE 7"
write-verbose "RUNNING HERE 7"
write-verbose "RUNNING HERE 7"

[System.IO.File]::WriteAllText(
    $jpath, (convertto-json $schedule), $UTF8Encoding)


# inject scheduler
$schedule_source = "$packagesPath\UnitTesting\sbin\run_scheduler.py"
$schedule_target = "$packagesPath\UnitTesting\zzz_run_scheduler.py"

if (test-path $schedule_target) {
    remove-item $schedule_target -force
}

if (-not (test-path $schedule_target)) {
    copy-item $schedule_source $schedule_target -force
}

write-verbose "RUNNING HERE 8"
write-verbose "RUNNING HERE 8"
write-verbose "RUNNING HERE 8"
write-verbose "RUNNING HERE 8"
write-verbose "RUNNING HERE 8"
write-verbose "RUNNING HERE 8"

# launch sublime
$sublimeIsRunning = get-process 'sublime_text' -erroraction silentlycontinue

# XXX(guillermooo): we cannot start the editor minimized?
if($sublimeIsRunning -eq $null) {
    start-process $stPath
}

write-verbose "RUNNING HERE 9"
write-verbose "RUNNING HERE 9"
write-verbose "RUNNING HERE 9"
write-verbose "RUNNING HERE 9"
write-verbose "RUNNING HERE 9"
write-verbose "RUNNING HERE 9"

$startTime = get-date
while (-not (test-path $outFile) -or (get-item $outFile).length -eq 0) {
    write-host -nonewline "."
    if (((get-date) - $startTime).totalseconds -ge 60) {
        write-host
        if (test-path $schedule_target) {
            remove-item $schedule_target -force
        }
        throw "Timeout: Sublime Text is not responding."
    }
    start-sleep -seconds 1
}
write-host

write-verbose "start to read output"

write-verbose "RUNNING HERE 10"
write-verbose "RUNNING HERE 10"
write-verbose "RUNNING HERE 10"
write-verbose "RUNNING HERE 10"
write-verbose "RUNNING HERE 10"
write-verbose "RUNNING HERE 10"

$copy = "$outfile.copy"
$read = 0
$done = $false
while ($true) {
    # XXX(guillermooo): We can't open a file already opened by another
    # process. By copying the file first, we can work around this. (But if
    # we can copy it we should be able to read it too?).
    # Powershell's `get-content $path -tail 1 -wait` is in fact able to read
    # from an already opened file. Perhaps it uses the same workaround as we
    # do here?
    copy-item $outfile $copy -force

    $lines = (get-content $copy)
    $lines = $lines | select-object -skip $read
    $count = $lines.count
    if ($count -gt 0){
        foreach ($i in 0..($count-1)){
            $l = $lines | select-object -index $i
            # do not print the last line, may be incomplete
            if ($i -lt $count-1){
                write-output $l
            }
            if ($l -match "^(OK|FAILED|ERROR)\b") {
                $success = ($matches[1] -eq "OK")
            }
            if ($l -match "^UnitTesting: Done\.$") {
                write-output $l
                $done = $true
                break
            }
        }
        $read = $read + $count - 1
        if ($done) { break }
    }
    write-verbose "RUNNING HERE 13 - SLEEP"
    start-sleep -milliseconds 200
}

write-verbose "RUNNING HERE 11"
write-verbose "RUNNING HERE 11"
write-verbose "RUNNING HERE 11"
write-verbose "RUNNING HERE 11"
write-verbose "RUNNING HERE 11"
write-verbose "RUNNING HERE 11"


# restore .coverage if it exists, needed for coveralls
if (test-path $coverageFile) {
    copy-item $coverageFile ".\.coverage" -force
    $cwd = (get-item -Path ".\" -verbose).fullname.replace("\", "\\")
    $pkgpath = "$packagesPath\$PackageToTest".replace("\", "\\")
    $data = (get-content ".\.coverage") -replace [regex]::escape($pkgpath), $cwd
    set-content ".\.coverage" -value $data
}

write-verbose "RUNNING HERE 12"
write-verbose "RUNNING HERE 12"
write-verbose "RUNNING HERE 12"
write-verbose "RUNNING HERE 12"
write-verbose "RUNNING HERE 12"
write-verbose "RUNNING HERE 12"

if (test-path $schedule_target) {
    remove-item $schedule_target -force
}

write-verbose "RUNNING HERE 13"
write-verbose "RUNNING HERE 13"
write-verbose "RUNNING HERE 13"
write-verbose "RUNNING HERE 13"
write-verbose "RUNNING HERE 13"

if (!$success) {
    throw
}
