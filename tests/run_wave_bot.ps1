# Runs the wave bot (tests/wave_bot.tscn) headless over several seeds and prints the report.
#
#   .\tests\run_wave_bot.ps1 -Godot "C:\path\Godot_console.exe"
#
# Soak runs keep the Fortress and the commander alive so every wave is played: 20 waves at x3
# for each soak seed, plus one run of all scripted waves. Then AFK and Frontline runs of 15 waves
# on the same seeds, for the comparison. Up to -Parallel runs at once. Results go to -Out
# (one JSON line per run) and tests/wave_bot_report.py prints the summary.
param(
    [Parameter(Mandatory = $true)][string]$Godot,
    [int[]]$SoakSeeds = @(11, 22, 33),
    [int[]]$CompareSeeds = @(11, 22, 33),
    [int]$Parallel = 3,
    [string]$Out = "wave_bot_results.jsonl"
)

$project = Split-Path -Parent $PSScriptRoot
if (Test-Path $Out) { Remove-Item $Out }
$outPath = (Resolve-Path -LiteralPath (New-Item -ItemType File -Force $Out)).Path

$jobs = @()
foreach ($s in $SoakSeeds) { $jobs += , @("--seed=$s", "--waves=20", "--soak", "--mode=afk") }
$jobs += , @("--seed=$($SoakSeeds[0] + 33)", "--waves=30", "--soak", "--mode=afk")
foreach ($s in $CompareSeeds) {
    $jobs += , @("--seed=$s", "--waves=15", "--mode=afk")
    $jobs += , @("--seed=$s", "--waves=15", "--mode=frontline")
}

$logDir = Join-Path ([System.IO.Path]::GetTempPath()) "wave_bot_logs"
New-Item -ItemType Directory -Force $logDir | Out-Null
$running = @()
$index = 0
foreach ($job in $jobs) {
    while (@($running | Where-Object { -not $_.HasExited }).Count -ge $Parallel) { Start-Sleep -Seconds 5 }
    $argList = @("--headless", "--path", "`"$project`"", "res://tests/wave_bot.tscn", "--") + $job + @("--out=`"$outPath`"")
    Write-Host "start: $($job -join ' ')"
    $index += 1
    $running += Start-Process -FilePath $Godot -ArgumentList $argList -NoNewWindow -PassThru `
        -RedirectStandardOutput (Join-Path $logDir "run$index.out.txt") -RedirectStandardError (Join-Path $logDir "run$index.err.txt")
}
$running | ForEach-Object { $_.WaitForExit() }

python (Join-Path $PSScriptRoot "wave_bot_report.py") $outPath
