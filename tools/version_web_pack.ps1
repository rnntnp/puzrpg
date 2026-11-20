param([string]$WebDirectory = "build/web")

$ErrorActionPreference = "Stop"
$packPath = Join-Path $WebDirectory "index.pck"
$htmlPath = Join-Path $WebDirectory "index.html"
$packVersion = (Get-FileHash -LiteralPath $packPath -Algorithm SHA256).Hash.ToLowerInvariant()
$htmlText = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $htmlPath).Path)
$htmlText = [regex]::Replace($htmlText, '(?m)^GODOT_CONFIG\.mainPack = .*\r?\n', '')
$marker = 'const engine = new Engine(GODOT_CONFIG);'
if (-not $htmlText.Contains($marker)) { throw "Godot HTML configuration marker not found" }
$versionConfig = "GODOT_CONFIG.mainPack = 'index.pck?v=$packVersion';"
$sizeConfig = 'GODOT_CONFIG.fileSizes[GODOT_CONFIG.mainPack] = GODOT_CONFIG.fileSizes["index.pck"];'
$htmlText = [regex]::Replace($htmlText, '(?m)^GODOT_CONFIG\.fileSizes\[GODOT_CONFIG\.mainPack\] = .*\r?\n', '')
$htmlText = $htmlText.Replace($marker, "$versionConfig`n$sizeConfig`n$marker")
[IO.File]::WriteAllText((Resolve-Path -LiteralPath $htmlPath).Path, $htmlText, [Text.UTF8Encoding]::new($false))
Write-Output "Web pack version: $packVersion"
