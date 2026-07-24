[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceDirectory,

    [Parameter(Mandatory = $true)]
    [string]$DestinationZip
)

$ErrorActionPreference = "Stop"

$SourceDirectory = [IO.Path]::GetFullPath($SourceDirectory)
$DestinationZip = [IO.Path]::GetFullPath($DestinationZip)
$RequiredRootFiles = @(
    "SearXNG for Windows.bat",
    "README.md",
    "LICENSE",
    "BUILD-INFO.txt"
)

if (-not (Test-Path -LiteralPath $SourceDirectory -PathType Container)) {
    throw "Portable source directory does not exist: $SourceDirectory"
}

foreach ($FileName in $RequiredRootFiles) {
    $FilePath = Join-Path $SourceDirectory $FileName
    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        throw "Required portable root file is missing: $FilePath"
    }
}

$SecretFiles = Get-ChildItem -LiteralPath $SourceDirectory -Recurse -Force -File |
    Where-Object { $_.Name -eq ".secret" }
if ($SecretFiles) {
    throw "Refusing to package a runtime .secret file"
}

$DestinationDirectory = Split-Path -Parent $DestinationZip
New-Item -ItemType Directory -Force -Path $DestinationDirectory | Out-Null
if (Test-Path -LiteralPath $DestinationZip) {
    Remove-Item -LiteralPath $DestinationZip -Force
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory(
    $SourceDirectory,
    $DestinationZip,
    [IO.Compression.CompressionLevel]::Optimal,
    $false
)

$Archive = [IO.Compression.ZipFile]::OpenRead($DestinationZip)
try {
    foreach ($FileName in $RequiredRootFiles) {
        if ($null -eq $Archive.GetEntry($FileName)) {
            throw "Packaged ZIP is missing required root file: $FileName"
        }
    }

    if ($Archive.Entries.FullName -contains ".secret") {
        throw "Packaged ZIP unexpectedly contains .secret"
    }
}
finally {
    $Archive.Dispose()
}

$Hash = Get-FileHash -LiteralPath $DestinationZip -Algorithm SHA256
Write-Host "Portable package completed:"
Write-Host "  Path: $DestinationZip"
Write-Host "  Size: $((Get-Item -LiteralPath $DestinationZip).Length) bytes"
Write-Host "  SHA256: $($Hash.Hash)"
