param(
    [string]$GodotPath = 'godot',
    [switch]$Rendered,
    [switch]$PairedMatches
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$verificationRoot = Join-Path $projectRoot 'build\verification'
$runtimeData = Join-Path $projectRoot 'build\godot-userdata'
$priorAppData = $env:APPDATA
New-Item -ItemType Directory -Force -Path $verificationRoot, (Join-Path $runtimeData 'Godot\app_userdata\Aegis Arena') | Out-Null
[IO.File]::WriteAllText((Join-Path $projectRoot 'build\.gdignore'), '')

function Invoke-GodotCheck {
    param([string]$Name, [string[]]$EngineArguments, [string]$Expected)
    $consoleLog = Join-Path $verificationRoot ($Name + '-console.log')
    $engineLog = Join-Path $verificationRoot ($Name + '.log')
    $arguments = @('--path', $projectRoot, '--log-file', $engineLog) + $EngineArguments
    & $GodotPath @arguments 2>&1 | Set-Content -LiteralPath $consoleLog -Encoding utf8
    $engineExit = $LASTEXITCODE
    $output = Get-Content -LiteralPath $consoleLog -Raw
    if ($engineExit -ne 0 -or $output -match '(?m)^(SCRIPT ERROR:|ERROR:)') {
        Write-Output $output
        throw "$Name failed. See $consoleLog"
    }
    if ($Expected -and $output -notmatch $Expected) {
        Write-Output $output
        throw "$Name did not report completion. See $consoleLog"
    }
    if ($Expected) {
        $output -split '\r?\n' | Where-Object { $_ -match $Expected } | Write-Output
    } else {
        Write-Output "$Name passed"
    }
}

try {
    # Isolate these child processes' caches, then restore the calling environment.
    $env:APPDATA = $runtimeData
    Invoke-GodotCheck -Name 'import' -EngineArguments @('--headless', '--editor', '--quit')
    $checks = @(
        @{ Name = 'phase-one'; Script = 'test_phase_one.gd'; Pattern = 'Phase 1: \d+ checks, 0 failures' },
        @{ Name = 'presentation'; Script = 'test_presentation.gd'; Pattern = 'Presentation: \d+ checks, 0 failures' },
        @{ Name = 'battle'; Script = 'test_battle.gd'; Pattern = 'Battle rules: \d+ checks, 0 failures' },
        @{ Name = 'search'; Script = 'test_search.gd'; Pattern = 'Search: \d+ checks, 0 failures' },
        @{ Name = 'integration'; Script = 'test_integration.gd'; Pattern = 'Integration: \d+ checks, 0 failures' }
    )
    foreach ($check in $checks) {
        Invoke-GodotCheck -Name $check.Name -EngineArguments @('--headless', '--script', ('res://tests/' + $check.Script), '--quit-after', '20000') -Expected $check.Pattern
    }
    Invoke-GodotCheck -Name 'replay' -EngineArguments @('--headless', '--script', 'res://tests/replay_decision.gd', '--', 'res://output/evidence/mcts_forced_defense.json') -Expected 'action matches=true, score matches=true'
    if ($Rendered) {
        Invoke-GodotCheck -Name 'rendered' -EngineArguments @('--max-fps', '60', '--script', 'res://tests/test_live_capture.gd', '--quit-after', '6000') -Expected 'Rendered gameplay: \d+ checks, 0 failures; 0 missed slots'
    }
    if ($PairedMatches) {
        Invoke-GodotCheck -Name 'paired-short' -EngineArguments @('--headless', '--script', 'res://tests/test_matches.gd', '--', '--pairs', '10', '--duration', '30', '--iterations', '20') -Expected 'Paired matches: 20 games, 0 failures'
        Invoke-GodotCheck -Name 'paired-full' -EngineArguments @('--headless', '--script', 'res://tests/test_matches.gd', '--', '--pairs', '1', '--duration', '180', '--iterations', '20') -Expected 'Paired matches: 2 games, 0 failures'
    }
    Write-Output "All requested checks passed. Logs: $verificationRoot"
} finally {
    $env:APPDATA = $priorAppData
}
