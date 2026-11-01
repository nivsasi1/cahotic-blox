# Builds .cache/test.rbxlx: the real game plus the integration test scripts
$root = Resolve-Path "$PSScriptRoot\..\.."
Set-Location $root

$project = Get-Content default.project.json -Raw | ConvertFrom-Json
$project.tree.ServerScriptService | Add-Member -NotePropertyName TestServer -NotePropertyValue ([pscustomobject]@{ '$path' = 'tests/integration/server' })
$project.tree.StarterPlayer.StarterPlayerScripts | Add-Member -NotePropertyName TestClient -NotePropertyValue ([pscustomobject]@{ '$path' = 'tests/integration/client' })
# WriteAllText because Set-Content adds a BOM on Windows PowerShell, and Rojo can't parse that
[IO.File]::WriteAllText("$root\.test.project.json", ($project | ConvertTo-Json -Depth 40))

New-Item -ItemType Directory -Force .cache | Out-Null
rojo build .test.project.json -o .cache\test.rbxlx
