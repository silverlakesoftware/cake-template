This repository contains a template for a Cake bootstrap script that runs as deterministically as possible and can self update from this repo.
There are no changes to Cake.  See Additional Information below for the differences in this bootstrap template.

# Setup

See [http://cakebuild.net/docs/tutorials/setting-up-a-new-project](http://cakebuild.net/docs/tutorials/setting-up-a-new-project) 
for complete information.  The only difference here is the URLs for installing the bootstraper.

## Windows
Open a new PowerShell window and run the following command.
```powershell
iwr https://raw.githubusercontent.com/silverlake-pub/cake-template/master/build.ps1 -o build.ps1
```
NOTE: iwr is an alias for Invoke-WebRequest

For PowerShell v2:
```powershell
(New-Object System.Net.WebClient).DownloadString("https://raw.githubusercontent.com/silverlake-pub/cake-template/master/build.ps1") >build.ps1
```

## Linux / OSX
Open a new shell and run the following command.
```bash
curl -Lsfo build.sh https://raw.githubusercontent.com/silverlake-pub/cake-template/master/build.sh
```

# Additional information

This template's goal is to have the build be as close to deterministic as possible and yet be easily updated
at will.  Nuget package downloads can be made deterministic via a local caching server like Proget.

* Nuget.exe is downloaded from the NuGet.CommandLine package (version specified in script).
* NUGET_SOURCE is the package source for any bootstrapped packages and is passed to Cake as CAKE_ROSLYN_NUGETSOURCE by default.
* It includes a .gitignore file to handle the tools folder automatically.
* Deleting tools\packages.config will update all files used from this template repo.
* build.ps1 and build.sh are only updated if they already exist.
* The build.cake file in this repo runs a test of the bootstrap script.
* TEMPLATE_URL can be updated to use a different repo.

# Requirements

## Windows
* The full .NET Framework version of Cake requires .Net 4.5.  Alternatively, you can also use Mono to run on Mac or Linux. 
The official recommended version of Mono is 4.2.3. (See [http://cakebuild.net/docs/overview/requirements](http://cakebuild.net/docs/overview/requirements))
* build.ps1 requires Powershell v2
    * If Powershell is running under the CLR v2 or .Net 4.5 is not installed, then unzip.exe must be checked-in to the
    tools/win32 folder.  A version of unzip.exe is in this repo under info-zip, but is not normally required.
* build.sh requires that unzip.exe be available on the command line.