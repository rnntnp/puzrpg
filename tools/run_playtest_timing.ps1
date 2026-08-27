[CmdletBinding()]
param(
    [string]$GodotExecutable = ""
)

$resolvedGodot = $GodotExecutable

if ([string]::IsNullOrWhiteSpace($resolvedGodot)) {
    foreach ($commandName in @("godot", "godot4")) {
        $command = Get-Command $commandName -ErrorAction SilentlyContinue
        if ($null -ne $command) {
            $resolvedGodot = $command.Source
            break
        }
    }
}

if ([string]::IsNullOrWhiteSpace($resolvedGodot)) {
    $candidateRoots = @(
        (Join-Path $env:USERPROFILE "Desktop\게임엔진"),
        (Join-Path $env:USERPROFILE "Downloads")
    )
    foreach ($candidateRoot in $candidateRoots) {
        if (-not (Test-Path -LiteralPath $candidateRoot)) {
            continue
        }
        $candidate = Get-ChildItem -LiteralPath $candidateRoot -Filter "Godot*_console.exe" `
            -File -Recurse -Depth 4 -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($null -eq $candidate) {
            $candidate = Get-ChildItem -LiteralPath $candidateRoot -Filter "Godot*_win64.exe" `
                -File -Recurse -Depth 4 -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -notmatch "_console\.exe$" } |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1
        }
        if ($null -ne $candidate) {
            $resolvedGodot = $candidate.FullName
            break
        }
    }
}

if ([string]::IsNullOrWhiteSpace($resolvedGodot) -or -not (Test-Path -LiteralPath $resolvedGodot)) {
    throw "Godot 실행 파일을 찾지 못했습니다. -GodotExecutable로 경로를 지정하세요."
}

$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
Write-Host "플레이테스트 시간 기록을 활성화합니다."
Write-Host "Godot: $resolvedGodot"
Write-Host "Project: $repositoryRoot"
Write-Host "게임이 종료될 때까지 이 창을 닫지 마세요."

& $resolvedGodot --path $repositoryRoot -- --playtest-timing
