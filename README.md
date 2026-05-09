# Baresip Windows Build Script

This repository contains a PowerShell script to install, build, and configure **baresip** on Windows using **MSYS2 UCRT64**.

The script automates:

- MSYS2 installation, if missing
- required dependency installation
- `re` build
- `baresip` build
- baresip runtime configuration
- `.baresip` folder creation
- `config`, `accounts`, and `contacts` file creation

The build is performed in **static mode**, which is the recommended setup for this Windows/MSYS2 flow.

---

## Requirements

Operating system:

```text
Windows 10 / Windows 11
```
You only need PowerShell and MSYS2 does not need to be installed manually.
If it is missing, the script downloads and installs it into: **C:\msys64**

## What the script does
1. Checks whether MSYS2 is installed.
2. Downloads and installs MSYS2 if it is missing.
3. Starts an MSYS2 UCRT64 shell.
4. Installs the required packages:
    git
    cmake
    ninja
    MinGW UCRT64 toolchain
    OpenSSL
    pkg-config
5. Clones and builds re.
6. Clones and builds baresip.
7. Installs baresip.exe into: **C:\msys64\ucrt64\bin\baresip.exe**

## Important paths
After the build, baresip is available at: **C:\msys64\ucrt64\bin\baresip.exe** 

From MSYS2 UCRT64: **/ucrt64/bin/baresip.exe**

## Runtime configuration folder
The runtime configuration is created in: **C:\msys64\home\<user>\.baresip**

## Main files
Inside .baresip you can find:
1. config gile
2. accounts file
3. contacts file

## Running the script

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\buildBaresipWindows.ps1
```
By default, the script uses:

```powershell
InstallDir: C:\msys64
WorkDir: C:\baresip-win-build
```
