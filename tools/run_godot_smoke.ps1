param(
    [string] $GodotPath = "$env:TEMP\godot-4.2.2-codex\Godot_v4.2.2-stable_win64_console.exe",
    [string] $ProjectPath = (Resolve-Path "$PSScriptRoot\..").Path,
    [int] $TimeoutSeconds = 90
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot console executable not found: $GodotPath"
}

if (-not (Test-Path -LiteralPath $ProjectPath)) {
    throw "Project path not found: $ProjectPath"
}

function Quote-ProcessArgument([string] $Value) {
    return '"' + ($Value -replace '"', '\"') + '"'
}

$arguments = @("--headless", "--path", $ProjectPath, "--script", "res://tools/godot_smoke_test.gd")
$argumentText = ($arguments | ForEach-Object { Quote-ProcessArgument $_ }) -join " "

$startInfo = [System.Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = $GodotPath
$startInfo.Arguments = $argumentText
$startInfo.UseShellExecute = $false
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$startInfo.CreateNoWindow = $true

$process = [System.Diagnostics.Process]::new()
$process.StartInfo = $startInfo

Write-Output "SMOKE_WRAPPER start timeout_seconds=$TimeoutSeconds"

[void] $process.Start()
$completed = $process.WaitForExit($TimeoutSeconds * 1000)

if (-not $completed) {
    Write-Output "SMOKE_WRAPPER timeout killing_pid=$($process.Id)"
    try {
        $process.Kill()
    } catch {
        Write-Output "SMOKE_WRAPPER kill_failed=$($_.Exception.Message)"
    }
}

$stdout = $process.StandardOutput.ReadToEnd()
$stderr = $process.StandardError.ReadToEnd()

if ($completed) {
    $process.WaitForExit()
}

$outputText = ($stdout + "`n" + $stderr).Trim()
if (-not [string]::IsNullOrWhiteSpace($outputText)) {
    $outputText -split "`r?`n" | ForEach-Object { Write-Output $_ }
}

if (-not $completed) {
    throw "Godot smoke timed out after $TimeoutSeconds seconds"
}

$exitCode = $process.ExitCode
Write-Output "SMOKE_WRAPPER exit_code=$exitCode"

if ($exitCode -ne 0) {
    throw "Godot smoke exited with code $exitCode"
}

if ($outputText -notmatch "SMOKE_OK maps=6 blockers=6 encounters=3") {
    throw "Godot smoke did not print the expected SMOKE_OK summary."
}
