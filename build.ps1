<#
.SYNOPSIS
    Builds libmem on Windows using MSVC and CMake.

.DESCRIPTION
    Automates locating Visual Studio, initializing the developer environment,
    configuring CMake, and building the libmem static library.

.PARAMETER Config
    The build configuration: Release (default) or Debug.

.PARAMETER Arch
    Target architecture: x64 (default), x86, or arm64.

.PARAMETER Clean
    If specified, removes the build directory before building.

.EXAMPLE
    .\build.ps1
    .\build.ps1 -Config Release -Arch x64
    .\build.ps1 -Clean
#>
[CmdletBinding()]
param (
    [ValidateSet("Release", "Debug")]
    [string]$Config = "Release",

    [ValidateSet("x64", "x86", "arm64")]
    [string]$Arch = "x64",

    [switch]$Clean
)

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
$BuildDir = Join-Path $ScriptDir "build"

if ($Clean -and (Test-Path -LiteralPath $BuildDir)) {
    Write-Host "[*] Cleaning existing build directory: $BuildDir" -ForegroundColor Cyan
    Remove-Item -LiteralPath $BuildDir -Recurse -Force
}

$batPath = Join-Path $ScriptDir "build.bat"
& cmd.exe /c "`"$batPath`" $Config $Arch"

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
