This repository contains a template for a Cake bootstrap script that can self update from this repo.

# Setup

See [http://cakebuild.net/docs/tutorials/setting-up-a-new-project](http://cakebuild.net/docs/tutorials/setting-up-a-new-project) 
for complete information.  The only difference here is the URLs for installing the bootstraper.

## Windows
Open a new PowerShell window and run the following command.
```powershell
Invoke-WebRequest https://raw.githubusercontent.com/silverlake-pub/cake-template/master/build.ps1 -OutFile build.ps1
```

## Linux / OSX
Open a new shell and run the following command.
```bash
curl -Lsfo build.sh https://raw.githubusercontent.com/silverlake-pub/cake-template/master/build.sh
```

# Additional information

This template's goal is to have the build be as close to deterministic as possible and yet be easily updated
at will.  Nuget package downloads can be made deterministic via a local caching server like Proget.

* It includes a .gitignore file to handle the tools folder automatically.
* Nuget.exe is always run locally and kept in version control.
* Deleting tools\packages.config will update all files used from this template repo.
* Deleting tools\nuget.exe will update nuget.exe (to latest from nuget.org).
* Deleting the tools folder completely will update everything.
* build.ps1 and build.sh are only updated if they already exist.
* The build.cake file in this repo runs a test of the powershell bootstrap script.
* TEMPLATE_URL can be updated to use a different repo.