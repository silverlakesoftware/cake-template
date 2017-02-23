##########################################################################
# This is the Cake bootstrapper script for PowerShell.
# This file was downloaded from https://github.com/cake-build/resources
# Feel free to change this file to fit your needs.
##########################################################################

<#

.SYNOPSIS
This is a Powershell script to bootstrap a Cake build.

.DESCRIPTION
This Powershell script will download NuGet if missing, restore NuGet tools (including Cake)
and execute your Cake build script with the parameters you provide.

.PARAMETER Script
The build script to execute.
.PARAMETER Target
The build script target to run.
.PARAMETER Configuration
The build configuration to use.
.PARAMETER Verbosity
Specifies the amount of information to be displayed.
.PARAMETER Experimental
Tells Cake to use the latest Roslyn release.
.PARAMETER WhatIf
Performs a dry run of the build script.
No tasks will be executed.
.PARAMETER Mono
Tells Cake to use the Mono scripting engine.
.PARAMETER SkipToolPackageRestore
Skips restoring of packages.
.PARAMETER ScriptArgs
Remaining arguments are added here.

.LINK
http://cakebuild.net

#>

[CmdletBinding()]
Param(
    [string]$Script = "build.cake",
    [string]$Target = "Default",
    [ValidateSet("Release", "Debug")]
    [string]$Configuration = "Release",
    [ValidateSet("Quiet", "Minimal", "Normal", "Verbose", "Diagnostic")]
    [string]$Verbosity = "Verbose",
    [switch]$Experimental,
    [Alias("DryRun","Noop")]
    [switch]$WhatIf,
    [switch]$Mono,
    [switch]$SkipToolPackageRestore,
    [Parameter(Position=0,Mandatory=$false,ValueFromRemainingArguments=$true)]
    [string[]]$ScriptArgs
)

[Reflection.Assembly]::LoadWithPartialName("System.Security") | Out-Null
function MD5HashFile([string] $filePath)
{
    if ([string]::IsNullOrEmpty($filePath) -or !(Test-Path $filePath -PathType Leaf))
    {
        return $null
    }

    [System.IO.Stream] $file = $null;
    [System.Security.Cryptography.MD5] $md5 = $null;
    try
    {
        $md5 = [System.Security.Cryptography.MD5]::Create()
        $file = [System.IO.File]::OpenRead($filePath)
        return [System.BitConverter]::ToString($md5.ComputeHash($file))
    }
    finally
    {
        if ($file -ne $null)
        {
            $file.Dispose()
        }
    }
}

Write-Host "Preparing to run build script..."

if(!$PSScriptRoot){
    $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

$TOOLS_DIR = Join-Path $PSScriptRoot "tools"
$NUGET_EXE = Join-Path $TOOLS_DIR "nuget.exe"
$CAKE_EXE = Join-Path $TOOLS_DIR "Cake/Cake.exe"
$NUGET_URL = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
$PACKAGES_CONFIG = Join-Path $TOOLS_DIR "packages.config"
$PACKAGES_CONFIG_MD5 = Join-Path $TOOLS_DIR "packages.config.md5sum"
$TEMPLATE_URL = "https://raw.githubusercontent.com/silverlake-pub/cake-template/master"

# Should we use mono?
$UseMono = "";
if($Mono.IsPresent) {
    Write-Verbose -Message "Using the Mono based scripting engine."
    $UseMono = "-mono"
}

# Should we use the new Roslyn?
$UseExperimental = "";
if($Experimental.IsPresent -and !($Mono.IsPresent)) {
    Write-Verbose -Message "Using experimental version of Roslyn."
    $UseExperimental = "-experimental"
}

# Is this a dry run?
$UseDryRun = "";
if($WhatIf.IsPresent) {
    $UseDryRun = "-dryrun"
}

# Make sure tools folder exists
if ((Test-Path $PSScriptRoot) -and !(Test-Path $TOOLS_DIR)) {
    Write-Verbose -Message "Creating tools directory..."
    New-Item -Path $TOOLS_DIR -Type directory | out-null
}

# Bootstrap cake build files if packages.config doesn't exist
if (!(Test-Path $PACKAGES_CONFIG)) {
    Write-Verbose -Message "Downloading bootstrap files..."
    try
    {
        $webClient = (New-Object System.Net.WebClient);
        $webClient.DownloadFile($TEMPLATE_URL + "/tools/packages.config", $PACKAGES_CONFIG);
        $webClient.DownloadFile($TEMPLATE_URL + "/tools/gitignore.txt", (Join-Path $TOOLS_DIR ".gitignore"));
        $webClient.DownloadFile($TEMPLATE_URL + "/build.ps1", (Join-Path $PSScriptRoot "build.ps1"));
        $bashScriptPath = Join-Path $PSScriptRoot "build.ps1";
        if (!(Test-Path $bashScriptPath)) {
            $webClient.DownloadFile($TEMPLATE_URL + "build.ps1", $bashScriptPath);
        }
    }
    catch
    {
        Write-Error "Could not download bootstrap files."
        throw $_.Exception;
    }
}

# Try download NuGet.exe if not exists
if (!(Test-Path $NUGET_EXE)) {
    Write-Verbose -Message "Downloading NuGet.exe..."
    try {
        (New-Object System.Net.WebClient).DownloadFile($NUGET_URL, $NUGET_EXE)
    } catch {
        Write-Error "Could not download NuGet.exe."
        throw $_.Exception;
    }
}

# Save nuget.exe path to environment to be available to child processed
$ENV:NUGET_EXE = $NUGET_EXE

# Restore tools from NuGet?
if(-Not $SkipToolPackageRestore.IsPresent) {
    Push-Location
    Set-Location $TOOLS_DIR

    # Check for changes in packages.config and remove installed tools if true.
    [string] $md5Hash = MD5HashFile($PACKAGES_CONFIG)
    if((!(Test-Path $PACKAGES_CONFIG_MD5)) -Or
      ($md5Hash -ne (Get-Content $PACKAGES_CONFIG_MD5 ))) {
        Write-Verbose -Message "Missing or changed package.config hash..."
        Remove-Item * -Recurse -Exclude packages.config,nuget.exe
    }

    Write-Verbose -Message "Restoring tools from NuGet..."
    $NuGetOutput = Invoke-Expression "&`"$NUGET_EXE`" install -ExcludeVersion -OutputDirectory `"$TOOLS_DIR`""

    if ($LASTEXITCODE -ne 0) {
        Throw "An error occured while restoring NuGet tools."
    }
    else
    {
        $md5Hash | Out-File $PACKAGES_CONFIG_MD5 -Encoding "ASCII"
    }
    Write-Verbose -Message ($NuGetOutput | out-string)
    Pop-Location
}

# Make sure that Cake has been installed.
if (!(Test-Path $CAKE_EXE)) {
    Throw "Could not find Cake.exe at $CAKE_EXE"
}

# Start Cake
Write-Host "Running build script..."
Invoke-Expression "& `"$CAKE_EXE`" `"$Script`" -target=`"$Target`" -configuration=`"$Configuration`" -verbosity=`"$Verbosity`" $UseMono $UseDryRun $UseExperimental $ScriptArgs"
exit $LASTEXITCODE