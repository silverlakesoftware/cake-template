#!/usr/bin/env bash

##########################################################################
# This is the Cake bootstrapper script for Linux and OS X.
# This file was downloaded from https://github.com/silverlake-pub/cake-template
# Feel free to change this file to fit your needs.
##########################################################################

# Define sources.
if [ -z $NUGET_SOURCE ]; then
    NUGET_SOURCE="https://www.nuget.org/api/v2"
fi
NUGET_VERSION="3.5.0"
TEMPLATE_URL="https://raw.githubusercontent.com/silverlake-pub/cake-template/master"

# Define directories.
SCRIPT_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
TOOLS_DIR=$SCRIPT_DIR/tools
NUGET_EXE=$TOOLS_DIR/nuget.exe
CAKE_EXE=$TOOLS_DIR/Cake/Cake.exe
PACKAGES_CONFIG=$TOOLS_DIR/packages.config
PACKAGES_CONFIG_MD5=$TOOLS_DIR/packages.config.md5sum

# Define md5sum or md5 depending on Linux/OSX
MD5_EXE=
if [[ "$(uname -s)" == "Darwin" ]]; then
    MD5_EXE="md5 -r"
else
    MD5_EXE="md5sum"
fi

# Define default arguments.
SCRIPT="build.cake"
TARGET="Default"
CONFIGURATION="Release"
VERBOSITY="verbose"
DRYRUN=
SHOW_VERSION=false
SCRIPT_ARGUMENTS=()

# Parse arguments.
for i in "$@"; do
    case $1 in
        -s|--script) SCRIPT="$2"; shift ;;
        -t|--target) TARGET="$2"; shift ;;
        -c|--configuration) CONFIGURATION="$2"; shift ;;
        -v|--verbosity) VERBOSITY="$2"; shift ;;
        -d|--dryrun) DRYRUN="-dryrun" ;;
        --version) SHOW_VERSION=true ;;
        --) shift; SCRIPT_ARGUMENTS+=("$@"); break ;;
        *) SCRIPT_ARGUMENTS+=("$1") ;;
    esac
    shift
done

# Make sure the tools folder exist.
if [ ! -d "$TOOLS_DIR" ]; then
  mkdir "$TOOLS_DIR"
fi

# Bootstrap cake build files if packages.config doesn't exist
if [ ! -f "$TOOLS_DIR/packages.config" ]; then
    echo "Downloading bootstrap files..."
    scriptHash=$($MD5_EXE "build.sh")
    curl -Lsfo "$TOOLS_DIR/packages.config" "$TEMPLATE_URL/tools/packages.config"
    curl -Lsfo "$TOOLS_DIR/.gitignore" "$TEMPLATE_URL/tools/.gitignore"
    curl -Lsfo "build.sh" "$TEMPLATE_URL/build.sh"
    if [ -f "build.ps1" ]; then
        curl -Lsfo "build.ps1" "$TEMPLATE_URL/build.ps1"
    fi
    if [ $? -ne 0 ]; then
        echo "An error occured while downloading boostrap files."
        exit 1
    fi
    if [ "$scriptHash" != "$($MD5_EXE "build.sh")" ]; then
        echo "The build script has updated please run again."
        exit 2
    fi
fi

# Download NuGet if it does not exist.
if [ ! -f "$NUGET_EXE" ]; then
    echo "Downloading NuGet.CommandLine.$NUGET_VERSION package for NuGet.exe..."
    nugetPackagePath="$TOOLS_DIR/nuget.commandline.$NUGET_VERSION.zip"
    curl -Lsfo "$nugetPackagePath" "$NUGET_SOURCE/package/NuGet.CommandLine/$NUGET_VERSION"
    unzip -j -C -q "$nugetPackagePath" "tools/nuget.exe" -d "tools"
    rm $nugetPackagePath
    if [ $? -ne 0 ]; then
        echo "An error occured while downloading Nuget.CommandLine package and extracting nuget.exe."
        exit 1
    fi
fi

# Restore tools from NuGet.
pushd "$TOOLS_DIR" >/dev/null
if [ ! -f "$PACKAGES_CONFIG_MD5" ] || [ "$( cat "$PACKAGES_CONFIG_MD5" | sed 's/\r$//' )" != "$( $MD5_EXE "$PACKAGES_CONFIG" | awk '{ print $1 }' )" ]; then
    find . -type d ! -name . | xargs rm -rf
fi

mono "$NUGET_EXE" install -ExcludeVersion
if [ $? -ne 0 ]; then
    echo "Could not restore NuGet packages."
    exit 1
fi

$MD5_EXE "$PACKAGES_CONFIG" | awk '{ print $1 }' >| "$PACKAGES_CONFIG_MD5"

popd >/dev/null

# Make sure that Cake has been installed.
if [ ! -f "$CAKE_EXE" ]; then
    echo "Could not find Cake.exe at '$CAKE_EXE'."
    exit 1
fi

# Start Cake
if $SHOW_VERSION; then
    exec mono "$CAKE_EXE" -version
else
    exec mono "$CAKE_EXE" $SCRIPT -verbosity=$VERBOSITY -configuration=$CONFIGURATION -target=$TARGET $DRYRUN "${SCRIPT_ARGUMENTS[@]}"
fi