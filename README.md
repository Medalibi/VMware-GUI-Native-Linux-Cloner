# VMware-GUI-Native-Linux-Cloner
A PowerShell script that help with the Native Linux VM deployment (Ubuntu) on a VMware Horizon environment.

This script should be preffably executed via the VMware vSphere PowerCLI Terminal (Been Tested on VMware vSphere PowerCLI 5.8 Release1).

There is a lot of personilized entries that has been filled in for the original environment. They maybe need to be updated to reflect alternative setup.

The Script also support other operations we found very usuful when runnign VMware Horizon pool:
1) Power On
2) Power Off
3) Shut VM Guest
4) Restart VM
5) Restart VM Guest
6) Delete VM
7) Add GPU PCI Device
8) Install Horizon Agent
9) Add Network Card
10) Connect Network Card
11) Get VM IP Address
12) Set Linux VM Hostname
13) Install Nvidia Driver on Linux VM
14) Migrate VMs equally between Hosts
15) Clone VMs for an Inactive pool
16) Remove GPU from VM
17) Run a Linux Command

#Usage

1) Fill in the Form 
Mainly: the Clones Name and Accept the licence. This does enable teh execution of most of the operations. To do a deployment, all the field must be filled and a Horizon Agnet must be selected.

2) Click the Deployemtn button or click the Operation button and choose an option.

3) Wait for it to finish
You can watch the script working on the PowerCLI screen or in the application display output text, also you can alwsy open the logfile. 

PS: Our timing for a propper deplyment of 32 VMs was done in 32min.

#Contact
alibi@ebi.ac.uk
alibimohamed@gmail.com
