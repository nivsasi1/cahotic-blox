# Plays the whole game with two real test clients in Studio and prints what happened.
# Needs Roblox Studio installed and signed in. Usage: .\tests\integration\run.ps1
param([int]$TimeoutSeconds = 240)

$root = Resolve-Path "$PSScriptRoot\..\.."
& "$PSScriptRoot\build.ps1"
if ($LASTEXITCODE -ne 0) { exit 1 }

$studio = Get-ChildItem "$env:LOCALAPPDATA\Roblox\Versions" -Recurse -Filter RobloxStudioBeta.exe |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
$logs = "$env:LOCALAPPDATA\Roblox\logs"
$started = Get-Date

$launch = "-task RunScript -localPlaceFile $root\.cache\test.rbxlx " +
    "-runScriptFile $root\tests\integration\start.luau " +
    "-outputFile $root\.cache\runner.log -quitAfterExecution"
Start-Process -FilePath $studio.FullName -ArgumentList $launch | Out-Null

$deadline = $started.AddSeconds($TimeoutSeconds)
do {
    Start-Sleep -Seconds 2
    $newLogs = Get-ChildItem $logs -Filter *_Studio_*_last.log | Where-Object { $_.CreationTime -gt $started }
    $finished = $newLogs | Select-String -Pattern '\[TEST\] DONE' -List
} until ($finished -or (Get-Date) -gt $deadline)

$newLogs | Select-String -Pattern '\[TEST\]|\[Duel\]|CreatorError' |
    Where-Object { $_.Line -notmatch 'ChatScript|CoreGuiChatConnections' } |
    ForEach-Object { $_.Line -replace '^.*?\[FLog::[A-Za-z]+\] ', '' }

Start-Sleep -Seconds 2
Get-Process RobloxStudioBeta, RobloxCrashHandler -ErrorAction SilentlyContinue |
    Where-Object { $_.StartTime -gt $started.AddSeconds(-2) } |
    Stop-Process -Force -Confirm:$false

# The test clients' screenshots land in Roblox's capture folder, named by process id and a 6-digit counter
$shotNames = 'hub', 'invite_window', 'invite_popup', 'countdown', 'live', 'result', 'back_in_hub'
$shots = "$root\.cache\shots"
Remove-Item $shots -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $shots | Out-Null
$clients = @{}
Get-ChildItem "$env:LOCALAPPDATA\Roblox\tmp-capture-storage" -File |
    Where-Object { $_.LastWriteTime -gt $started } |
    Sort-Object Name | ForEach-Object {
        if ($_.Name -match '^wob-(\d+)(\d{6})$') {
            $client = $Matches[1]
            $index = [int]$Matches[2]
            if (-not $clients.ContainsKey($client)) { $clients[$client] = $clients.Count + 1 }
            Copy-Item $_.FullName "$shots\$($shotNames[$index])_client$($clients[$client]).png"
        }
    }

if (-not $finished) {
    Write-Output "TIMED OUT after $TimeoutSeconds seconds"
    exit 1
}
if ("$finished" -notmatch 'failed=0') { exit 1 }
