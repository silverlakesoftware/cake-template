##########################################################################
# This is the Cake bootstrapper script for PowerShell.
# This file was downloaded from https://github.com/silverlake-pub/cake-template
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

# Define sources
$NUGET_SOURCE = if ($env:NUGET_SOURCE -eq $null) { "https://www.nuget.org/api/v2" } else { $env:NUGET_SOURCE }
$NUGET_VERSION = "3.5.0"
$TEMPLATE_URL = "https://raw.githubusercontent.com/silverlake-pub/cake-template/dev"

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

# Sources:
# https://serverfault.com/a/201604
# https://msdn.microsoft.com/en-us/library/ms723202(v=vs.85).aspx
# https://gallery.technet.microsoft.com/scriptcenter/PowerShell-Get-Specific-9b35352f
# https://stackoverflow.com/a/21551647/287602
function UnzipTools([string] $filePath, [string] $destPath)
{
    Write-Verbose -Message ("Unzipping tools folder from " + $filePath + " to " + $destPath)
    $shell_app=new-object -com shell.application
    $zip_file = $shell_app.namespace($filePath)
    $destination = $shell_app.namespace($destPath)
    foreach($item in $zip_file.items()) 
    { 
        if ($item.name -eq "tools") 
        {
             $destination.Copyhere($item.GetFolder.items(),4+8+16+512+1024)
        }
    }
}

# Sources:
# http://stackoverflow.com/a/19132572/287602
function SwitchToCRLFLineEndings([string] $filePath)
{
    $text = [IO.File]::ReadAllText($filePath) -replace "`r`n", "`n"
    $text = $text -replace "`n", "`r`n"
    [IO.File]::WriteAllText($filePath, $text)
}

Write-Host "Preparing to run build script..."

if(!$PSScriptRoot){
    $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

$TOOLS_DIR = Join-Path $PSScriptRoot "tools"
$NUGET_EXE = Join-Path $TOOLS_DIR "nuget.exe"
$CAKE_EXE = Join-Path $TOOLS_DIR "Cake/Cake.exe"
$PACKAGES_CONFIG = Join-Path $TOOLS_DIR "packages.config"
$PACKAGES_CONFIG_MD5 = Join-Path $TOOLS_DIR "packages.config.md5sum"

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
        $thisScriptPath = (Join-Path $PSScriptRoot "build.ps1")
        $thisScriptHash = MD5HashFile $thisScriptPath
        $webClient = (New-Object System.Net.WebClient);
        $webClient.DownloadFile($TEMPLATE_URL + "/tools/packages.config", $PACKAGES_CONFIG);
        SwitchToCRLFLineEndings $PACKAGES_CONFIG
        $gitIgnorePath = Join-Path $TOOLS_DIR ".gitignore";
        $webClient.DownloadFile($TEMPLATE_URL + "/tools/.gitignore", $gitIgnorePath);
        SwitchToCRLFLineEndings $gitIgnorePath
        #$webClient.DownloadFile($TEMPLATE_URL + "/build.ps1", $thisScriptPath);
        $preSwitchHash = MD5HashFile $thisScriptPath
        SwitchToCRLFLineEndings $thisScriptPath
        $bashScriptPath = Join-Path $PSScriptRoot "build.sh";
        if (Test-Path $bashScriptPath)
        {
            $webClient.DownloadFile($TEMPLATE_URL + "/build.sh", $bashScriptPath);
            SwitchToCRLFLineEndings $bashScriptPath
        }
        if ($thisScriptHash -ne (MD5HashFile $thisScriptPath) -and $thisScriptHash -ne $preSwitchHash)
        {
            Write-Host "The build script has updated please run again."
            exit
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
    Write-Verbose -Message ("Downloading NuGet.CommandLine." + $NUGET_VERSION + " package for NuGet.exe")
    try {
        $nugetPackagePath = Join-Path $TOOLS_DIR ("nuget.commandline." + $NUGET_VERSION + ".zip");
        $nugetPackageUrl = $NUGET_SOURCE + "/package/NuGet.CommandLine/" + $NUGET_VERSION;
        (New-Object System.Net.WebClient).DownloadFile($nugetPackageUrl, $nugetPackagePath);
        UnzipTools $nugetPackagePath $TOOLS_DIR;
        Remove-item $nugetPackagePath
    } catch {
        Write-Error "Could not download Nuget.CommandLine package and extract NuGet.exe."
        throw $_.Exception;
    }
}

# Save nuget.exe path to environment to be available to child processes
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
        Remove-Item * -Recurse -Exclude .gitignore,packages.config,nuget.exe
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