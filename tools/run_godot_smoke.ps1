param(
    [string] $GodotPath = "$env:TEMP\godot-4.2.2-codex\Godot_v4.2.2-stable_win64_console.exe",
    [string] $ProjectPath = (Resolve-Path "$PSScriptRoot\..").Path
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot console executable not found: $GodotPath"
}

if (-not (Test-Path -LiteralPath $ProjectPath)) {
    throw "Project path not found: $ProjectPath"
}

try {
    # Godot may print non-fatal shutdown warnings to stderr even when the smoke
    # script exits with code 0. Capture both streams without letting PowerShell
    # promote those warnings into terminating errors.
    $ErrorActionPreference = "Continue"
    $output = & $GodotPath --headless --path $ProjectPath --script "res://tools/godot_smoke_test.gd" 2>&1 | ForEach-Object { $_.ToString() }
    $exitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = "Stop"
}

$output | ForEach-Object { Write-Output $_ }

if ($exitCode -ne 0) {
    throw "Godot smoke exited with code $exitCode"
}

if (($output -join "`n") -notmatch "SMOKE_OK maps=6 blockers=6 encounters=3") {
    throw "Godot smoke did not print the expected SMOKE_OK summary."
}
