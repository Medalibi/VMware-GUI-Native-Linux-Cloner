function add-uniquepcipassthroughdevice {

[cmdletbinding()]

param (

[Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$vm,

[Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$pciid,

[Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()][string]$vmhost

)

$vmhostview= get-view -viewtype hostsystem -filter @{'name'=$vmhost}

$vendorid = ($vmhostview.hardware.pcidevice |?{$_.id -eq $pciid}).vendorid

$deviceid = ($vmhostview.hardware.pcidevice |?{$_.id -eq $pciid}).deviceid

$devicename = ($vmhostview.hardware.pcidevice |?{$_.id -eq $pciid}).devicename

$systemid = (get-esxcli -vmhost $vmhost).system.uuid.get()  

$deviceid = "{0:X4}" -f $deviceid

$vmv = Get-VM $vm 

 $spec = New-Object VMware.Vim.VirtualMachineConfigSpec

 $spec.deviceChange  = New-Object VMware.Vim.VirtualDeviceConfigSpec

 $spec.deviceChange[0].Operation = New-Object VMware.Vim.VirtualDeviceConfigSpecOperation

 $spec.deviceChange[0].Operation = 'add'

 $spec.deviceChange[0].device = New-Object VMware.Vim.VirtualPCIPassthrough

 $spec.deviceChange[0].device.key = -100

 $spec.deviceChange[0].Device.DeviceInfo = New-Object VMware.Vim.Description

 $spec.deviceChange[0].Device.DeviceInfo.label = 'PCI device 0'

 $spec.deviceChange[0].Device.Backing = new-object vmware.vim.VirtualPCIPassthroughDeviceBackingInfo

 $spec.deviceChange[0].Device.Backing.devicename = $devicename

 $spec.deviceChange[0].Device.Backing.id = $pciid

 $spec.deviceChange[0].Device.Backing.deviceId = $deviceid #"0ff2" 

 $spec.deviceChange[0].Device.Backing.systemId = $systemid  

 $spec.deviceChange[0].Device.Backing.vendorId = $vendorid

 $spec.devicechange[0].Device.DeviceInfo.Summary = ''

 $vmobj = $vmv | Get-View 

  $vmobj.ReconfigVM_Task($spec)

  }
