[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$RadioRoot,

    [switch]$DryRun,

    [Alias('h')]
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Output @'
Uso:
  .\deploy.ps1 [-DryRun] [raiz-do-cartao]
  .\deploy.ps1 -DryRun E:\
  .\deploy.ps1 -Help

Sem destino, procura um cartao EdgeTX nas unidades montadas.
O arquivo flights-count.csv existente no radio e preservado.
'@
    return
}

function Test-EdgeTxRoot {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath (Join-Path $Path 'WIDGETS') -PathType Container)) {
        return $false
    }

    foreach ($directory in @('RADIO', 'SCRIPTS', 'SOUNDS', 'IMAGES')) {
        if (Test-Path -LiteralPath (Join-Path $Path $directory) -PathType Container) {
            return $true
        }
    }
    return $false
}

function Copy-DeployFile {
    param(
        [string]$RelativePath,
        [switch]$PreserveExisting
    )

    $source = Join-Path $PSScriptRoot $RelativePath
    $destination = Join-Path $RadioRoot $RelativePath
    $exists = Test-Path -LiteralPath $destination
    if ($exists) {
        if ($PreserveExisting) {
            Write-Output "Preservado: $RelativePath"
            return
        }
        if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) {
            throw "O destino do arquivo esta ocupado por uma pasta: $destination"
        }
        if ((Get-FileHash -LiteralPath $source).Hash -eq (Get-FileHash -LiteralPath $destination).Hash) {
            return
        }
    }

    if ($DryRun) {
        $action = if ($exists) { 'Atualizar' } else { 'Instalar' }
        Write-Output "[dry-run] ${action}: $RelativePath"
        return
    }

    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
    [IO.File]::Copy($source, $destination, -not $PreserveExisting)
    Write-Output "Copiado: $RelativePath"
}

try {
    $systemRoot = [IO.Path]::GetPathRoot($env:SystemRoot)
    if (-not $PSBoundParameters.ContainsKey('RadioRoot')) {
        $candidates = @(
            Get-PSDrive -PSProvider FileSystem |
                Where-Object { $_.Root -ne $systemRoot -and (Test-EdgeTxRoot $_.Root) } |
                Select-Object -ExpandProperty Root -Unique
        )
        if ($candidates.Count -eq 0) {
            throw 'Nenhum cartao EdgeTX detectado. Informe a raiz, por exemplo: .\deploy.ps1 E:\'
        }
        if ($candidates.Count -gt 1) {
            throw "Mais de um cartao EdgeTX detectado ($($candidates -join ', ')). Informe a raiz desejada."
        }
        $RadioRoot = $candidates[0]
        Write-Output "Radio EdgeTX detectado automaticamente: $RadioRoot"
    }

    $target = Get-Item -LiteralPath $RadioRoot
    if ($target -isnot [IO.DirectoryInfo]) {
        throw "O destino deve ser uma pasta: $RadioRoot"
    }
    $RadioRoot = $target.FullName
    if ($RadioRoot.TrimEnd('\') -in @($PSScriptRoot.TrimEnd('\'), $systemRoot.TrimEnd('\'))) {
        throw "Destino inseguro: $RadioRoot"
    }

    $widget = 'WIDGETS\StacyDashV4'
    $requiredFiles = @('main.lua', 'flights.lua', 'status.lua', 'themes.lua', 'ui.lua', 'leds.lua', 'elrs.lua', 'default.png') |
        ForEach-Object { Join-Path $widget $_ }
    foreach ($relativePath in ($requiredFiles + 'flights-count.csv')) {
        if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $relativePath) -PathType Leaf)) {
            throw "Arquivo necessario nao encontrado: $relativePath"
        }
    }

    $directories = [ordered]@{
        $widget                         = '.lua'
        "$widget\BatterySounds"        = '.wav'
        "$widget\audio"                = '.wav'
        "$widget\audio\gov"            = '.wav'
        "$widget\audio\profile"        = '.wav'
        'IMAGES'                        = '.png', '.bmp'
    }
    $files = foreach ($directory in $directories.Keys) {
        Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot $directory) -File |
            Where-Object { $_.Extension -in $directories[$directory] } |
            ForEach-Object { Join-Path $directory $_.Name }
    }

    Write-Output "Destino do radio: $RadioRoot"
    foreach ($relativePath in ($files + "$widget\default.png")) {
        Copy-DeployFile $relativePath
    }
    Copy-DeployFile 'flights-count.csv' -PreserveExisting

    if ($DryRun) {
        Write-Output 'Dry-run concluido; nenhum arquivo foi alterado.'
    } else {
        Write-Output 'Deploy do StacyDash concluido.'
    }
} catch {
    Write-Error $_.Exception.Message -ErrorAction Continue
    exit 1
}
