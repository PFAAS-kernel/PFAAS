[CmdletBinding()]
param(
    [string]$Distribution = 'Ubuntu-24.04',
    [string]$LinuxProjectDir = '~/pfaas'
)

$ErrorActionPreference = 'Stop'
$source = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$portableSource = $source.Replace('\', '/')
$wslSourceOutput = wsl.exe -d $Distribution -- wslpath -a -u $portableSource
$wslSource = ($wslSourceOutput | Select-Object -Last 1).Trim()
if (-not $wslSource) { throw 'Could not translate the Windows source path for WSL.' }
$processor = Get-CimInstance Win32_Processor | Select-Object -First 1
$firmwareVirtualization = [string]$processor.VirtualizationFirmwareEnabled
$hypervisorPresent = [string](Get-CimInstance Win32_ComputerSystem).HypervisorPresent

wsl.exe -d $Distribution -- bash -lc "dpkg-query -W build-essential llvm-dev clang lld qemu-system-x86 qemu-utils python3-venv libelf-dev >/dev/null 2>&1"
if ($LASTEXITCODE -ne 0) {
    wsl.exe -d $Distribution -u root -- bash -lc "set -euo pipefail; cd '$wslSource'; bash scripts/bootstrap-linux.sh --packages-only"
    if ($LASTEXITCODE -ne 0) { throw "Linux package installation failed (exit $LASTEXITCODE)" }
}

$linuxUser = (wsl.exe -d $Distribution -- id -un | Select-Object -Last 1).Trim()
wsl.exe -d $Distribution -- test -e /dev/kvm
if ($LASTEXITCODE -eq 0) {
    $groupNames = (wsl.exe -d $Distribution -- id -nG) -join ' '
    if (($groupNames -split '\s+') -notcontains 'kvm') {
        wsl.exe -d $Distribution -u root -- usermod -aG kvm $linuxUser
        if ($LASTEXITCODE -ne 0) { throw "Could not grant $linuxUser access to /dev/kvm" }
    }
}

wsl.exe -d $Distribution -- bash -lc "set -euo pipefail; mkdir -p $LinuxProjectDir; rsync -a --delete --exclude .git/ --exclude build/ --exclude verification/ --exclude unikernel-baseline/unikraft/ --exclude linux-baseline/buildroot/ '$wslSource/' $LinuxProjectDir/; cd $LinuxProjectDir; chmod +x scripts/*.sh tools/*/*.py; PFAAS_SKIP_PACKAGES=1 PFAAS_FIRMWARE_VIRT='$firmwareVirtualization' PFAAS_HYPERVISOR_PRESENT='$hypervisorPresent' ./scripts/bootstrap-linux.sh"
if ($LASTEXITCODE -ne 0) { throw "Linux bootstrap failed with exit code $LASTEXITCODE" }

Write-Host "Desired-state bootstrap complete. Authoritative Linux checkout: $LinuxProjectDir"
