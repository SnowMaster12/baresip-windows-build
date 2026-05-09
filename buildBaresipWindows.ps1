param(
    [string]$InstallDir = "C:\msys64",
    [string]$WorkDir = "C:\baresip-win-build"
)

$ErrorActionPreference = "Stop"

function Convert-ToMsysPath {
    param([string]$WindowsPath)
    $full = [System.IO.Path]::GetFullPath($WindowsPath)
    $drive = $full.Substring(0, 1).ToLower()
    $rest = $full.Substring(2).Replace('\', '/')
    return "/$drive$rest"
}

Write-Host " Baresip Windows build START"
$InstallerUrl = "https://github.com/msys2/msys2-installer/releases/latest/download/msys2-x86_64-latest.exe"
$InstallerPath = "$env:TEMP\msys2-x86_64-latest.exe"

if (!(Test-Path $InstallDir)) {
    Write-Host " MSYS2 not found. Downloading installer..."
    Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath

    Write-Host " Installing MSYS2 into $InstallDir"
    Start-Process -FilePath $InstallerPath -ArgumentList @(
        "/VERYSILENT",
        "/SUPPRESSMSGBOXES",
        "/NORESTART",
        "/DIR=$InstallDir"
    ) -Wait
} else {
    Write-Host " MSYS2 already installed at $InstallDir"
}

$Bash = Join-Path $InstallDir "usr\bin\bash.exe"
if (!(Test-Path $Bash)) {
    throw "bash.exe not found at $Bash"
}

New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null

$MsysWorkDir = Convert-ToMsysPath $WorkDir

$BuildScript = @'
#!/usr/bin/env bash
set -euo pipefail

export MSYSTEM=UCRT64
export PATH="/ucrt64/bin:/usr/bin:$PATH"

echo "Running inside MSYS2 UCRT64"
echo "MSYSTEM=$MSYSTEM"
echo "HOME=$HOME"

echo "Updating pacman database"
pacman -Sy --noconfirm

echo "Installing dependencies"
pacman -S --needed --noconfirm \
  git \
  mingw-w64-ucrt-x86_64-toolchain \
  mingw-w64-ucrt-x86_64-cmake \
  mingw-w64-ucrt-x86_64-ninja \
  mingw-w64-ucrt-x86_64-openssl \
  mingw-w64-ucrt-x86_64-pkgconf

WORKDIR="__WORKDIR__"
INSTALL_PREFIX="/ucrt64"

mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "Workdir -> $WORKDIR"

if [[ ! -d re ]]; then
  echo " Cloning libre/re"
  git clone https://github.com/baresip/re.git
else
  echo "Updating libre/re"
  git -C re pull --ff-only || true
fi

echo " Building libre/re"
cd "$WORKDIR/re"

rm -rf build

cmake -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX"

cmake --build build
cmake --install build

cd "$WORKDIR"

if [[ ! -d baresip ]]; then
  echo " Cloning baresip"
  git clone https://github.com/baresip/baresip.git
else
  echo " Updating baresip"
  git -C baresip pull --ff-only || true
fi

echo "Building baresip"
cd "$WORKDIR/baresip"

rm -rf build

cmake -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_PREFIX_PATH="$INSTALL_PREFIX" \
  -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
  -DSTATIC=ON \
  -DMODULES="account;menu;stdio;wincons;g711;wasapi;srtp;stun;turn;ice;uuid;netroam;vumeter"

cmake --build build
cmake --install build

echo "Creating baresip runtime config"

CONFIG_DIR="$HOME/.baresip"
mkdir -p "$CONFIG_DIR"

CONFIG_FILE="$CONFIG_DIR/config"
ACCOUNTS_FILE="$CONFIG_DIR/accounts"
CONTACTS_FILE="$CONFIG_DIR/contacts"

cat > "$CONFIG_FILE" <<EOF
poll_method          select
sip_transports       udp,tcp,tls

module               account.dll
module               menu.dll
module               stdio.dll
module               wincons.dll

module               g711.dll
module               wasapi.dll
module               srtp.dll
module               stun.dll
module               turn.dll
module               ice.dll
module               uuid.dll
module               netroam.dll
module               vumeter.dll

audio_player         wasapi,default
audio_source         wasapi,default
audio_alert          wasapi,default

call_local_timeout   5
call_max_calls       4
call_hold_other_calls yes
call_transfer        yes

rtcp_enable          yes
avpf                 yes
EOF

if [[ ! -f "$ACCOUNTS_FILE" ]]; then
  cat > "$ACCOUNTS_FILE" <<'EOF'
# Add your SIP account here.
#
# Example:
# <sip:username@sip.example.com;transport=udp>;auth_pass=your_password;call_transfer=yes
#
# Linphone example:
# <sip:your_user@sip.linphone.org;transport=udp>;auth_pass=your_password;call_transfer=yes
EOF
  echo "Created accounts template"
else
  echo "Existing accounts file found"
fi

touch "$CONTACTS_FILE"

echo ""
echo " Runtime config ready:"
echo "  $CONFIG_FILE"
echo "  $ACCOUNTS_FILE"
echo "  $CONTACTS_FILE"

echo ""
echo " Config content:"
cat "$CONFIG_FILE"

echo ""
echo " Accounts file:"
echo "  $ACCOUNTS_FILE"
echo ""
echo "Edit it with:"
echo "  nano ~/.baresip/accounts"
echo ""
echo "Or open the folder from MSYS2 with:"
echo "  explorer.exe \"\$(cygpath -w ~/.baresip)\""

echo ""
echo " Build completed"
echo "Baresip binary:"
echo "  $WORKDIR/baresip/build/baresip.exe"
echo ""
echo "Installed binary:"
echo "  /ucrt64/bin/baresip.exe"
echo ""
echo "Run from MSYS2 UCRT64:"
echo "  baresip.exe -f ~/.baresip"
'@

$BuildScript = $BuildScript.Replace("__WORKDIR__", $MsysWorkDir)

$BuildScriptPath = Join-Path $WorkDir "build_baresip_inside_msys2.sh"
Set-Content -Path $BuildScriptPath -Value $BuildScript -Encoding UTF8

$MsysBuildScriptPath = Convert-ToMsysPath $BuildScriptPath

Write-Host " Starting MSYS2 build"
& $Bash -lc "bash '$MsysBuildScriptPath'"

if ($LASTEXITCODE -ne 0) {
    throw "MSYS2 build failed with exit code $LASTEXITCODE"
}

Write-Host "Baresip binary:"
Write-Host "$InstallDir\ucrt64\bin\baresip.exe"

Write-Host "Baresip config:"
Write-Host "$InstallDir\home\$env:USERNAME\.baresip\config"
Write-Host "$InstallDir\home\$env:USERNAME\.baresip\accounts"

Write-Host "Edit account from MSYS2 UCRT64:"
Write-Host "nano ~/.baresip/accounts"

Write-Host "Run from MSYS2 UCRT64:"
Write-Host "baresip.exe -f ~/.baresip"