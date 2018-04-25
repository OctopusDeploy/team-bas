$virtualMachineName = "DemoVM"
$virtualMachineRam = 8GB
$virtualMachineHardDriveSize = 80GB
$virtualMachineVhdLocation = "C:\VHDs"
$virtualMachineVhd = $virtualMachineVhdLocation + "\$virtualMachineName.vhdx"
$isoLocation = "C:\ISOs\Windows10.iso"
$virtualMachineNetworkSwitch = "DemoSwitch1"

# Create the path for the VHD
if ((test-path $virtualMachineVhdLocation) -eq $false)
{
    New-Item $virtualMachineVhdLocation -ItemType Directory
}

# Create the network switch for the VM
$testSwitch = Get-VMSwitch -Name $virtualMachineNetworkSwitch -ErrorAction SilentlyContinue; if ($testSwitch.Count -EQ 0){New-VMSwitch -Name $virtualMachineNetworkSwitch -SwitchType Private}

New-VM -Name $virtualMachineName -Path $virtualMachineVhdLocation -MemoryStartupBytes $virtualMachineRam -NewVHDPath $virtualMachineVhd -NewVHDSizeBytes $virtualMachineHardDriveSize -SwitchName $virtualMachineNetworkSwitch

Set-VMDvdDrive -VMName $virtualMachineName -Path $isoLocation

Start-VM $virtualMachineName