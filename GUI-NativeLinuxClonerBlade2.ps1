####################################################################
# This a GUI for Native Linux pool deployemtn using PowerShell/PowerCLI
# with VMware Horizon
#
#
####################################################################

####################  Form Initialisation  #######################

[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")  #loading the necessary .net libraries (using void to suppress output)

$Form = New-Object System.Windows.Forms.Form                                      #creating the form (this will be the "primary" window)
$Form.Size = New-Object System.Drawing.Size(1000,1100)                            #the size in px of the window length, height
$Form.AutoScaleDimensions = New-Object System.Drawing.SizeF(6, 13)
$Form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Font
$Form.AutoSize = $True
$Form.StartPosition = "CenterScreen"                                              #loads the window in the center of the screen
#$Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedToolWindow  #Make the window border fixed
$Form.Text = "VMWare Horizon Native Linux Pool Deployment Room 2 Wizzard (ESXi Blade2)"                #window description
#$form.Topmost = $True
$form.DataBindings.DefaultDataSourceUpdateMode = [System.Windows.Forms.DataSourceUpdateMode]::OnValidation
$Icon = [system.drawing.icon]::ExtractAssociatedIcon($PSHOME + "\powershell.exe")
$Form.Icon = $Icon

########################  functions  ############################

# Var init
. .\passtest.ps1

##C:\Scripts\VMware-GUI-Native-Linux-Cloner\Initialize-PowerCLIEnvironment.ps1

$global:agentInstaller = ""
[bool]$global:vmop = $false

# Message Dialogue function
function Read-MessageBoxDialog([string]$Message, [string]$WindowTitle, [System.Windows.Forms.MessageBoxButtons]$Buttons =
[System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]$Icon = [System.Windows.Forms.MessageBoxIcon]::None)
{
    Add-Type -AssemblyName System.Windows.Forms
    return [System.Windows.Forms.MessageBox]::Show($Message, $WindowTitle, $Buttons, $Icon)
}

# Check if the VM exist
function IsVMExists ()
{
    Param($VMExists)
	Write-Host -ForeGroundColor Green "[INFO] Checking if the VM $VMExists already Exists"
    $outputBox.AppendText("Checking if the VM $VMExists already Exists`r`n")
	[bool]$Exists = $false

	#Get all VMS and check if the VMs is already present in VC
	$listvm = Get-vm
	foreach ($lvm in $listvm)
	{
		if($VMExists -eq $lvm.Name )
		{
			$Exists = $true
		}
	}
	return $Exists
}

# Delete VM
function Delete_VM()
{
    Param($VMToDelete)
	Write-Host -ForeGroundColor Yellow "[DEBUG] Deleting VM $VMToDelete ..."
    $outputBox.AppendText("Deleting VM $VMToDelete ...`r`n")
	Get-VM $VMToDelete | where { $_.PowerState –eq "PoweredOn" } | Stop-VM –confirm:$false
	Get-VM $VMToDelete | Remove-VM –DeleteFromDisk –confirm:$false
}

# Check SSH Client
function Check_SSH_Client
{
    Param($IsPlink, $IsPSCP)
    if ($IsPlink)
    {
        if (Test-Path ".\plink.exe")
        {
          write-host  -ForeGroundColor Green '[INFO] SSH client "plink.exe" found'
          $outputBox.AppendText("[INFO] SSH client plink.exe found`r`n")
        }
        else
        {
          write-host  -ForeGroundColor Red '[ERROR] SSH client "plink.exe" not found, please download from its official web site'
          $outputBox.AppendText("[ERROR] SSH client plink.exe not found, please download from its official web site`r`n")
          exit
        }
    }
    if ($IsPSCP)
    {
        if (Test-Path ".\pscp.exe")
        {
          write-host  -ForeGroundColor Green '[INFO] SSH client "pscp.exe" found'
          $outputBox.AppendText("[INFO] SSH client pscp.exe found`r`n")
        }
        else
        {
          write-host  -ForeGroundColor Red '[ERROR] SSH client "pscp.exe" not found, please download from its official web site'
          $outputBox.AppendText("[ERROR] SSH client pscp.exe not found, please download from its official web site`r`n")
          exit
        }
    }
}

# Run a command via SSH
function RunCmdViaSSH
{
    Param($VM_Name, $User, $Password, $Cmd, $returnOutput = $false)

    $VM= Get-VM $VM_Name
    $IP = $VM.guest.IPAddress[0]
    write-host -ForeGroundColor Green "[INFO] Run cmd on $VM_Name ($IP)"
    $outputBox.AppendText("Run cmd on $VM_Name ($IP)`r`n")
    if($returnOutput)
    {
        $command = "echo yes | .\plink.exe -ssh -l -t $user -pw $password $IP " + '"' + $cmd +'"'
        $output = Invoke-Expression $command
        return $output
    }
    else
    {
        echo yes | .\plink.exe -ssh -l $user -pw $password $IP "$cmd"
    }

}

# Upload files using SSH/SCP
function UploadFileViaSSH
{
    Param($VM_Name, $User, $Password, $LocalPath, $DestPath)

    $VM= Get-VM $VM_Name
    $IP = $VM.guest.IPAddress[0]
    $command = "echo yes | .\pscp.exe -l $User -pw $Password $LocalPath $IP" + ":" + "$DestPath"
    write-host -ForeGroundColor Green "[INFO] Uploading VMware Horizon agent related files"
    $outputBox.AppendText("Uploading VMware Horizon agent related files`r`n")
    Invoke-Expression $command
}

# Open File Dialog box
function Read-OpenFileDialog([string]$WindowTitle, [string]$InitialDirectory, [string]$Filter = "All files (*.*)|*.*", [switch]$AllowMultiSelect)
{
    Add-Type -AssemblyName System.Windows.Forms
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Title = $WindowTitle
    if (![string]::IsNullOrWhiteSpace($InitialDirectory)) { $openFileDialog.InitialDirectory = $InitialDirectory }
    $openFileDialog.Filter = $Filter
    if ($AllowMultiSelect) { $openFileDialog.MultiSelect = $true }
    $openFileDialog.ShowHelp = $true    # Without this line the ShowDialog() function may hang depending on system configuration and running from console vs. ISE.
    $openFileDialog.ShowDialog() > $null
    if ($AllowMultiSelect) { return $openFileDialog.Filenames } else { return $openFileDialog.Filename }
}
# Disable VM console
function Disable_VM_Console()
{
    Param($VMToDisableConsole)
    $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
    $extra = New-Object VMware.Vim.optionvalue
    $extra.Key="RemoteDisplay.maxConnections"
    $extra.Value="0"
    $vmConfigSpec.extraconfig += $extra
    $vm = Get-VM $VMToDisableConsole | Get-View
    $vm.ReconfigVM($vmConfigSpec)
}

# Logfile creator
Function LogWrite
{
    Param ([string]$logstring)
    Add-content $global:Logfile -value $logstring
}

########################  Text Field  ###########################

# Welcome label
$wel_label = New-Object system.Windows.Forms.Label
$wel_label.text = "Automated Native Linux pool deployment using a master VM snapshot. Please fill in the form and accept the EULA licence before proceeding."
$wel_label.Location = New-Object System.Drawing.Size(20,15)
$wel_label.Font = New-Object System.Drawing.Font("Calibri",12,[System.Drawing.FontStyle]::Regular)
$wel_label.Autosize = $True
$form.controls.add($wel_label)

# EULA Licence Group Box
$EULA_groupBox = New-Object System.Windows.Forms.GroupBox
$EULA_groupBox.Autosize = $True
$EULA_groupBox.Location = New-Object System.Drawing.Size(20,45)
$EULA_groupBox.size = New-Object System.Drawing.Size(260,50)
$EULA_groupBox.text = "Linux Horizon Agent EULA Licence"
$EULA_groupBox.Font = New-Object System.Drawing.Font("Tahoma",10,[System.Drawing.FontStyle]::Bold)
$Form.Controls.Add($EULA_groupBox)

#EULA Licence check box
$EULA_checkbox = New-Object System.Windows.Forms.CheckBox
$EULA_checkbox.AutoSize = $True
$EULA_checkbox.Location = New-Object System.Drawing.Point(15,27)
$EULA_checkbox.Name = "Accept EULA"
$EULA_checkbox.TabIndex = 0
$EULA_checkbox.Text = "Accept EULA Licence"
$EULA_checkbox.UseVisualStyleBackColor = $True
$EULA_groupBox.Controls.Add($EULA_checkbox)

# Cloning Type GroupBox
$type_groupBox = New-Object System.Windows.Forms.GroupBox
$type_groupBox.Autosize = $True
$type_groupBox.Location = New-Object System.Drawing.Size(300,45)
$type_groupBox.size = New-Object System.Drawing.Size(140,50)
$type_groupBox.text = "Cloning Type"
$type_groupBox.Font = New-Object System.Drawing.Font("Tahoma",10,[System.Drawing.FontStyle]::Bold)
$Form.Controls.Add($type_groupBox)

# Cloning Type dropbox
$Type_DropDownBox = New-Object System.Windows.Forms.ComboBox
$Type_DropDownBox.Location = New-Object System.Drawing.Size(15,25)
$Type_DropDownBox.Size = New-Object System.Drawing.Size(80,20)
$Type_DropDownBox.TabIndex = 1
$Type_DropDownBox.SelectedText = "linked"
#$Type_DropDownBox.SelectedItem = $wksList.Items[0]
$type_groupBox.Controls.Add($Type_DropDownBox)
$wksList=@("linked","full")
foreach ($ClnTyp in $wksList) {
                      $Type_DropDownBox.Items.Add($ClnTyp)
                              } #end foreach
$Type_DropDownBox.SelectedItem = $wksList[0]

# VMName GroupBox
$VMName_groupBox = New-Object System.Windows.Forms.GroupBox
$VMName_groupBox.Autosize = $True
$VMName_groupBox.Location = New-Object System.Drawing.Size(460,45)
$VMName_groupBox.size = New-Object System.Drawing.Size(180,50)
$VMName_groupBox.text = "Clones VMs Name"
$VMName_groupBox.Font = New-Object System.Drawing.Font("Tahoma",10,[System.Drawing.FontStyle]::Bold)
$Form.Controls.Add($VMName_groupBox)

# VMName inputbox
$VMName_InputBox = New-Object System.Windows.Forms.TextBox
$VMName_InputBox.Location = New-Object System.Drawing.Size(15,25)
$VMName_InputBox.Size = New-Object System.Drawing.Size(150,50)
$VMName_InputBox.TabIndex = 2
$VMName_InputBox.AutoCompleteCustomSource.AddRange(("EMBOMetagenomicVM", "IntroNGSVM", "DataVisialVM", "EMBOMetabolomicsVM", "GenomicMedVM", "PrimersVM", "IntegrativeOmicsVM",
        "ubuntu1404VM", "ProteomicsVM", "BioExcelVM", "GenMedVM", "IntOmicsVM", "OmicsVM", "WTACVM", "IncilicoVM", "SteamCellVM", "TestVM", "LinuxTestVM", "UbuntuVM"));
$VMName_InputBox.AutoCompleteMode = [System.Windows.Forms.AutoCompleteMode]::SuggestAppend;
$VMName_InputBox.AutoCompleteSource = [System.Windows.Forms.AutoCompleteSource]::CustomSource;
$VMName_groupBox.Controls.Add($VMName_InputBox)

# Parent VMName GroupBox
$Par_VMName_groupBox = New-Object System.Windows.Forms.GroupBox
$Par_VMName_groupBox.Autosize = $True
$Par_VMName_groupBox.Location = New-Object System.Drawing.Size(660,45)
$Par_VMName_groupBox.size = New-Object System.Drawing.Size(180,50)
$Par_VMName_groupBox.text = "Parent VM Name"
$Par_VMName_groupBox.Font = New-Object System.Drawing.Font("Tahoma",10,[System.Drawing.FontStyle]::Bold)
$Form.Controls.Add($Par_VMName_groupBox)

# Parent VMName inputbox
$Par_VMName_InputBox = New-Object System.Windows.Forms.TextBox
$Par_VMName_InputBox.Location = New-Object System.Drawing.Size(15,25)
$Par_VMName_InputBox.Size = New-Object System.Drawing.Size(150,50)
$Par_VMName_InputBox.TabIndex = 3
$Par_VMName_InputBox.AutoCompleteCustomSource.AddRange(("EMBOMetagenomicOct17", "IntroNGSApr17", "DataVisJan17", "EMBOMetabolomicsFeb17", "GenomicMedFeb17",
"PrimersJan17", "ubuntu1404", "ProteomicsJan17", "BioExelMay16", "IntegrativeOmicsFeb17", "ubuntu1604", "Ubuntu1604"));
$Par_VMName_InputBox.AutoCompleteMode = [System.Windows.Forms.AutoCompleteMode]::SuggestAppend;
$Par_VMName_InputBox.AutoCompleteSource = [System.Windows.Forms.AutoCompleteSource]::CustomSource;
$Par_VMName_groupBox.Controls.Add($Par_VMName_InputBox)

# Disable VM Console Group Box
$vmcon_groupBox = New-Object System.Windows.Forms.GroupBox
#$vmcon_groupBox.Autosize = $True
$vmcon_groupBox.Location = New-Object System.Drawing.Size(860,45)
$vmcon_groupBox.size = New-Object System.Drawing.Size(100,72)
$vmcon_groupBox.text = "Disable VM Console"
$vmcon_groupBox.Font = New-Object System.Drawing.Font("Tahoma",10,[System.Drawing.FontStyle]::Bold)
$Form.Controls.Add($vmcon_groupBox)

# Disable VM Console check box
$vmcon_checkbox = New-Object System.Windows.Forms.CheckBox
$vmcon_checkbox.AutoSize = $True
$vmcon_checkbox.Location = New-Object System.Drawing.Point(15,37)
#$vmcon_checkbox.Name = "Delete if Present"
$vmcon_checkbox.TabIndex = 4
$vmcon_checkbox.Text = "Disable"
$vmcon_checkbox.UseVisualStyleBackColor = $True
$vmcon_groupBox.Controls.Add($vmcon_checkbox)


# Datastore GroupBox
$data_groupBox = New-Object System.Windows.Forms.GroupBox
$data_groupBox.Autosize = $True
$data_groupBox.Location = New-Object System.Drawing.Size(20,130)
$data_groupBox.size = New-Object System.Drawing.Size(150,50)
$data_groupBox.text = "Data Store"
$data_groupBox.Font = New-Object System.Drawing.Font("Tahoma",10,[System.Drawing.FontStyle]::Bold)
$Form.Controls.Add($data_groupBox)

# Datastore dropbox
$data_DropDownBox = New-Object System.Windows.Forms.ComboBox
$data_DropDownBox.Location = New-Object System.Drawing.Size(15,25)
$data_DropDownBox.Size = New-Object System.Drawing.Size(120,20)
$data_DropDownBox.Autosize = $True
$data_DropDownBox.TabIndex = 5
$data_DropDownBox.SelectedText = "flash-ds1"
#$data_DropDownBox.SelectedItem = $dataList.Items[0]
$data_groupBox.Controls.Add($data_DropDownBox)
$dataList=@("flash-ds1","fast_flash","slower_bigger_2")
foreach ($datastr in $dataList) {
                      $data_DropDownBox.Items.Add($datastr)
                              } #end foreach
$data_DropDownBox.SelectedItem = $dataList[0]

# Custom Spec GroupBox
$spec_groupBox = New-Object System.Windows.Forms.GroupBox
$spec_groupBox.Autosize = $True
$spec_groupBox.Location = New-Object System.Drawing.Size(190,130)
$spec_groupBox.size = New-Object System.Drawing.Size(180,50)
$spec_groupBox.text = "VM Custom Spec"
$spec_groupBox.Font = New-Object System.Drawing.Font("Tahoma",10,[System.Drawing.FontStyle]::Bold)
$Form.Controls.Add($spec_groupBox)

# Custom Spe inputbox
$spec_InputBox = New-Object System.Windows.Forms.TextBox
$spec_InputBox.Location = New-Object System.Drawing.Size(15,25)
$spec_InputBox.Size = New-Object System.Drawing.Size(150,50)
$spec_InputBox.TabIndex = 6
$spec_InputBox.Text = "ubuntu1604"
$spec_InputBox.AutoCompleteCustomSource.AddRange(("Windows7", "Windows10", "NativeUbuntu", "ubuntu1404", "ubuntu1604"));
$spec_InputBox.AutoCompleteMode = [System.Windows.Forms.AutoCompleteMode]::SuggestAppend;
$spec_InputBox.AutoCompleteSource = [System.Windows.Forms.AutoCompleteSource]::CustomSource;
$spec_groupBox.Controls.Add($spec_InputBox)

# Snapshot GroupBox
$snap_groupBox = New-Object System.Windows.Forms.GroupBox
$snap_groupBox.Autosize = $True
$snap_groupBox.Location = New-Object System.Drawing.Size(390,130)
$snap_groupBox.size = New-Object System.Drawing.Size(180,50)
$snap_groupBox.text = "VM Snapshot"
$snap_groupBox.Font = New-Object System.Drawing.Font("Tahoma",10,[System.Drawing.FontStyle]::Bold)
$Form.Controls.Add($snap_groupBox)

# Snapshot inputbox
$snap_InputBox = New-Object System.Windows.Forms.TextBox
$snap_InputBox.Location = New-Object System.Drawing.Size(15,25)
$snap_InputBox.Size = New-Object System.Drawing.Size(150,50)
$snap_InputBox.TabIndex = 7
$snap_InputBox.AutoCompleteCustomSource.AddRange(("Post_Nvidia", "PostNvidia", "Final", "final_snap", "Final_Snap", "postNvidia", "Nvidia",
"Pre_deployment", "Post_testing", "Post_Test"));
$snap_InputBox.AutoCompleteMode = [System.Windows.Forms.AutoCompleteMode]::SuggestAppend;
$snap_InputBox.AutoCompleteSource =[System.Windows.Forms.AutoCompleteSource]::CustomSource;
$snap_groupBox.Controls.Add($snap_InputBox)

# Delete if present Group Box
$del_groupBox = New-Object System.Windows.Forms.GroupBox
$del_groupBox.Autosize = $True
$del_groupBox.Location = New-Object System.Drawing.Size(590,130)
$del_groupBox.size = New-Object System.Drawing.Size(160,50)
$del_groupBox.text = "Delete old VM"
$del_groupBox.Font = New-Object System.Drawing.Font("Tahoma",10,[System.Drawing.FontStyle]::Bold)
$Form.Controls.Add($del_groupBox)

# Delete if present check box
$del_checkbox = New-Object System.Windows.Forms.CheckBox
$del_checkbox.AutoSize = $True
$del_checkbox.Location = New-Object System.Drawing.Point(15,27)
#$del_checkbox.Name = "Delete if Present"
$del_checkbox.TabIndex = 8
$del_checkbox.Text = "Delete if present"
$del_checkbox.UseVisualStyleBackColor = $True
$del_groupBox.Controls.Add($del_checkbox)

# VM Clones number Groupbox
$vmnbr_groupBox = New-Object System.Windows.Forms.GroupBox
$vmnbr_groupBox.Autosize = $True
$vmnbr_groupBox.Location = New-Object System.Drawing.Size(815,150)
$vmnbr_groupBox.size = New-Object System.Drawing.Size(150,50)
$vmnbr_groupBox.text = "Number of Clones"
$vmnbr_groupBox.Font = New-Object System.Drawing.Font("Tahoma",10,[System.Drawing.FontStyle]::Bold)
$Form.Controls.Add($vmnbr_groupBox)

# VM Clones number inputbox
$vmnbr_InputBox = New-Object System.Windows.Forms.TextBox
$vmnbr_InputBox.Location = New-Object System.Drawing.Size(15,25)
$vmnbr_InputBox.Size = New-Object System.Drawing.Size(50,50)
$vmnbr_InputBox.TabIndex = 9
$vmnbr_InputBox.Text
$vmnbr_InputBox.Text = "32"
$vmnbr_groupBox.Controls.Add($vmnbr_InputBox)

# VM Clones number label
$vmnbr_Label = New-Object System.Windows.Forms.Label
$vmnbr_Label.Text = "VMs"
$vmnbr_Label.Location = New-Object System.Drawing.Size(70,28)
$vmnbr_Label.Font = New-Object System.Drawing.Font("Calibri",10,[System.Drawing.FontStyle]::Bold)
$vmnbr_Label.AutoSize = $True
$vmnbr_groupBox.Controls.Add($vmnbr_Label)

# Broker GroupBox
$broker_groupBox = New-Object System.Windows.Forms.GroupBox
$broker_groupBox.Autosize = $True
$broker_groupBox.Location = New-Object System.Drawing.Size(20,220)
$broker_groupBox.size = New-Object System.Drawing.Size(240,150)
$broker_groupBox.text = "Horizon Broker Credentials"
$broker_groupBox.Font = New-Object System.Drawing.Font("Tahoma",10,[System.Drawing.FontStyle]::Bold)
$Form.Controls.Add($broker_groupBox)

# Broker Address label
$broAdd_Label = New-Object System.Windows.Forms.Label
$broAdd_Label.Text = "Horizon Broker Address:"
$broAdd_Label.Location = New-Object System.Drawing.Size(10,20)
$broAdd_Label.Font = New-Object System.Drawing.Font("Calibri",10,[System.Drawing.FontStyle]::Regular)
$broAdd_Label.AutoSize = $True
$broker_groupBox.Controls.Add($broAdd_Label)

# Broker address inputbox
$broAdd_InputBox = New-Object System.Windows.Forms.TextBox
$broAdd_InputBox.Location = New-Object System.Drawing.Size(15,43)
$broAdd_InputBox.Size = New-Object System.Drawing.Size(210,50)
$broAdd_InputBox.TabIndex = 10
$broAdd_InputBox.Text = "broker1.courses.ebi.ac.uk"
$broAdd_InputBox.AutoCompleteCustomSource.AddRange(("intsecurity.courses.ebi.ac.uk", "broker.courses.ebi.ac.uk", "broker7test.courses.ebi.ac.uk",
 "broker2.courses.ebi.ac.uk", "broker7.courses.ebi.ac.uk", "broker1.courses.ebi.ac.uk", "extsecurity.courses.ebi.ac.uk"));
$broAdd_InputBox.AutoCompleteMode = [System.Windows.Forms.AutoCompleteMode]::SuggestAppend;
$broAdd_InputBox.AutoCompleteSource =[System.Windows.Forms.AutoCompleteSource]::CustomSource;
$broker_groupBox.Controls.Add($broAdd_InputBox)

# Broker Admin username label
$broadm_Label = New-Object System.Windows.Forms.Label
$broadm_Label.Text = "Horizon Broker Admin username:"
$broadm_Label.Location = New-Object System.Drawing.Size(10,70)
$broadm_Label.Font = New-Object System.Drawing.Font("Calibri",10,[System.Drawing.FontStyle]::Regular)
$broadm_Label.AutoSize = $True
$broker_groupBox.Controls.Add($broadm_Label)

# Broker Admin username inputbox
$broAdm_InputBox = New-Object System.Windows.Forms.TextBox
$broAdm_InputBox.Location = New-Object System.Drawing.Size(15,93)
$broAdm_InputBox.Size = New-Object System.Drawing.Size(210,50)
$broAdm_InputBox.TabIndex = 11
$broAdm_InputBox.Text = "linuxviewagent"
$broAdm_InputBox.AutoCompleteCustomSource.AddRange(("admin", "brokeradmin", "linuxviewagent", "horizonadmin", "alibi"));
$broAdm_InputBox.AutoCompleteMode = [System.Windows.Forms.AutoCompleteMode]::SuggestAppend;
$broAdm_InputBox.AutoCompleteSource =[System.Windows.Forms.AutoCompleteSource]::CustomSource;
$broker_groupBox.Controls.Add($broAdm_InputBox)

# Broker Admin password label
$bropass_Label = New-Object System.Windows.Forms.Label
$bropass_Label.Text = "Horizon Broker Admin password:"
$bropass_Label.Location = New-Object System.Drawing.Size(10,120)
$bropass_Label.Font = New-Object System.Drawing.Font("Calibri",10,[System.Drawing.FontStyle]::Regular)
$bropass_Label.AutoSize = $True
$broker_groupBox.Controls.Add($bropass_Label)

# Broker Admin PAssword inputbox
$bropass_InputBox = New-Object System.Windows.Forms.TextBox
$bropass_InputBox.Location = New-Object System.Drawing.Size(15,143)
$bropass_InputBox.Size = New-Object System.Drawing.Size(210,50)
$bropass_InputBox.TabIndex = 12
$bropass_InputBox.UseSystemPasswordChar = $true
$broker_groupBox.Controls.Add($bropass_InputBox)

# Domaine Name label
$domain_Label = New-Object System.Windows.Forms.Label
$domain_Label.Text = "Domain Name:"
$domain_Label.Location = New-Object System.Drawing.Size(10,170)
$domain_Label.Font = New-Object System.Drawing.Font("Calibri",10,[System.Drawing.FontStyle]::Regular)
$domain_Label.AutoSize = $True
$broker_groupBox.Controls.Add($domain_Label)

# Domain Name inputbox
$domain_InputBox = New-Object System.Windows.Forms.TextBox
$domain_InputBox.Location = New-Object System.Drawing.Size(15,193)
$domain_InputBox.Size = New-Object System.Drawing.Size(210,50)
$domain_InputBox.TabIndex = 13
$domain_InputBox.Text = "courses.ebi.ac.uk"
$domain_InputBox.AutoCompleteCustomSource.AddRange(("courses.ebi.ac.uk", "ebi.ac.uk", "COURSES.EBI.AC.UK", "COURSES"));
$domain_InputBox.AutoCompleteMode = [System.Windows.Forms.AutoCompleteMode]::SuggestAppend;
$domain_InputBox.AutoCompleteSource =[System.Windows.Forms.AutoCompleteSource]::CustomSource;
$broker_groupBox.Controls.Add($domain_InputBox)

# vcenter GroupBox
$vcenter_groupBox = New-Object System.Windows.Forms.GroupBox
$vcenter_groupBox.Autosize = $True
$vcenter_groupBox.Location = New-Object System.Drawing.Size(280,220)
$vcenter_groupBox.size = New-Object System.Drawing.Size(240,150)
$vcenter_groupBox.text = "VCenter Credentials"
$vcenter_groupBox.Font = New-Object System.Drawing.Font("Tahoma",10,[System.Drawing.FontStyle]::Bold)
$Form.Controls.Add($vcenter_groupBox)

# vcenter Address label
$vcAdd_Label = New-Object System.Windows.Forms.Label
$vcAdd_Label.Text = "VCenter Address:"
$vcAdd_Label.Location = New-Object System.Drawing.Size(10,20)
$vcAdd_Label.Font = New-Object System.Drawing.Font("Calibri",10,[System.Drawing.FontStyle]::Regular)
$vcAdd_Label.AutoSize = $True
$vcenter_groupBox.Controls.Add($vcAdd_Label)

# vcenter address inputbox
$vcAdd_InputBox = New-Object System.Windows.Forms.TextBox
$vcAdd_InputBox.Location = New-Object System.Drawing.Size(15,43)
$vcAdd_InputBox.Size = New-Object System.Drawing.Size(210,50)
$vcAdd_InputBox.TabIndex = 14
$vcAdd_InputBox.Text = "vcenter.courses.ebi.ac.uk"
$vcAdd_InputBox.AutoCompleteCustomSource.AddRange(("vcenter.courses.ebi.ac.uk", "vcenter2.courses.ebi.ac.uk", "vcenter.ebi.ac.uk", "testvcenter.courses.ebi.ac.uk"));
$vcAdd_InputBox.AutoCompleteMode = [System.Windows.Forms.AutoCompleteMode]::SuggestAppend;
$vcAdd_InputBox.AutoCompleteSource =[System.Windows.Forms.AutoCompleteSource]::CustomSource;
$vcenter_groupBox.Controls.Add($vcAdd_InputBox)

# Broker Admin username label
$vcadm_Label = New-Object System.Windows.Forms.Label
$vcadm_Label.Text = "VCenter Admin username:"
$vcadm_Label.Location = New-Object System.Drawing.Size(10,70)
$vcadm_Label.Font = New-Object System.Drawing.Font("Calibri",10,[System.Drawing.FontStyle]::Regular)
$vcadm_Label.AutoSize = $True
$vcenter_groupBox.Controls.Add($vcadm_Label)

# Broker Admin username inputbox
$vcAdm_InputBox = New-Object System.Windows.Forms.TextBox
$vcAdm_InputBox.Location = New-Object System.Drawing.Size(15,93)
$vcAdm_InputBox.Size = New-Object System.Drawing.Size(210,50)
$vcAdm_InputBox.TabIndex = 15
$vcAdm_InputBox.Text = "alibi"
$vcAdm_InputBox.AutoCompleteCustomSource.AddRange(("admin", "centeradmin", "alibi", "brett"));
$vcAdm_InputBox.AutoCompleteMode = [System.Windows.Forms.AutoCompleteMode]::SuggestAppend;
$vcAdm_InputBox.AutoCompleteSource =[System.Windows.Forms.AutoCompleteSource]::CustomSource;
$vcenter_groupBox.Controls.Add($vcAdm_InputBox)

# Broker Admin password label
$vcpass_Label = New-Object System.Windows.Forms.Label
$vcpass_Label.Text = "VCenter Admin password:"
$vcpass_Label.Location = New-Object System.Drawing.Size(10,120)
$vcpass_Label.Font = New-Object System.Drawing.Font("Calibri",10,[System.Drawing.FontStyle]::Regular)
$vcpass_Label.AutoSize = $True
$vcenter_groupBox.Controls.Add($vcpass_Label)

# Broker Admin Password inputbox
$vcpass_InputBox = New-Object System.Windows.Forms.TextBox
$vcpass_InputBox.Location = New-Object System.Drawing.Size(15,143)
$vcpass_InputBox.Size = New-Object System.Drawing.Size(210,50)
$vcpass_InputBox.TabIndex = 16
$vcpass_InputBox.UseSystemPasswordChar = $true
$vcenter_groupBox.Controls.Add($vcpass_InputBox)

# Linux Guest GroupBox
$guest_groupBox = New-Object System.Windows.Forms.GroupBox
$guest_groupBox.Autosize = $True
$guest_groupBox.Location = New-Object System.Drawing.Size(540,240)
$guest_groupBox.size = New-Object System.Drawing.Size(240,150)
$guest_groupBox.text = "Guest OS User Credentials"
$guest_groupBox.Font = New-Object System.Drawing.Font("Tahoma",10,[System.Drawing.FontStyle]::Bold)
$Form.Controls.Add($guest_groupBox)

# Guest user label
$gstusr_Label = New-Object System.Windows.Forms.Label
$gstusr_Label.Text = "Guest OS User username:"
$gstusr_Label.Location = New-Object System.Drawing.Size(10,20)
$gstusr_Label.Font = New-Object System.Drawing.Font("Calibri",10,[System.Drawing.FontStyle]::Regular)
$gstusr_Label.AutoSize = $True
$guest_groupBox.Controls.Add($gstusr_Label)

# Guest username inputbox
$gstusr_InputBox = New-Object System.Windows.Forms.TextBox
$gstusr_InputBox.Location = New-Object System.Drawing.Size(15,43)
$gstusr_InputBox.Size = New-Object System.Drawing.Size(210,50)
$gstusr_InputBox.TabIndex = 15
$gstusr_InputBox.Text = "setup"
$gstusr_InputBox.AutoCompleteCustomSource.AddRange(("admin", "root", "setup", "training"));
$gstusr_InputBox.AutoCompleteMode = [System.Windows.Forms.AutoCompleteMode]::SuggestAppend;
$gstusr_InputBox.AutoCompleteSource =[System.Windows.Forms.AutoCompleteSource]::CustomSource;
$guest_groupBox.Controls.Add($gstusr_InputBox)

# Guest password label
$gstpass_Label = New-Object System.Windows.Forms.Label
$gstpass_Label.Text = "Guest OS User password:"
$gstpass_Label.Location = New-Object System.Drawing.Size(10,70)
$gstpass_Label.Font = New-Object System.Drawing.Font("Calibri",10,[System.Drawing.FontStyle]::Regular)
$gstpass_Label.AutoSize = $True
$guest_groupBox.Controls.Add($gstpass_Label)

# guest Password inputbox
$gstpass_InputBox = New-Object System.Windows.Forms.TextBox
$gstpass_InputBox.Location = New-Object System.Drawing.Size(15,93)
$gstpass_InputBox.Size = New-Object System.Drawing.Size(210,50)
$gstpass_InputBox.TabIndex = 16
$gstpass_InputBox.UseSystemPasswordChar = $true
$guest_groupBox.Controls.Add($gstpass_InputBox)

# VM Clones range Groupbox
$vmrng_groupBox = New-Object System.Windows.Forms.GroupBox
$vmrng_groupBox.Autosize = $True
$vmrng_groupBox.Location = New-Object System.Drawing.Size(815,235)
$vmrng_groupBox.size = New-Object System.Drawing.Size(145,150)
$vmrng_groupBox.text = "Range of Clones"
$vmrng_groupBox.Font = New-Object System.Drawing.Font("Tahoma",10,[System.Drawing.FontStyle]::Bold)
$Form.Controls.Add($vmrng_groupBox)

# VM Clones range usage check box
$vmrng_checkbox = New-Object System.Windows.Forms.CheckBox
$vmrng_checkbox.AutoSize = $True
$vmrng_checkbox.Location = New-Object System.Drawing.Point(15,25)
$vmrng_checkbox.TabIndex = 17
$vmrng_checkbox.Text = "Use this range:"
$vmrng_checkbox.UseVisualStyleBackColor = $True
$vmrng_groupBox.Controls.Add($vmrng_checkbox)

# VM Clones start range inputbox
$vmstrnbr_InputBox = New-Object System.Windows.Forms.TextBox
$vmstrnbr_InputBox.Location = New-Object System.Drawing.Size(70,55)
$vmstrnbr_InputBox.Size = New-Object System.Drawing.Size(50,50)
$vmstrnbr_InputBox.TabIndex = 18
$vmstrnbr_InputBox.Text
$vmstrnbr_InputBox.Text = "0"
$vmrng_groupBox.Controls.Add($vmstrnbr_InputBox)

# VM Clones start range label
$vmstrnbr_Label = New-Object System.Windows.Forms.Label
$vmstrnbr_Label.Text = "From:"
$vmstrnbr_Label.Location = New-Object System.Drawing.Size(15,58)
$vmstrnbr_Label.Font = New-Object System.Drawing.Font("Tahoma",10,[System.Drawing.FontStyle]::Bold)
$vmstrnbr_Label.AutoSize = $True
$vmrng_groupBox.Controls.Add($vmstrnbr_Label)

# VM Clones end range inputbox
$vmendnbr_InputBox = New-Object System.Windows.Forms.TextBox
$vmendnbr_InputBox.Location = New-Object System.Drawing.Size(70,85)
$vmendnbr_InputBox.Size = New-Object System.Drawing.Size(50,50)
$vmendnbr_InputBox.TabIndex = 19
$vmendnbr_InputBox.Text
$vmendnbr_InputBox.Text = "32"
$vmrng_groupBox.Controls.Add($vmendnbr_InputBox)

# VM Clones end range label
$vmendnbr_Label = New-Object System.Windows.Forms.Label
$vmendnbr_Label.Text = "To:"
$vmendnbr_Label.Location = New-Object System.Drawing.Size(15,88)
$vmendnbr_Label.Font = New-Object System.Drawing.Font("Tahoma",10,[System.Drawing.FontStyle]::Bold)
$vmendnbr_Label.AutoSize = $True
$vmrng_groupBox.Controls.Add($vmendnbr_Label)

# Selected tar ball label
$tar_Label = New-Object System.Windows.Forms.Label
$tar_Label.Text = "No Horizon Agent tar ball file selected yet."
$tar_Label.BackColor = [System.Drawing.Color]::DarkOrange
$tar_label.Location = New-Object System.Drawing.Size(180,530)
$tar_label.Font = New-Object System.Drawing.Font("Calibri",10,[System.Drawing.FontStyle]::Bold)
$tar_Label.AutoSize = $True
$form.controls.add($tar_label)

# Output Box for monitotoring
$outputBox = New-Object System.Windows.Forms.TextBox                              #creating the text box
$outputBox.Location = New-Object System.Drawing.Size(25,640)                      #location of the text box (px) in relation to the primary window's edges
$outputBox.Size = New-Object System.Drawing.Size(940,400)                         #the size in px of the text box (length, height)
$outputBox.MultiLine = $True                                                      #declaring the text box as multi-line
$outputBox.ScrollBars = "Both"                                                    #adding scroll bars if required
$outputBox.ForeColor = [Drawing.Color]::Green
$outputBox.DataBindings.DefaultDataSourceUpdateMode = [System.Windows.Forms.DataSourceUpdateMode]::OnValidation
$outputBox.TabIndex = 24
$outputBox.Font = New-Object System.Drawing.Font("Consolas",8,[System.Drawing.FontStyle]::Regular)    #Output text
$Form.Controls.Add($outputBox)                                                    #activating the text box inside the primary window

##########################  Buttons #############################

# Upload File Button
$file_Button = New-Object System.Windows.Forms.Button
$file_Button.Location = New-Object System.Drawing.Size(20,500)
$file_Button.Size = New-Object System.Drawing.Size(140,60)
$file_Button.Text = "Select Horizon Agent tar ball"
$file_Button.Font = New-Object System.Drawing.Font("Comic Sans MS",10,[System.Drawing.FontStyle]::Bold)
$file_Button.Cursor = [System.Windows.Forms.Cursors]::Hand
#$file_Button.Autosize = $True
$file_Button.TabIndex = 21
$file_Button.UseVisualStyleBackColor = $True
$file_Button.Add_Click({})
$Form.Controls.Add($file_Button)
$file_Button.Add_Click({
    Write-Host -ForeGroundColor Green "[INFO] Selecting Horizon Agent tarball..."
    $outputBox.AppendText("[INFO] Selecting Horizon Agent tar ball...`r`n")
    $global:agentInstaller = Read-OpenFileDialog -WindowTitle "Select the Horizon Agent tar ball File" -InitialDirectory 'C:\scripts\Horizon_tarballs' -Filter "Tar files (*.tar)|*.tar*"
    if (![string]::IsNullOrEmpty($global:agentInstaller))
    {
        Write-Host -ForeGroundColor Green "[INFO] You selected the Horizon agent tar ball: $global:agentInstaller."
        $outputBox.AppendText("[INFO] You selected the Horizon agent tar ball: $global:agentInstaller.`r`n")
        #$agent_ver = $global:agentInstaller.Substring(11)
        $tar_Label.Text = "Tar selected: $global:agentInstaller"
        $tar_Label.BackColor = [System.Drawing.Color]::DodgerBlue
        $tar_Label.Refresh()
    }
    else
    {
        Write-Host -ForeGroundColor Red "[ERROR] You did not select any file as the Horizon agent tar ball."
        $outputBox.AppendText("[ERROR] You did not select any file as the Horizon agent tar ball.`r`n")
        $tar_Label.Text = "No Horizon Agent tar ball file selected yet."
        $tar_Label.BackColor = [System.Drawing.Color]::DarkOrange
        $tar_Label.Refresh()
    }

})

# Cancel Button
$btn_CANCEL = New-Object System.Windows.Forms.Button
$btn_CANCEL.Autosize = $True
$btn_CANCEL.Location = New-Object System.Drawing.Size(25,585)
$btn_CANCEL.Name = "btn_CANCEL"
$btn_CANCEL.Size = New-Object System.Drawing.Size(75,40)
$btn_CANCEL.TabIndex = 23
$btn_CANCEL.UseVisualStyleBackColor = $True
$btn_CANCEL.Text = "Cancel"
#$btn_CANCEL.BackColor = [System.Drawing.Color]::Orange
$btn_CANCEL.Font = New-Object System.Drawing.Font("Comic Sans MS",10,[System.Drawing.FontStyle]::Bold)
$btn_CANCEL.Add_Click({
    $cancel_ver = Read-MessageBoxDialog -Message "Are you sure you want to cancel the Deployment?" -WindowTitle "Cancel Deployment" -Buttons YesNo -Icon Question
    if ($cancel_ver -eq "Yes")
    {
        Write-Host -ForeGroundColor Yellow "[DEBUG] Deployment Canceled. Exiting..."
        $outputBox.AppendText("[DEBUG] Deployment Canceled. Exiting...`r`n")
        Start-Sleep -s 1
        $Form.Close()
    }
})
$btn_CANCEL.UseVisualStyleBackColor = $True
$btn_CANCEL.Cursor = [System.Windows.Forms.Cursors]::Hand
$Form.Controls.Add($btn_CANCEL)

# Deploy Button
$ok_Button = New-Object System.Windows.Forms.Button                                  #create the button
$ok_Button.Location = New-Object System.Drawing.Size(830,585)                         #location of the button (px) in relation to the primary window's edges
$ok_Button.Size = New-Object System.Drawing.Size(100,40)                              #the size in px of the button (length, height)
$ok_Button.Text = "Start Deployment"                                                 #labeling the button
$ok_Button.Font = New-Object System.Drawing.Font("Comic Sans MS",10,[System.Drawing.FontStyle]::Bold)
$ok_Button.Cursor = [System.Windows.Forms.Cursors]::Hand
$ok_Button.BackColor = [System.Drawing.Color]::DeepSkyBlue
$ok_Button.Autosize = $True
$ok_Button.TabIndex = 22
$ok_Button.UseVisualStyleBackColor = $True
$ok_Button.Add_Click({})                                                             #the action triggered by the button
$Form.Controls.Add($ok_Button)                                                       #activating the button inside the primary window
$ok_Button.Add_Click({
    Write-Host -ForeGroundColor Green "[INFO] Initiating Deployment..."
    $outputBox.AppendText("[INFO] Initiating Deployment...`r`n")
    $EULA_groupBox.BackColor = [System.Drawing.Color]::Transparent
    $EULA_groupBox.Refresh()
    $Type_groupBox.BackColor = [System.Drawing.Color]::Transparent
    $Type_groupBox.Refresh()
    $VMName_groupBox.BackColor = [System.Drawing.Color]::Transparent
    $VMName_groupBox.Refresh()
    $Par_VMName_groupBox.BackColor = [System.Drawing.Color]::Transparent
    $Par_VMName_groupBox.Refresh()
    $data_groupBox.BackColor = [System.Drawing.Color]::Transparent
    $data_groupBox.Refresh()
    $vmnbr_groupBox.BackColor = [System.Drawing.Color]::Transparent
    $vmnbr_groupBox.Refresh()
    $vmrng_groupBox.BackColor = [System.Drawing.Color]::Transparent
    $vmrng_groupBox.Refresh()
    $spec_groupBox.BackColor = [System.Drawing.Color]::Transparent
    $spec_groupBox.Refresh()
    $snap_groupBox.BackColor = [System.Drawing.Color]::Transparent
    $snap_groupBox.Refresh()
    $broAdd_Label.BackColor = [System.Drawing.Color]::Transparent
    $broAdd_Label.Refresh()
    $broAdm_Label.BackColor = [System.Drawing.Color]::Transparent
    $broAdm_Label.Refresh()
    $bropass_Label.BackColor = [System.Drawing.Color]::Transparent
    $bropass_Label.Refresh()
    $domain_Label.BackColor = [System.Drawing.Color]::Transparent
    $domain_Label.Refresh()
    $vcAdd_Label.BackColor = [System.Drawing.Color]::Transparent
    $vcAdd_Label.Refresh()
    $gstusr_Label.BackColor = [System.Drawing.Color]::Transparent
    $gstusr_Label.Refresh()
    $gstpass_Label.BackColor = [System.Drawing.Color]::Transparent
    $gstpass_Label.Refresh()

    [bool]$global:vmop = $false
    main

})

# VM Operation Button
$VMOp_Button = New-Object System.Windows.Forms.Button                                  #create the button
$VMOp_Button.Location = New-Object System.Drawing.Size(815,410)                         #location of the button (px) in relation to the primary window's edges
$VMOp_Button.Size = New-Object System.Drawing.Size(140,50)                              #the size in px of the button (length, height)
$VMOp_Button.Text = "Virtual Machines Operations"                                                 #labeling the button
$VMOp_Button.Font = New-Object System.Drawing.Font("Comic Sans MS",10,[System.Drawing.FontStyle]::Bold)
$VMOp_Button.Cursor = [System.Windows.Forms.Cursors]::Hand
#$VMOp_Button.Autosize = $True
$VMOp_Button.TabIndex = 20
$VMOp_Button.UseVisualStyleBackColor = $True
$VMOp_Button.Add_Click({})                                                             #the action triggered by the button
$Form.Controls.Add($VMOp_Button)                                                       #activating the button inside the primary window
$VMOp_Button.Add_Click({
    Write-Host -ForeGroundColor Green "[INFO] Initiating VM Operations..."
    $outputBox.AppendText("[INFO] Initiating VM Operations...`r`n")
    Write-Host -ForeGroundColor Green "[INFO] You must fill out the form before going to the VM operations menu."
    $outputBox.AppendText("[INFO] You must fill out the form before going to the VM operations menu.`r`n")

    $EULA_groupBox.BackColor = [System.Drawing.Color]::Transparent
    $EULA_groupBox.Refresh()
    $Type_groupBox.BackColor = [System.Drawing.Color]::Transparent
    $Type_groupBox.Refresh()
    $VMName_groupBox.BackColor = [System.Drawing.Color]::Transparent
    $VMName_groupBox.Refresh()
    $Par_VMName_groupBox.BackColor = [System.Drawing.Color]::Transparent
    $Par_VMName_groupBox.Refresh()
    $data_groupBox.BackColor = [System.Drawing.Color]::Transparent
    $data_groupBox.Refresh()
    $vmnbr_groupBox.BackColor = [System.Drawing.Color]::Transparent
    $vmnbr_groupBox.Refresh()
    $vmrng_groupBox.BackColor = [System.Drawing.Color]::Transparent
    $vmrng_groupBox.Refresh()
    $spec_groupBox.BackColor = [System.Drawing.Color]::Transparent
    $spec_groupBox.Refresh()
    $snap_groupBox.BackColor = [System.Drawing.Color]::Transparent
    $snap_groupBox.Refresh()
    $broAdd_Label.BackColor = [System.Drawing.Color]::Transparent
    $broAdd_Label.Refresh()
    $broAdm_Label.BackColor = [System.Drawing.Color]::Transparent
    $broAdm_Label.Refresh()
    $bropass_Label.BackColor = [System.Drawing.Color]::Transparent
    $bropass_Label.Refresh()
    $domain_Label.BackColor = [System.Drawing.Color]::Transparent
    $domain_Label.Refresh()
    $vcAdd_Label.BackColor = [System.Drawing.Color]::Transparent
    $vcAdd_Label.Refresh()
    $gstusr_Label.BackColor = [System.Drawing.Color]::Transparent
    $gstusr_Label.Refresh()
    $gstpass_Label.BackColor = [System.Drawing.Color]::Transparent
    $gstpass_Label.Refresh()



    # VM Ops selection form
    $VMOps_Form = New-Object System.Windows.Forms.Form                                      #creating the form (this will be the "primary" window)
    $VMOps_Form.Size = New-Object System.Drawing.Size(570,250)                            #the size in px of the window length, height
    $VMOps_Form.AutoScaleDimensions = New-Object System.Drawing.SizeF(6, 13)
    $VMOps_Form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Font
    $VMOps_Form.AutoSize = $True
    $VMOps_Form.StartPosition = "CenterScreen"                                              #loads the window in the center of the screen
    #$Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedToolWindow  #Make the window border fixed
    $VMOps_Form.Text = "VM Operatiosn Selection Menu"                #window description
    #$VMOps_Form.Topmost = $True
    $VMOps_Form.DataBindings.DefaultDataSourceUpdateMode = [System.Windows.Forms.DataSourceUpdateMode]::OnValidation
    $VMOps_Icon = [system.drawing.icon]::ExtractAssociatedIcon($PSHOME + "\powershell.exe")
    $VMOps_Form.Icon = $VMOps_Icon

    # VM Ops Welcome label
    $VMOps_wel_label = New-Object system.Windows.Forms.Label
    $VMOps_wel_label.text = "You must fill out the form before going to the VM Operations Menu!!"
    $VMOps_wel_label.ForeColor = [System.Drawing.Color]::OrangeRed
    $VMOps_wel_label.Location = New-Object System.Drawing.Size(20,15)
    $VMOps_wel_label.Font = New-Object System.Drawing.Font("Calibri",12,[System.Drawing.FontStyle]::Bold)
    $VMOps_wel_label.Autosize = $True
    $VMOps_Form.controls.add($VMOps_wel_label)

    # VM Ops GroupBox
    $VMOps_groupBox = New-Object System.Windows.Forms.GroupBox
    $VMOps_groupBox.Autosize = $True
    $VMOps_groupBox.Location = New-Object System.Drawing.Size(20,50)
    $VMOps_groupBox.size = New-Object System.Drawing.Size(510,80)
    $VMOps_groupBox.text = "Please select on of the following operation to be done into the VMs:"
    $VMOps_groupBox.Font = New-Object System.Drawing.Font("Tahoma",10,[System.Drawing.FontStyle]::Bold)
    $VMOps_Form.Controls.Add($VMOps_groupBox)

    # Vm Ops dropbox
    $VMOps_DropDownBox = New-Object System.Windows.Forms.ComboBox
    $VMOps_DropDownBox.Location = New-Object System.Drawing.Size(15,30)
    $VMOps_DropDownBox.Size = New-Object System.Drawing.Size(480,20)
    $VMOps_DropDownBox.Autosize = $True
    $VMOps_DropDownBox.TabIndex = 1
    $VMOps_groupBox.Controls.Add($VMOps_DropDownBox)
    $VMOps_List = @("(1). Power On", "(2). Power Off", "(3) Shut VM Guest", "(4). Restart VM", "(5). Restart VM Guest", "(6). Delete VM", "(7). Add GPU PCI Device", "(8). Install Horizon Agent",
    "(9). Add Network Card", "(10). Connect Network Card", "(11). Get VM IP Address", "(12). Set Linux VM Hostname","(13). Install Nvidia Driver on Linux VM",
    "(14). Migrate VMs equally between Hosts", "(15). Clone VMs for an Inactive pool", "(16) Remove GPU from VM", "(17). Change network VLAN configuration")
    foreach ($VMOpsstr in $VMOps_List) {
                      $VMOps_DropDownBox.Items.Add($VMOpsstr)
                              } #end foreach


    # VM Ops select Button
    $VMOps_ok_Button = New-Object System.Windows.Forms.Button                                  #create the button
    $VMOps_ok_Button.Location = New-Object System.Drawing.Size(400,150)                         #location of the button (px) in relation to the primary window's edges
    $VMOps_ok_Button.Size = New-Object System.Drawing.Size(100,40)                              #the size in px of the button (length, height)
    $VMOps_ok_Button.Text = "Start Operation"                                                 #labeling the button
    $VMOps_ok_Button.Font = New-Object System.Drawing.Font("Comic Sans MS",10,[System.Drawing.FontStyle]::Bold)
    $VMOps_ok_Button.Cursor = [System.Windows.Forms.Cursors]::Hand
    $VMOps_ok_Button.BackColor = [System.Drawing.Color]::DeepSkyBlue
    $VMOps_ok_Button.Autosize = $True
    $VMOps_ok_Button.TabIndex = 2
    $VMOps_ok_Button.UseVisualStyleBackColor = $True
    $VMOps_ok_Button.Add_Click({})                                                             #the action triggered by the button
    $VMOps_Form.Controls.Add($VMOps_ok_Button)                                                       #activating the button inside the primary window
    $VMOps_ok_Button.Add_Click({
     if (!($VMOps_DropDownBox.SelectedItem -eq $null))
    {
        [bool]$global:vmop = $true
        main
    }

    })

    # VM Ops Cancel Button
    $VMOps_CANCEL = New-Object System.Windows.Forms.Button
    $VMOps_CANCEL.Autosize = $True
    $VMOps_CANCEL.Location = New-Object System.Drawing.Size(30,150)
    $VMOps_CANCEL.Name = "VMOps_CANCEL"
    $VMOps_CANCEL.Size = New-Object System.Drawing.Size(75,40)
    $VMOps_CANCEL.TabIndex = 3
    $VMOps_CANCEL.UseVisualStyleBackColor = $True
    $VMOps_CANCEL.Text = "Back"
    #$btn_CANCEL.BackColor = [System.Drawing.Color]::Orange
    $VMOps_CANCEL.Font = New-Object System.Drawing.Font("Comic Sans MS",10,[System.Drawing.FontStyle]::Bold)
    $VMOps_CANCEL.Add_Click(
    {
        Write-Host -ForeGroundColor Yellow "[DEBUG] VM Operation selection popup box closing."
        $outputBox.AppendText("[DEBUG] VM Operation selection selection popup box closing.`r`n")
        [bool]$global:vmop = $false
        $VMOps_Form.Close()
    })
    $VMOps_CANCEL.UseVisualStyleBackColor = $True
    $VMOps_CANCEL.Cursor = [System.Windows.Forms.Cursors]::Hand
    $VMOps_Form.Controls.Add($VMOps_CANCEL)

    $VMOps_Form.Add_Shown({$VMOps_Form.Activate()})
    [void] $VMOps_Form.ShowDialog()


})


#####################  Main application  ##########################

function main {

    [bool]$global:init_dep = $true
    [bool]$global:init_vmops = $true
    if ($EULA_checkbox.Checked -eq $false) # EULA Licence test
    {
        Write-Host -ForeGroundColor Red "[ERROR] Deployment Aborded. EULA Licence not accepted."
        $outputBox.AppendText("[ERROR] Deployment Aborded. EULA Licence not accepted.`r`n")
        $global:init_dep = $false
        $global:init_vmops = $false
        $EULA_groupBox.BackColor = [System.Drawing.Color]::DarkOrange
        $EULA_groupBox.Refresh()
    }

    if ($Type_DropDownBox.SelectedItem -eq $null) # Clone type test
    {
        Write-Host -ForeGroundColor Red "[ERROR] Deployment Aborded. Cloning Type not specified."
        $outputBox.AppendText("[ERROR] Deployment Aborded. Cloning Type not specified.`r`n")
        $global:init_dep = $false
        $Type_groupBox.BackColor = [System.Drawing.Color]::DarkOrange
        $Type_groupBox.Refresh()
    }
    if ($VMName_InputBox.Text -eq "") # Clones VMs name test
    {
        Write-Host -ForeGroundColor Red "[ERROR] Deployment Aborded. Clones VMs Name not specified."
        $outputBox.AppendText("[ERROR] Deployment Aborded. Clones VMs Name not specified.`r`n")
        $global:init_dep = $false
        $global:init_vmops = $false
        $VMName_groupBox.BackColor = [System.Drawing.Color]::DarkOrange
        $VMName_groupBox.Refresh()
    }
    if ($Par_VMName_InputBox.Text -eq "") # Parent VM name test
    {
        Write-Host -ForeGroundColor Red "[ERROR] Deployment Aborded. Parent VM not specified."
        $outputBox.AppendText("[ERROR] Deployment Aborded. Parent VM not specified.`r`n")
        $global:init_dep = $false
        $Par_VMName_groupBox.BackColor = [System.Drawing.Color]::DarkOrange
        $Par_VMName_groupBox.Refresh()
    }
    if ($data_DropDownBox.SelectedItem -eq $null) # Datastore test
    {
        Write-Host -ForeGroundColor Red "[ERROR] Deployment Aborded. Datastore not specified."
        $outputBox.AppendText("[ERROR] Deployment Aborded. Datastore not specified.`r`n")
        $global:init_dep = $false
        $data_groupBox.BackColor = [System.Drawing.Color]::DarkOrange
        $data_groupBox.Refresh()
    }
    if ($spec_InputBox.Text -eq "") # Custom Spec test
    {
        Write-Host -ForeGroundColor Red "[ERROR] Deployment Aborded. Custom Spec not specified."
        $outputBox.AppendText("[ERROR] Deployment Aborded. Custom Spec not specified.`r`n")
        $global:init_dep = $false
        $spec_groupBox.BackColor = [System.Drawing.Color]::DarkOrange
        $spec_groupBox.Refresh()
    }
    if ($snap_InputBox.Text -eq "") # Snapshot test
    {
        Write-Host -ForeGroundColor Red "[ERROR] Deployment Aborded. Snapshot not specified."
        $outputBox.AppendText("[ERROR] Deployment Aborded. Snapshot not specified.`r`n")
        $global:init_dep = $false
        $snap_groupBox.BackColor = [System.Drawing.Color]::DarkOrange
        $snap_groupBox.Refresh()
    }
    if ($global:agentInstaller -eq "") # Agent tar ball localtion test
    {
        Write-Host -ForeGroundColor Red "[ERROR] Deployment Aborded. No Horizon Agent tar ball specified."
        $outputBox.AppendText("[ERROR] Deployment Aborded. No Horizon Agent tar ball specified.`r`n")
        $global:init_dep = $false
    }
    if ($broAdd_InputBox.Text -eq "") # Broker address test
    {
        Write-Host -ForeGroundColor Red "[ERROR] Deployment Aborded. Broker Address not specified."
        $outputBox.AppendText("[ERROR] Deployment Aborded. Broker Address not specified.`r`n")
        $global:init_dep = $false
        $broAdd_Label.BackColor = [System.Drawing.Color]::DarkOrange
        $broAdd_Label.Refresh()
    }
    if ($broAdm_InputBox.Text -eq "")
    {
        Write-Host -ForeGroundColor Red "[ERROR] Deployment Aborded. Broker Admin username not specified."
        $outputBox.AppendText("[ERROR] Deployment Aborded. Broker Admin username not specified.`r`n")
        $global:init_dep = $false
        $broAdm_Label.BackColor = [System.Drawing.Color]::DarkOrange
        $broAdm_Label.Refresh()

    }
    if ($bropass_InputBox.Text -eq "")
    {
        Write-Host -ForeGroundColor Red "[ERROR] Deployment Aborded. Broker Admin Password not specified."
        $outputBox.AppendText("[ERROR] Deployment Aborded. Broker Admin Password not specified.`r`n")
        $global:init_dep = $false
        $bropass_Label.BackColor = [System.Drawing.Color]::DarkOrange
        $bropass_Label.Refresh()
    }
    if ($domain_InputBox.Text -eq "")
    {
        Write-Host -ForeGroundColor Red "[ERROR] Deployment Aborded. Domain Name not specified."
        $outputBox.AppendText("[ERROR] Deployment Aborded. Domain Name not specified.`r`n")
        $global:init_dep = $false
        $domain_Label.BackColor = [System.Drawing.Color]::DarkOrange
        $domain_Label.Refresh()
    }
    if ($vcAdd_InputBox.Text -eq "")
    {
        Write-Host -ForeGroundColor Red "[ERROR] Deployment Aborded. VCenter Address not specified."
        $outputBox.AppendText("[ERROR] Deployment Aborded. VCenter Address not specified.`r`n")
        $global:init_dep = $false
        $global:init_vmops = $false
        $vcAdd_Label.BackColor = [System.Drawing.Color]::DarkOrange
        $vcAdd_Label.Refresh()
    }
   # if ($vcAdm_InputBox.Text -eq "")
   # {
   #     Write-Host -ForeGroundColor Red "[ERROR] Deployment Aborded. VCenter Admin username not specified."
   #     $outputBox.AppendText("[ERROR] Deployment Aborded. VCenter Admin username not specified.`r`n")
   #     $global:init_dep = $false
   # }
   # if ($vcpass_InputBox.Text -eq "")
   # {
   #     Write-Host -ForeGroundColor Red "[ERROR] Deployment Aborded. VCenter Admin password not specified."
   #     $outputBox.AppendText("[ERROR] Deployment Aborded. VCenter Admin password not specified.`r`n")
   #     $global:init_dep = $false
   # }
    if ($gstusr_InputBox.Text -eq "")
    {
        Write-Host -ForeGroundColor Red "[ERROR] Deployment Aborded. Guest OS User username not specified."
        $outputBox.AppendText("[ERROR] Deployment Aborded. Guest OS User username not specified.`r`n")
        $global:init_dep = $false
        $gstusr_Label.BackColor = [System.Drawing.Color]::DarkOrange
        $gstusr_Label.Refresh()
    }
    if ($gstpass_InputBox.Text -eq "")
    {
        Write-Host -ForeGroundColor Red "[ERROR] Deployment Aborded. Guest OS User password not specified."
        $outputBox.AppendText("[ERROR] Deployment Aborded. Guest OS User password not specified.`r`n")
        $global:init_dep = $false
        $gstpass_Label.BackColor = [System.Drawing.Color]::DarkOrange
        $gstpass_Label.Refresh()
    }
    if ($vmnbr_InputBox.Text -eq "")
    {
        Write-Host -ForeGroundColor Red "[ERROR] Deployment Aborded. Clone VMs number not specified."
        $outputBox.AppendText("[ERROR] Deployment Aborded. Clone VMs number not specified.`r`n")
        $global:init_dep = $false
        $global:init_vmops = $false
        $vmnbr_groupBox.BackColor = [System.Drawing.Color]::DarkOrange
        $vmnbr_groupBox.Refresh()
    }
     if ($vmrng_checkbox.Checked -eq $true -and $vmstrnbr_InputBox.Text -eq "" -and $vmendnbr_InputBox.Text -eq "")
    {
        Write-Host -ForeGroundColor Red "[ERROR] Deployment Aborded. Clone VMs range not specified."
        $outputBox.AppendText("[ERROR] Deployment Aborded. Clone VMs range not specified.`r`n")
        $global:init_dep = $false
        $global:init_vmops = $false
        $vmrng_groupBox.BackColor = [System.Drawing.Color]::DarkOrange
        $vmrng_groupBox.Refresh()
    }


########################################################################################################
####################################### Main deloyment code ############################################
########################################################################################################

    if ($global:init_dep -eq $true -and $global:vmop -eq $false)
    {

    Write-Host -ForeGroundColor Green "`n########################################################"
    $Org_VMName= $VMName_InputBox.Text
    Write-Host -ForeGroundColor Yellow "[INFO] VMs clones common name: $Org_VMName"
    Write-Host -ForeGroundColor Green "########################################################`n"



    "-----------------------------------------------------"
    Check_SSH_Client -IsPlink $true -IsPSCP $true
    "-----------------------------------------------------"

    if ($vmcon_checkbox.Checked -eq $true)
    {
        $disableVMConsole = "yes"
        Write-Host -ForeGroundColor Green "[INFO] Disabling VM Console."
    }
    else
    {
        $disableVMConsole = "no"
        Write-Host -ForeGroundColor Green "[INFO] Leaving VM Console enabled"
    }

    $CloneType = $Type_DropDownBox.SelectedItem.ToString()
    Write-Host -ForeGroundColor Green "[INFO] Cloning Type selected: $CloneType"

    $srcVM = $Par_VMName_InputBox.Text
    Write-Host -ForeGroundColor Green "[INFO] Parent VM selected: $srcVM"

    $cSpec = $spec_InputBox.Text
    Write-Host -ForeGroundColor Green "[INFO] Custom Spec selected: $cSpec"

    $targetDSName = $data_DropDownBox.SelectedItem.ToString()
    Write-Host -ForeGroundColor Green "[INFO] Data Store selected: $targetDSName"

    $srcSnapshot = $snap_InputBox.Text
    Write-Host -ForeGroundColor Green "[INFO] Snapshot selected: $srcSnapshot"

    $deleteExisting = $del_checkbox.Checked
    Write-Host -ForeGroundColor Green "[INFO] Delete existing VM: $deleteExisting"

    $agentInstaller = $global:agentInstaller
    Write-Host -ForeGroundColor Green "[INFO] Agent tar ball selected: $agentInstaller"

    $brokerAddress = $broAdd_InputBox.Text
    Write-Host -ForeGroundColor Green "[INFO] Broker Address selected: $brokerAddress"

    $brokerAdminName = $broAdm_InputBox.Text
    Write-Host -ForeGroundColor Green "[INFO] Broker Admin Username selected: $brokerAdminName"

    $brokerAdminPassword = $bropass_InputBox.Text
    Write-Host -ForeGroundColor Green "[INFO] A Broker Admin Password has been selected."

    $domainName = $domain_InputBox.Text
    Write-Host -ForeGroundColor Green "[INFO] Domain Name selected: $domainName"

    $vcAddress = $vcAdd_InputBox.Text
    Write-Host -ForeGroundColor Green "[INFO] VCenter Address selected: $vcAddress"

    $vcAdmin = $vcAdm_InputBox.Text
    Write-Host -ForeGroundColor Green "[INFO] VCenter Admin username selected: $vcAdmin"

    $vcPassword = $vcpass_InputBox.Text
    Write-Host -ForeGroundColor Green "[INFO] A VCenter Admin Password has been selected."

    $guestUser = $gstusr_InputBox.Text
    Write-Host -ForeGroundColor Green "[INFO] Guest OS User username selected: $guestUser"

    $guestPassword = $gstpass_InputBox.Text
    Write-Host -ForeGroundColor Green "[INFO] A Guest OS user password has been selected."

    if ($vmrng_checkbox.Checked -eq $false)
    {
        $vm_nbr = $vmnbr_InputBox.Text
        Write-Host -ForeGroundColor Green "[INFO] Number of VM Clones selected: $vm_nbr"
    }
    else
    {
        $vm_str_nbr = $vmstrnbr_InputBox.Text
        $vm_nbr = $vmendnbr_InputBox.Text
        Write-Host -ForeGroundColor Green "[INFO] Range of VM Clones selected is from $vm_str_nbr to $vm_nbr"
    }

    Write-Host -ForeGroundColor Green "########################################################`n"


    # Logging the deployment
    $logDateTime = date -Format dd_MM_yy
    $global:Logfile = "C:\scripts\logs\" + $Par_VMName_InputBox.text + $logDateTime + ".log"
    Write-Host -ForeGroundColor Green "[INFO] Log file is: $global:Logfile `n"
    $timedate = date -Format dd/MM/yy`thh:mm:ss.m
    LogWrite "##############################################################################`n"
    LogWrite "[INFO]- Native Linux Deploying started for $Org_VMName"
    LogWrite "[INFO]- This script has started at: $timedate."
    LogWrite "[INFO]- Linux Horizon Agent EULA licence Accepted."
    LogWrite "[INFO]- Cloning type selected is: $CloneType"
    LogWrite "[INFO]- VMware Horizon Agent archive selected: $agentInstaller."
    LogWrite "[INFO]- Parent VM selected: $srcVM."
    LogWrite "[INFO]- Custom Spec selected: $cSpec."
    LogWrite "[INFO]- Data Store selected: $targetDSName."
    LogWrite "[INFO]- Snapshot selected: $srcSnapshot."
    LogWrite "[INFO]- VMs clones common name: $Org_VMName"
    LogWrite "[INFO]- Horizon Connection server to authenticate with is: $brokerAddress.`n"
    LogWrite "[INFO]- Horizon Connection server Admin connected: $brokerAdminName.`n"
    LogWrite "[INFO]- VCenter server used is: $vcAddress.`n"
    LogWrite "[INFO]- VCenter Admin runnign the deployment is: $vcAdmin.`n"
    LogWrite "[INFO]- Guest OS user used: $vcAddress.`n"
    if ($vmrng_checkbox.Checked -eq $false)
    {
        LogWrite "[INFO]- Number of VM Clones is: $vm_nbr.`n"
    }
    else
    {
        LogWrite "[INFO]- Range of VM Clones is from: $vm_str_nbr to: $vm_nbr.`n"
    }
    LogWrite "##############################################################################`n"



    #Connect to vCenter
    [Console]::ResetColor()
    if (!( $vcAdm_InputBox.Text -eq "" -or $vcpass_InputBox.Text -eq ""))
    { Connect-VIServer $vcAddress -user $vcAdmin -password $vcPassword }
    else { Connect-VIServer $vcAddress }

    $time = date -Format dd/MM/yy`thh:mm:ss.m
    LogWrite "[INFO] $time- Connecting to vCenter Address: $vcAddress."

    $j=0
    
    $destFolder = "/home/$guestUser/"

    $destHostList1 = "hx-vdi-hyp167.ebi.ac.uk", "hx-vdi-hyp168.ebi.ac.uk", "hx-vdi-hyp169.ebi.ac.uk", "hx-vdi-hyp170.ebi.ac.uk", 
    "hx-vdi-hyp171.ebi.ac.uk", "hx-vdi-hyp172.ebi.ac.uk", "hx-vdi-hyp173.ebi.ac.uk", "hx-vdi-hyp174.ebi.ac.uk"

    $destHostList2 = $destHostList1.Clone()
    [array]::Reverse($destHostList2)


    #"hx-vdi-hyp174.ebi.ac.uk", "hx-vdi-hyp173.ebi.ac.uk", "hx-vdi-hyp172.ebi.ac.uk", "hx-vdi-hyp171.ebi.ac.uk", "hx-vdi-hyp170.ebi.ac.uk",
    #  "hx-vdi-hyp169.ebi.ac.uk", "hx-vdi-hyp168.ebi.ac.uk", "hx-vdi-hyp167.ebi.ac.uk"


    [Console]::ResetColor()

    [int]$deploymentloop = [convert]::ToInt32($vm_nbr, 10)
    if ($vmrng_checkbox.Checked -eq $false)
    {
        [int]$i=1
    }
    else
    {
        [int]$i=[convert]::ToInt32($vm_str_nbr, 10)
    }

    while ($i -le $deploymentloop)
    {
        $destVMName = $Org_VMName + "-" + $i.ToString("00")

        $j=$j+1
        $VMName = $destVMName

        write-host -ForeGroundColor Yellow "`n############ Clone Nbr: $j   On: $VMName      ##########`n"
        $outputBox.AppendText("`r`n############ Clone Nbr: $j   On: $VMName     ##########`r`n")
        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[INFO] $time- Cloning the VM: $VMName started.`n"

	    if (IsVMExists ($destVMName))
	    {
		    Write-Host -ForeGroundColor Yellow "[DEBUG] VM $destVMName already Exists in VC $vcAddress"
            $outputBox.AppendText("[DEBUG] VM $destVMName Already Exists in VC $vcAddress`r`n")
		    if($deleteExisting -eq $true)
		    {
			    Delete_VM ($destVMName)
                $time = date -Format dd/MM/yy`thh:mm:ss.m
                LogWrite "[INFO] $time- VM $VMname is already created. Deleting it now..."
                LogWrite "[INFO] $time- VM $VMname is already created. Deleting...`n"
		    }
		    else
		    {
			    Write-Host -ForeGroundColor Yellow "[DEBUG] Skip clone for $destVMName"
                $outputBox.AppendText("[DEBUG] Skip clone for $destVMName`r`n")
                $time = date -Format dd/MM/yy`thh:mm:ss.m
                LogWrite "[DEBUG] $time- Skip cloning the VM $destVMName as requested.`n"
                LogWrite "#################################################################################`n"
                $i = $i+1
                continue
		    }
	    }

        
        $GPUID = $null
        $destHost = $null

        if ( $i  % 2 -eq 0)
        {
        foreach ($Hosting in $destHostList1)
        {
            Write-Host -ForeGroundColor Yellow "Testing host $Hosting ..."
            $GpuConf=get-vmhost $Hosting | get-vm | get-view
            $IdList = $GpuConf.config.hardware.device | ?{$_.Backing -is "VMware.Vim.VirtualPCIPassthroughDeviceBackingInfo"} | Select-Object  -Property @{N="Id";E={$_.Backing.Id}}
            ##$OnVMlist = Get-VMHost $destHost | Get-VM | Where-Object {$_.PowerState -eq "PoweredOn"}
            #$OnlineVMcount = $OnVMlist.count

            if ($IdList.Id.Length -eq 4)
            {
                Write-Host -ForeGroundColor Yellow "[DEBUG] The ESXi host: $Hosting is full"
                $outputBox.AppendText("[DEBUG] The ESXi host: $Hosting is full`r`n")
                LogWrite "[DEBUG] The ESXi host: $Hosting is full`n"
                continue
            }
            #elseif ($IdList.Id.Length -lt 4 -and $OnlineVMcount -gt 4)
            #{
            # # Ths case of having offline VMs with PCI device connected to them
            # $OffVMlist = Get-VMHost $destHost | Get-VM | Where-Object {$_.PowerState -eq "PoweredOff"}
            #
            # Write-Host -ForeGroundColor Yellow "[DEBUG] Removing PCI device from Offline VMs of ESXi host $destHost..."
            # $outputBox.AppendText("[DEBUG] Removing PCI device from Offline VMs of ESXi host $destHost...`r`n")
            # LogWrite "[DEBUG] Removing PCI device from Offline VMs of ESXi host $destHost...`n"
            # foreach ($v in $OffVMlist)
            # {
            #    foreach ($vm in (get-vm $v)) {get-vmresourceconfiguration $vm | set-vmresourceconfiguration -MemReservationMB $vm.MemoryMB}
            #    get-vm $v | get-passthroughdevice | remove-passthroughdevice -Confirm:$false
            # }
            else
            {
                $destHost = $Hosting
                break
            }
        }
        }
        else
        {
        foreach ($Hosting in $destHostList2)
        {
            Write-Host -ForeGroundColor Green "[INFO] Testing host $Hosting ..."
            $GpuConf=get-vmhost $Hosting | get-vm | get-view
            $IdList = $GpuConf.config.hardware.device | ?{$_.Backing -is "VMware.Vim.VirtualPCIPassthroughDeviceBackingInfo"} | Select-Object  -Property @{N="Id";E={$_.Backing.Id}}
            #$OnVMlist = Get-VMHost $destHost | Get-VM | Where-Object {$_.PowerState -eq "PoweredOn"}
            #$OnlineVMcount = $OnVMlist.count

            if ($IdList.Id.Length -eq 4)
            {
                Write-Host -ForeGroundColor Yellow "[DEBUG] The ESXi host: $Hosting is full"
                $outputBox.AppendText("[DEBUG] The ESXi host: $Hosting is full`r`n")
                LogWrite "[DEBUG] The ESXi host: $Hosting is full`n"
                continue
            }
            #elseif ($IdList.Id.Length -lt 4 -and $OnlineVMcount -gt 4)
            #{
            # # Ths case of having offline VMs with PCI device connected to them
            # $OffVMlist = Get-VMHost $destHost | Get-VM | Where-Object {$_.PowerState -eq "PoweredOff"}
            #
            # Write-Host -ForeGroundColor Yellow "[DEBUG] Removing PCI device from Offline VMs of ESXi host $destHost..."
            # $outputBox.AppendText("[DEBUG] Removing PCI device from Offline VMs of ESXi host $destHost...`r`n")
            # LogWrite "[DEBUG] Removing PCI device from Offline VMs of ESXi host $destHost...`n"
            # foreach ($v in $OffVMlist)
            # {
            #    foreach ($vm in (get-vm $v)) {get-vmresourceconfiguration $vm | set-vmresourceconfiguration -MemReservationMB $vm.MemoryMB}
            #    get-vm $v | get-passthroughdevice | remove-passthroughdevice -Confirm:$false
            # }
            #}
            else
            {
                $destHost = $Hosting
                break
            }
        }
        }

        if ( $destHost -eq $null)
        {
            Write-Host -ForeGroundColor Red "`n[ERROR] ######!!!!!!!!!!! All ESXi hosts are full  !!!!!!!!!!######`n"
            $outputBox.AppendText("`r`n[ERROR] ######!!!!!!!!!!! All ESXi hosts are full  !!!!!!!!!!######`r`n`r`n")
            LogWrite "`n[ERROR] ######!!!!!!!!!!! All ESXi hosts are full  !!!!!!!!!!######`n`n"
            $lastgoodi = $i - 1
            $lastgood = $Org_VMName + "-" + $lastgoodi.ToString("00")

            Write-Host -ForeGroundColor Yellow "[DEBUG]  Cloning stopped. Last Good VM: $lastgood.`n"
            $outputBox.AppendText("[DEBUG]  Cloning stopped. Last Good VM: $lastgood.`r`n`r`n")
            LogWrite "[DEBUG]  Cloning stopped. Last Good VM: $lastgood.`n`n"
            LogWrite "#################################################################################`n"
            Write-Host -ForeGroundColor Red "#################################################################################`n"
            $outputBox.AppendText("#################################################################################`r`n`r`n")

            #Start-sleep -s 2
            $deploymentloop = $lastgoodi
            continue
            #break
        }

        #$destHost = $Hosting
        Write-Host -ForeGroundColor Green "[INFO] ESXi host $Hosting has been choosing to host the VM $destVMName"
        $outputBox.AppendText("[INFO] ESXi host $Hosting has been choosing to host the VM $destVMName`r`n")
        LogWrite "[INFO] ESXi host $Hosting has been choosing to host the VM $destVMName`n"

        # Cloning
        $vm = get-vm $srcvm -ErrorAction Stop | get-view -ErrorAction Stop
	    $cloneSpec = new-object VMware.VIM.VirtualMachineCloneSpec
	    $cloneSpec.Location = new-object VMware.VIM.VirtualMachineRelocateSpec
	    if ($CloneType -eq "linked")
	    {
		    $cloneSpec.Location.DiskMoveType = [VMware.VIM.VirtualMachineRelocateDiskMoveOptions]::createNewChildDiskBacking
	    }
	    Write-Host -ForeGroundColor Green "[INFO] Selecting Datastore: $targetDSName"
	    $newDS = Get-Datastore $targetDSName | Get-View
	    $CloneSpec.Location.Datastore =  $newDS.summary.Datastore
        Write-Host -ForeGroundColor Green "[INFO] Cloning on Snapshot: $srcSnapshot"
        Set-VM -vm $srcVM -snapshot (Get-Snapshot -vm $srcVM -Name $srcSnapshot) -confirm:$false
        $cloneSpec.Snapshot = $vm.Snapshot.CurrentSnapshot
	    $cloneSpec.Location.Host = (get-vmhost -Name $destHost).Extensiondata.MoRef
	    #$CloneSpec.Location.Pool = (Get-ResourcePool -Name Resources -Location (Get-VMHost -Name $destHost)).Extensiondata.MoRef
        # Start the Clone task using the above parameters
	    $task = $vm.CloneVM_Task($vm.parent, $destVMName, $cloneSpec)
        # Get the task object
	    $task = Get-Task | where { $_.id -eq $task }
        #Wait for the taks to Complete
        Wait-Task -Task $task

        $newvm = Get-vm $destVMName
        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[INFO] $time- VM $newvm Cloned.`n"
        $customSpec = Get-OSCustomizationSpec $cSpec
        Set-vm -OSCustomizationSpec $cSpec -vm $newvm -confirm:$false
	    if ($disableVMConsole -eq "yes")
	    {
		    Disable_VM_Console($destVMName)
	    }
        # Add GPU card passthrough

        $ObjHost = Get-EsxCli -VMHost $destHost
        $GPUsIdslist = $ObjHost.hardware.pci.list("0x300") | Where-Object {$_.ModuleName -eq "pciPassthru"} | select -Property Address
        [array]::Reverse($GPUsIdslist)

        $GpuConf=get-vmhost $destHost | get-vm | get-view
        $IdList = $GpuConf.config.hardware.device | ?{$_.Backing -is "VMware.Vim.VirtualPCIPassthroughDeviceBackingInfo"} | Select-Object  -Property @{N="Id";E={$_.Backing.Id}}
        $SlotLeft = 4 - $IdList.Id.Count
        "-----------------------------------------------------"
        Write-Host -ForeGroundColor Yellow "[DEBUG] The Host '$destHost' has  # $SlotLeft #  GPU slots left."
        $outputBox.AppendText("[DEBUG] The Host '$destHost' has  # $SlotLeft #  GPU slots left.`r`n")
        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[DEBUG] The Host '$destHost' has  # $SlotLeft #  GPU slots left.'"
        "-----------------------------------------------------"
        foreach ($Idline in $GPUsIdslist)
      {
         if ($IdList -ne $null)
         {
            if (!($IdList.Id.Contains($Idline.Address)))
            {
                $GPUID = $Idline.Address
                #continue
            }
          }
          else
          {
             $GPUID = $GPUsIdslist[3].Address
          }
      }
        "-----------------------------------------------------"
        Write-Host -ForeGroundColor Green "[INFO] PCI Device with ID '$GPUID' from the host '$destHost' is going to be added to the VM '$destVMName'"
        $outputBox.AppendText("[INFO] PCI Device with ID '$GPUID' from the host '$destHost' is going to be added to the VM '$destVMName'`r`n")
        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[INFO] $time- PCI Device with ID '$GPUID' from the host '$destHost' is going to be added to the VM '$destVMName'"
        "-----------------------------------------------------"

        add-uniquepcipassthroughdevice $newvm $GPUID $destHost

        Start-Sleep -s 1

        $g=get-view -viewtype VirtualMachine -filter @{"Name"=$destVMName}
        $h=$g.config.hardware.device | ?{$_.Backing -like "*Pass*"}
        $h.backing

        $gpuvm = Get-VM $newvm
        $device = Get-PassthroughDevice -VM $gpuvm -Type Pci
        $devname = $device.Name

        $devid = $h.backing.Id

        "-----------------------------------------------------"
        Write-Host -ForeGroundColor Green "[INFO] PCI Device '$devname' with ID: ' $devid ' has been added to the VM '$newvm'`n"
        $outputBox.AppendText("[INFO] PCI Device '$devname' with ID: ' $devid ' has been added to the VM '$newvm'`r`n`n")
        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[INFO] $time- PCI Device '$devname' with ID: ' $devid ' has been added to the VM '$newvm'`n`n"
        "-----------------------------------------------------"

        foreach ($vm in (get-vm $newvm)) {get-vmresourceconfiguration $vm | set-vmresourceconfiguration -MemReservationMB $vm.MemoryMB}

        #Start-Sleep -s 2

        #Configure VLAN setting
        $NetworkAdapter = Get-NetworkAdapter -VM $newvm
        Set-NetworkAdapter -NetworkAdapter $NetworkAdapter -NetworkName 'VLAN 514 (blade)' -Confirm:$false 
        $time = date -Format dd/MM/yy`thh:mm:ss.m
        Write-Host -ForeGroundColor Green "[INFO] Link the VM $newvm to the appropriate VLAN.`n"
        LogWrite "[INFO] $time- Link the VM $newvm to the appropriate VLAN.`n"
        $outputBox.AppendText("[INFO] Link the VM $newvm to the appropriate VLAN.`r`n")

        # Start the VM
        Start-VM $newvm
        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[INFO] $time- Starting the VM $newvm.`n"
        $outputBox.AppendText("[INFO] Starting the VM $newvm.`r`n")

        Start-Sleep -s 1

        # Connect the VM to the network
        $NetworkAdapter = Get-NetworkAdapter -VM $newvm
        Set-NetworkAdapter -NetworkAdapter $NetworkAdapter -StartConnected:$true -Connected:$true -Confirm:$false
        $outputBox.AppendText("[INFO] Network connectivity of the VM '$newvm' checked.`r`n")
        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[INFO] $time- Network connectivity checked.`n"

        $time = date -Format dd/MM/yy`thh:mm:ss.m
        Write-Host -ForeGroundColor Green "[INFO] VM $newvm Cloned successfuly. Moving to next VM.`n"
        Write-Host -ForeGroundColor Green "#################################################################################`n"
        $outputBox.AppendText("[INFO] VM $newvm Cloned successfuly. Moving to next VM.`r`n")
        $outputBox.AppendText("#################################################################################.`r`n")
        LogWrite "[INFO] $time- VM $newvm cloned with success. Moving to next VM.`n"
        LogWrite "#################################################################################`n"
        #$outputBox.AppendText("###############  VM $newvm Cloned successfuly. Moving to next VM  ##############`r`n")
        $outputBox.SelectionStart = $outputBox.Text.Length
        $outputBox.ScrollToCaret()

        $i = $i+1

        [Console]::ResetColor()

        }
        
        
        #$j=0
        #$i=1

    while ($false) #($i -le $deploymentloop)     ############# Disabling Horizon Agent installation. It is now performed via an Ansible script (faster)
    {
        $destVMName = $Org_VMName + "-" + $i.ToString("00")

        $j=$j+1
        $VMName = $destVMName
        $newvm = Get-vm $destVMName

        write-host -ForeGroundColor Yellow "`n############ Configure: $j #### VM: $VMName      ##########`n"
        $outputBox.AppendText("`r`n############ Configure: $j #### VM: $VMName     ##########`r`n")
        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[INFO] $time- Configuring the VM: $VMName started.`n"

        $Ipchecker = $newvm.Guest.IPAddress.Count.ToString()
        $timerout = 0
        $Ipchecker = ""

        While (!($newvm.Guest.IPAddress.Count -ige 2 -or $timerout -ige 18)){

        Start-Sleep -s 10
        $timerout = $timerout + 1

        $newvm = Get-vm $destVMName
        $Ipchecker = $newvm.Guest.IPAddress.Count.ToString()

        Write-Host -ForeGroundColor Yellow "VM $newvm is still Offline. Sys-IP nbrs: $Ipchecker"

        }

        if ( $timerout -ige 18 -and !($newvm.Guest.IPAddress.Count -ige 2))
        {

            Write-Host -ForeGroundColor Red "#################################################################################"
            Write-Host -ForeGroundColor Red "The VM $newvm is having a network issue. Moving to the next VM."
            Write-Host -ForeGroundColor Red "#################################################################################`n"
            $time = date -Format dd/MM/yy`thh:mm:ss.m
            LogWrite "[ERROR] $time- The VM $newvm is having a network issue. Moving to the next VM.`n"
            $outputBox.AppendText("#################################################################################`r`n")
            $outputBox.AppendText("[ERROR] The VM $newvm is having a network issue. Moving to the next VM.`r`n")
            $outputBox.AppendText("#################################################################################`r`n`r`n")
            LogWrite "#################################################################################`n"
            $i = $i+1
            continue
        }
        else
        {
            $NewVMIPaddr = $newvm.guest.IPAddress[0]
            $counttimer = $timerout * 10
            Write-Host -ForeGroundColor Green "`n[INFO] VM $newvm is Online with IP @: $NewVMIPaddr.`n"  # Wait time: $counttimer sec.
            $time = date -Format dd/MM/yy`thh:mm:ss.m
            LogWrite "[INFO] $time- VM $newvm is now Online with IP address: $NewVMIPaddr. After a wait of $counttimer sec.`n"
            $outputBox.AppendText("[INFO] VM $newvm is now Online with IP address: $NewVMIPaddr. After a wait of $counttimer sec.`r`n")
        }

        # Installing and configuring eth Horizon agent on the VM
        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[INFO] $time- Configuring VM $newvm to install Horizon Agent."

        #Remove old installation and configuration folders
        #$cmd = "sudo /usr/lib/vmware/viewagent/bin/uninstall_viewagent.sh; sudo rm /etc/vmware/viewagent-conf*; sudo rm /etc/vmware/viewagent-machine*;  sudo rm -r /etc/vmware/ssl; sudo rm -r /etc/vmware/jms; sudo rm -r $destFolder/VMware-*-linux-*"
        #Write-Host -ForeGroundColor Yellow "[DEBUG] Uninstall old view agent and removing of old configuration."
        #$outputBox.AppendText("[DEBUG] Uninstall old view agent and removing of old configuration.`r`n")
        #RunCmdViaSSH -VM_Name $newvm -User $guestUser -Password $guestPassword -Cmd $cmd

        #Configure Hostname for the VM
        #$cmd = "sudo chmod 777  " + $destFolder + "hostnamer.sh; sudo " + $destFolder + "hostnamer.sh $VMName"
        #Write-Host -ForeGroundColor Green "[INFO] VM $VMName hostname configuration."
        #$outputBox.AppendText("[INFO] VM $VMName hostname configuration.`r`n")
        #UploadFileViaSSH -VM_Name $newvm -User $guestUser -Password $guestPassword -LocalPath ".\hostnamer.sh" -DestPath $destFolder
        #RunCmdViaSSH -VM_Name $newvm -User $guestUser -Password $guestPassword -Cmd $cmd

        #Upload installer tar ball to Linux VM
        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[INFO] $time- Upload installer tar ball to Linux VM $newvm."
        Write-Host -ForeGroundColor Green "[INFO] Upload the Horizon Agent tar ball: '$agentInstaller' to the VM '$newvm' with user '$guestUser'."
        $outputBox.AppendText("[INFO] Upload the Horizon Agent tar ball: '$agentInstaller' to the VM '$newvm' with user '$guestUser'.`r`n")
        UploadFileViaSSH -VM_Name $newvm -User $guestUser -Password $guestPassword -LocalPath $agentInstaller -DestPath $destFolder

        #Extract the installer
        Write-Host -ForeGroundColor Yellow "$newvm : Extract the installer and install VHCI"
        $cmd = "tar -xvf VMware-*-linux-*.tar*; cd /usr/local/vhci-hcd-1.15; sudo  make; sudo make install"
        Write-Host -ForeGroundColor Yellow "Run cmd '$cmd' in VM '$newvm' with user '$guestUser'"
        $taroutput = RunCmdViaSSH -VM_Name $newvm -User $guestUser -Password $guestPassword -Cmd $cmd

        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[INFO] $time- Start the installation and registration to the Horizon connection server.`n"
        # Start the installation and registration to the Horizon connection server
        $cmd = "cd VMware-*-linux* && sudo ./install_viewagent.sh -r yes -a yes -A yes $newvm -b $brokerAddress -d $domainName -u $brokerAdminName -p $brokerAdminPassword"
        Write-Host -ForeGroundColor Yellow "[INFO] Run the Horizon agent installation and registration with VM name '$newvm' using the user '$guestUser'."
        $outputBox.AppendText("[INFO] Run the Horizon agent installation and registration with VM name '$newvm' using the user '$guestUser'..`r`n")
        RunCmdViaSSH -VM_Name $newvm -User $guestUser -Password $guestPassword -Cmd $cmd
        Write-Host -ForeGroundColor Yellow "Linux Agent installer will reboot the Linux VM after installation, and you may hit the ssh connection closed error message, which is expectation.`n"


        $time = date -Format dd/MM/yy`thh:mm:ss.m
        Write-Host -ForeGroundColor Green "[INFO] VM $newvm Configured successfuly. Moving to next VM...`n"
        Write-Host -ForeGroundColor Green "#################################################################################`n"
        LogWrite "[INFO] $time- VM $newvm Configured successfully. Moving to next VM...`n"
        LogWrite "#################################################################################`n"
        $outputBox.AppendText("[INFO] VM $newvm Configured successfuly. Moving to next VM...`r`n")
        $outputBox.AppendText("#################################################################################`r`n")
        $outputBox.SelectionStart = $outputBox.Text.Length
        $outputBox.ScrollToCaret()

        $i = $i+1

        [Console]::ResetColor()
    }

    if ($deploymentloop -gt 1)
    {

    Start-Sleep -s 5
    Write-Host -ForeGroundColor Green "`n#################################################################"
    $outputBox.AppendText("#################################################################`r`n")
    $outputBox.AppendText("[INFO] Gathering IP addresses...`r`n`r`n")
    $outputBox.AppendText("#################################################################`r`n")
    Write-Host -ForeGroundColor Yellow "[INFO] Gathering IP addresses...`n"

    Write-Host -ForeGroundColor Green "`#################################################################`n"
    $VMName = $destVMName
    $newvm = Get-vm $destVMName
    $Ipchecker = $newvm.Guest.IPAddress.Count.ToString()
    $timerout = 0
    $Ipchecker = ""

    While (!($newvm.Guest.IPAddress.Count -ige 2 -or $timerout -ige 18)){

    Start-Sleep -s 10
    $timerout = $timerout + 1

    $newvm = Get-vm $destVMName
    $Ipchecker = $newvm.Guest.IPAddress.Count.ToString()

    Write-Host -ForeGroundColor Yellow "[DEBUG] Awaiting last configured VM to properly Power On..."
    $outputBox.AppendText("[DEBUG] Awaiting last configured VM to properly Power On...`r`n")
    }

    $VMfile = $Org_VMName
    $VMlist = $Org_VMName + "*"

    $time = date -Format dd/MM/yy`thh:mm:ss.m
    LogWrite "[INFO] $time- Gathering IP addresses... `n"

    $VMIPaddress = "\\penelopeprime.courses.ebi.ac.uk\shared\Scripts\IP_CSV\" + $VMfile +"_IP_Address.csv"

    #Write-Host -ForeGroundColor Green "[INFO] VM IP addresses list file will be stored to: `n$VMIPaddress"
    #$outputBox.AppendText("[INFO] VM IP addresses list file will be stored to: `n$VMIPaddress`r`n")
    $time = date -Format dd/MM/yy`thh:mm:ss.m
    LogWrite "[INFO] $time- The VM list is stored at: $VMIPaddress`n"

    Get-VM $VMlist | select Name, @{N="IPAddress";E={@($_.guest.IPAddress -like '10.7.*')}} | ft -auto | out-file $VMIPaddress -Encoding ASCII

    Write-Host -ForeGroundColor Green "[INFO] IP Address has been gathered and saved into $VMIPaddress"
    $outputBox.AppendText("[INFO] IP Address has been gathered and saved into $VMIPaddress`r`n")
    notepad.exe $VMIPaddress
    LogWrite "#################################################################################`n"
    }

    Write-Host -ForeGroundColor Green "[INFO] VM cloning Done."
    $outputBox.AppendText("[INFO] Virtual Machines cloning Done.`r`n")
    $outputBox.SelectionStart = $outputBox.Text.Length
    $outputBox.ScrollToCaret()
    $time = date -Format dd/MM/yy`thh:mm:ss.m
    LogWrite "[INFO] $time- There is no Next VM. Script is done. Exiting.`n"
    $timedate1 = date -Format dd/MM/yy`thh:mm:ss.m
    LogWrite "[INFO]- The script has ended at: $timedate1"
    LogWrite "#################################################################################`n"
    LogWrite "#################################################################################`n"
    Disconnect-VIServer $vcAddress -Confirm:$false

    }



########################################################################################################
############################# VM Operations code #######################################################
########################################################################################################

    elseif ($global:init_vmops -eq $true -and $global:vmop -eq $true)
    {

    Write-Host -ForeGroundColor Green "`n#################################################################"
    $Org_VMName= $VMName_InputBox.Text
    Write-Host -ForeGroundColor Yellow "[INFO] VMs clones common name: $Org_VMName"
    Write-Host -ForeGroundColor Green "#################################################################`n"


    "-----------------------------------------------------"
    Check_SSH_Client -IsPlink $true -IsPSCP $true
    "-----------------------------------------------------"

    if ($vmcon_checkbox.Checked -eq $true)
    {
        $disableVMConsole = "yes"
        Write-Host -ForeGroundColor Green "[INFO] Disabling VM Console."
    }
    else
    {
        $disableVMConsole = "no"
        Write-Host -ForeGroundColor Green "[INFO] Leaving VM Console enabled"
    }

    $CloneType = $Type_DropDownBox.SelectedItem.ToString()
    Write-Host -ForeGroundColor Green "[INFO] Cloning Type selected: $CloneType"

    $srcVM = $Par_VMName_InputBox.Text
    Write-Host -ForeGroundColor Green "[INFO] Parent VM selected: $srcVM"

    $cSpec = $spec_InputBox.Text
    Write-Host -ForeGroundColor Green "[INFO] Custom Spec selected: $cSpec"

    $targetDSName = $data_DropDownBox.SelectedItem.ToString()
    Write-Host -ForeGroundColor Green "[INFO] Data Store selected: $targetDSName"

    $srcSnapshot = $snap_InputBox.Text
    Write-Host -ForeGroundColor Green "[INFO] Snapshot selected: $srcSnapshot"

    $deleteExisting = $del_checkbox.Checked
    Write-Host -ForeGroundColor Green "[INFO] Delete existing VM: $deleteExisting"

    $agentInstaller = $global:agentInstaller
    Write-Host -ForeGroundColor Green "[INFO] Agent tar ball selected: $agentInstaller"

    $brokerAddress = $broAdd_InputBox.Text
    Write-Host -ForeGroundColor Green "[INFO] Broker Address selected: $brokerAddress"

    $brokerAdminName = $broAdm_InputBox.Text
    Write-Host -ForeGroundColor Green "[INFO] Broker Admin Username selected: $brokerAdminName"

    $brokerAdminPassword = $bropass_InputBox.Text
    Write-Host -ForeGroundColor Green "[INFO] A Broker Admin Password has been selected."

    $domainName = $domain_InputBox.Text
    Write-Host -ForeGroundColor Green "[INFO] Domain Name selected: $domainName"

    $vcAddress = $vcAdd_InputBox.Text
    Write-Host -ForeGroundColor Green "[INFO] VCenter Address selected: $vcAddress"

    $vcAdmin = $vcAdm_InputBox.Text
    Write-Host -ForeGroundColor Green "[INFO] VCenter Admin username selected: $vcAdmin"

    $vcPassword = $vcpass_InputBox.Text
    Write-Host -ForeGroundColor Green "[INFO] A VCenter Admin Password has been selected."

    $guestUser = $gstusr_InputBox.Text
    Write-Host -ForeGroundColor Green "[INFO] Guest OS User username selected: $guestUser"

    $guestPassword = $gstpass_InputBox.Text
    Write-Host -ForeGroundColor Green "[INFO] A Guest OS user password has been selected."

    if ($vmrng_checkbox.Checked -eq $false)
    {
        $vm_nbr = $vmnbr_InputBox.Text
        Write-Host -ForeGroundColor Green "[INFO] Number of VM Clones selected: $vm_nbr"
    }
    else
    {
        $vm_str_nbr = $vmstrnbr_InputBox.Text
        $vm_nbr = $vmendnbr_InputBox.Text
        Write-Host -ForeGroundColor Green "[INFO] Range of VM Clones selected is from $vm_str_nbr to $vm_nbr"
    }
    
    Write-Host -ForeGroundColor Green "#################################################################`n"



    # Logging the deployment
    $logDateTime = date -Format dd_MM_yy
    $global:Logfile = "C:\scripts\logs\" + $VMName_InputBox.text + $logDateTime + ".log"
    Write-Host -ForeGroundColor Green "[INFO] Log file is: $global:Logfile `n"
    $timedate = date -Format dd/MM/yy`thh:mm:ss.m
    $VMOpswelcome = $VMOps_DropDownBox.SelectedItem.ToString()
    LogWrite "##############################################################################`n"
    LogWrite "[INFO]- VM Operations @@  $VMOpswelcome  @@  Started."
    LogWrite "[INFO]- This script has started at: $timedate."
    LogWrite "[INFO]- Linux Horizon Agent EULA licence Accepted."
    #LogWrite "[INFO]- Cloning type selected is: $CloneType"
    LogWrite "[INFO]- VMware Horizon Agent archive selected: $agentInstaller."
    LogWrite "[INFO]- Parent VM selected: $srcVM."
    LogWrite "[INFO]- Custom Spec selected: $cSpec."
    #LogWrite "[INFO]- Data Store selected: $targetDSName."
    LogWrite "[INFO]- Snapshot selected: $srcSnapshot."
    LogWrite "[INFO]- VMs clones common name: $Org_VMName"
    LogWrite "[INFO]- Horizon Connection server to authenticate with is: $brokerAddress.`n"
    LogWrite "[INFO]- Horizon Connection server Admin connected: $brokerAdminName.`n"
    LogWrite "[INFO]- VCenter server used is: $vcAddress.`n"
    LogWrite "[INFO]- VCenter Admin runnign the deployment is: $vcAdmin.`n"
    LogWrite "[INFO]- Guest OS user used: $vcAddress.`n"
    if ($vmrng_checkbox.Checked -eq $false)
    {
        LogWrite "[INFO]- Number of VM Clones is: $vm_nbr.`n"
    }
    else
    {
        LogWrite "[INFO]- Range of VM Clones is from: $vm_str_nbr to: $vm_nbr.`n"
    }
    LogWrite "##############################################################################`n"

    #Connect to vCenter
    [Console]::ResetColor()
    if (!( $vcAdm_InputBox.Text -eq "" -or $vcpass_InputBox.Text -eq ""))
    { Connect-VIServer $vcAddress -user $vcAdmin -password $vcPassword }
    else { Connect-VIServer $vcAddress }

    $time = date -Format dd/MM/yy`thh:mm:ss.m
    LogWrite "[INFO] $time- Connecting to vCenter Address: $vcAddress."

    $destFolder = "/home/$guestUser/"

    $destHostList1 = "hx-vdi-hyp167.ebi.ac.uk", "hx-vdi-hyp168.ebi.ac.uk", "hx-vdi-hyp169.ebi.ac.uk", "hx-vdi-hyp170.ebi.ac.uk", 
    "hx-vdi-hyp171.ebi.ac.uk", "hx-vdi-hyp172.ebi.ac.uk", "hx-vdi-hyp173.ebi.ac.uk", "hx-vdi-hyp174.ebi.ac.uk"

    $destHostList2 = $destHostList1.Clone()
    [array]::Reverse($destHostList2)
    
    #$destHostList1 = "hx-vdi-hyp167.ebi.ac.uk", "hx-vdi-hyp168.ebi.ac.uk", "hx-vdi-hyp169.ebi.ac.uk","hx-vdi-hyp170.ebi.ac.uk", "hx-vdi-hyp171.ebi.ac.uk", 
    #"hx-vdi-hyp172.ebi.ac.uk", "hx-vdi-hyp173.ebi.ac.uk", "hx-vdi-hyp174.ebi.ac.uk"

    #$destHostList2 = "hx-vdi-hyp174.ebi.ac.uk", "hx-vdi-hyp173.ebi.ac.uk", "hx-vdi-hyp172.ebi.ac.uk", "hx-vdi-hyp171.ebi.ac.uk", "hx-vdi-hyp170.ebi.ac.uk",
    #  "hx-vdi-hyp169.ebi.ac.uk", "hx-vdi-hyp168.ebi.ac.uk", "hx-vdi-hyp167.ebi.ac.uk"

    $VMOpswelcome = $VMOps_DropDownBox.SelectedItem.ToString()
    Write-Host -ForeGroundColor Green "#################################################################"
    write-host -ForeGroundColor Yellow "[INFO] VM Operations @@  $VMOpswelcome  @@  Started."
    $outputBox.AppendText("[INFO] VM Operations @@  $VMOpswelcome  @@  Started.`r`n")
    Write-Host -ForeGroundColor Green "#################################################################"
    [Console]::ResetColor()

    [int]$operationloop = [convert]::ToInt32($vm_nbr, 10)
    $j=0
    if ($vmrng_checkbox.Checked -eq $false)
    {
        [int]$i=1
    }
    else
    {
        [int]$i=[convert]::ToInt32($vm_str_nbr, 10)
    }

    while ($i -le $operationloop)
    {
        $destVMName = $Org_VMName + "-" + $i.ToString("00")   # + "-"

        $j=$j+1
        $VMName = $destVMName
        write-host -ForeGroundColor Yellow "`n############ Operation Nbr: $j  On: $VMName      ##########`n"
        $outputBox.AppendText("`r`n############ Operation Nbr: $j  On: $VMName     ##########`r`n")

        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[INFO] $time- Working on the VM: $VMName.`n"

        #####################################################################
        #
        #
        # "(1). Power On", "(2). Power Off", "(3) Shut VM Guest", "(4). Restart VM", "(5). Restart VM Guest", "(6). Delete VM", "(7). Add GPU PCI Device", "(8). Install Horizon Agent",
        # "(9). Add Network Card", "(10). Connect Network Card", "(11). Get VM IP Address", "(12). Set Linux VM Hostname","(13). Install Nvidia Driver on Linux VM",
        # "(14). Migrate VMs equally between Hosts", "(15). Clone VMs for an Inactive pool", "(16) Remove GPU from VM", "(17). Change network VLAN configuration"
        #
        #
        #####################################################################

        switch ($VMOps_DropDownBox.SelectedItem.ToString())
    {
      "(1). Power On"
      {

        write-host -ForeGroundColor Green "[INFO] Starting VM $VMName..."
        $outputBox.AppendText("[INFO] Starting VM $VMName...`r`n")
        Get-VM $VMName | where { $_.PowerState –eq "PoweredOff" } | Start-VM -Confirm:$false
        $outputBox.AppendText("#################################################################################`r`n`r`n")
        Write-Host -ForeGroundColor Green "#################################################################################`n"
        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[INFO] $time- Starting VM: $VMName."

      }
      "(2). Power Off"
      {
        write-host -ForeGroundColor Green "[INFO] Stopping VM $VMName..."
        $outputBox.AppendText("[INFO] Stopping VM $VMName...`r`n")
        Get-VM $VMName | where { $_.PowerState –eq "PoweredOn" } | Stop-VM -Confirm:$false
        $outputBox.AppendText("#################################################################################`r`n`r`n")
        Write-Host -ForeGroundColor Green "#################################################################################`n"
        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[INFO] $time- Shutting down VM: $VMName."
      }
      "(3) Shut VM Guest"
      {
        write-host -ForeGroundColor Green "[INFO] Shutting down VM $VMName Guest..."
        $outputBox.AppendText("[INFO] Shutting down VM $VMName Guest...`r`n")
        Get-VM $VMName | where { $_.PowerState –eq "PoweredOn" }  | Shutdown-VMGuest -Confirm:$false
        $outputBox.AppendText("#################################################################################`r`n`r`n")
        Write-Host -ForeGroundColor Green "#################################################################################`n"
        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[INFO] $time- Shutting down VMGuest of: $VMName."
      }
      "(4). Restart VM"
      {
        write-host -ForeGroundColor Green "[INFO] Restarting VM $VMName..."
        $outputBox.AppendText("[INFO] Restarting VM $VMName Guest...`r`n")
        Get-VM $VMName | where { $_.PowerState –eq "PoweredOn" }  | Restart-VM -Confirm:$false
        $outputBox.AppendText("#################################################################################`r`n`r`n")
        Write-Host -ForeGroundColor Green "#################################################################################`n"
        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[INFO] $time- Restarting VM: $VMName."
      }
      "(5). Restart VM Guest"
      {
        write-host -ForeGroundColor Green "[INFO] Restarting VM $VMName Guest..."
        $outputBox.AppendText("[INFO] Restarting VM $VMName Guest...`r`n")
        Get-VM $VMName | where { $_.PowerState –eq "PoweredOn" }  | Restart-VMGuest -Confirm:$false
        $outputBox.AppendText("#################################################################################`r`n`r`n")
        Write-Host -ForeGroundColor Green "#################################################################################`n"
        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[INFO] $time- Restarting VMGuest of: $VMName."
      }
      "(6). Delete VM"
      {

        if (IsVMExists ($VMName))
	       {
              write-host -ForeGroundColor Green "[INFO] Deleting VM $VMName..."
              $outputBox.AppendText("[INFO] Deleting VM $VMName...`r`n")
              Delete_VM ($VMName)
              $time = date -Format dd/MM/yy`thh:mm:ss.m
              LogWrite "[INFO] $time- Deleting VM: $VMName."
	        }

        $outputBox.AppendText("[INFO] VM $VMName Deleted.`r`n")
        Write-Host -ForeGroundColor Green "[INFO] VM $VMName Deleted."
        $outputBox.AppendText("#################################################################################`r`n`r`n")
        Write-Host -ForeGroundColor Green "#################################################################################`n"

        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[INFO] $time- VM: $VMName deleted."

       }





       "(7). Add GPU PCI Device"
      {
        
        # Add PCi device GPU
        Get-VM $VMName | where { $_.PowerState –eq "PoweredOn" } | Stop-VM –confirm:$false

        foreach ($vm in (get-vm $VMName)) {get-vmresourceconfiguration $vm | set-vmresourceconfiguration -MemReservationMB $vm.MemoryMB}

        $GPUID = "null"

        get-vm $VMName | get-passthroughdevice | remove-passthroughdevice -Confirm:$false

        $newvm = Get-vm $VMName

        $destHost = $newvm.VMHost.Name

        $ObjHost = Get-EsxCli -VMHost $destHost
        $GPUsIdslist = $ObjHost.hardware.pci.list("0x300") | Where-Object {$_.ModuleName -eq "pciPassthru"} | select -Property Address
        [array]::Reverse($GPUsIdslist)

        #get VMs from a host

        $GpuConf=get-vmhost $destHost | get-vm | get-view

        $IdList = $GpuConf.config.hardware.device | ?{$_.Backing -is "VMware.Vim.VirtualPCIPassthroughDeviceBackingInfo"} | Select-Object  -Property @{N="Id";E={$_.Backing.Id}}

        $SlotLeft = 4 - $IdList.Id.Count

        "-----------------------------------------------------"
        Write-Host -ForeGroundColor Yellow "[DEBUG] The Host '$destHost' has  # $SlotLeft #  GPU slots left."
        $outputBox.AppendText("[DEBUG] The Host '$destHost' has  # $SlotLeft #'  GPU slots left.`r`n")
        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[DEBUG] The Host '$destHost' has  # $SlotLeft #  GPU slots left.'"
        "-----------------------------------------------------"

        foreach ($Idline in $GPUsIdslist)
        {
            if ($IdList -ne $null)
            {
            if (!($IdList.Id.Contains($Idline.Address)))
            {
                $GPUID = $Idline.Address
                #continue
            }
            }
            else
            {
               $GPUID = $GPUsIdslist[3].Address
            }
        }

        if ($GPUID.Equals("null"))
        {
            "-----------------------------------------------------"
            Write-Host -ForeGroundColor Red "`n[ERROR] The host '$destHost' has no free GPU. Please Migrate the VM '$VMName' to a host with available GPUs.`n"
            $outputBox.AppendText("`n[ERROR] The host '$destHost' has no free GPU. Please Migrate the VM '$VMName' to an ESXi host with available GPUs.`r`n`r`n")
            $time = date -Format hh:mm:ss.ms
            LogWrite "`n[ERROR] $time- The host '$destHost' has no free GPU. Please Migrate the VM '$VMName' to a host with available GPUs.`n"
            "-----------------------------------------------------"
            #$operationloop = $i
            continue

        }

        "-----------------------------------------------------"
        Write-Host -ForeGroundColor Green "[INFO] PCI Device with ID '$GPUID' from the host '$destHost' is going to be added to the VM '$destVMName'"
        $outputBox.AppendText("[INFO] PCI Device with ID '$GPUID' from the host '$destHost' is going to be added to the VM '$destVMName'`r`n")
        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[INFO] $time- PCI Device with ID '$GPUID' from the host '$destHost' is going to be added to the VM '$destVMName'"
        "-----------------------------------------------------"

        add-uniquepcipassthroughdevice $VMName $GPUID $destHost

        Start-Sleep -s 1

        $g=get-view -viewtype VirtualMachine -filter @{"Name"=$VMName}
        $h=$g.config.hardware.device | ?{$_.Backing -like "*Pass*"}
        $h.backing

        $gpuvm = Get-VM $newvm
        $device = Get-PassthroughDevice -VM $gpuvm -Type Pci
        $devname = $device.Name

        $devid = $h.backing.Id


        "-----------------------------------------------------"
        Write-Host -ForeGroundColor Green "[INFO] PCI Device '$devname' with ID: ' $devid ' has been added to the VM '$newvm'"
        $outputBox.AppendText("[INFO] PCI Device '$devname' with ID: ' $devid ' has been added to the VM '$newvm'`r`n")
        $outputBox.AppendText("#################################################################################`r`n`r`n")
        Write-Host -ForeGroundColor Green "#################################################################################`n"
        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[INFO] $time- PCI Device '$devname' with ID: ' $devid ' has been added to the VM '$newvm'`n`n"
        "-----------------------------------------------------"
        #foreach ($vm in (get-vm $newvm)) {get-vmresourceconfiguration $vm | set-vmresourceconfiguration -MemReservationMB $vm.MemoryMB}

        #Start-Sleep -s 3

        # Start the VM
	    Start-VM $VMName

        $time = date -Format hh:mm:ss.ms
        LogWrite "[INFO] $time- PCI Device Added to VM $VMName`n"
        LogWrite "#################################################################################`n"
      }








       "(8). Install Horizon Agent"
       {
        $destVMName = $Org_VMName + "-" + $i.ToString("00")


        $VMName = $destVMName
        $newvm = Get-vm $VMName
        Get-VM $VMName | where { $_.PowerState –eq "PoweredOff" } | Start-VM -Confirm:$false

        write-host -ForeGroundColor Yellow "`n############ Installing Horizon Agent: $j #### VM: $VMName      ##########`n"
        $outputBox.AppendText("`r`n############ Installing Horizon Agent: $j #### VM: $VMName     ##########`r`n")
        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[INFO] $time- Installing Horizon Agent on VM: $VMName started.`n"


        $Ipchecker = $newvm.Guest.IPAddress.Count.ToString()
        $timerout = 0
        $Ipchecker = ""

        While (!($newvm.Guest.IPAddress.Count -ige 2 -or $timerout -ige 18)){

        Start-Sleep -s 10
        $timerout = $timerout + 1

        $newvm = Get-vm $destVMName
        $Ipchecker = $newvm.Guest.IPAddress.Count.ToString()

        Write-Host -ForeGroundColor Yellow "VM $newvm is still Offline. Sys-IP nbrs: $Ipchecker"

        }

        if ( $timerout -ige 18 -and !($newvm.Guest.IPAddress.Count -ige 2))
        {

            Write-Host -ForeGroundColor Red "#################################################################################"
            Write-Host -ForeGroundColor Red "The VM $newvm is having a network issue. Moving to the next VM."
            Write-Host -ForeGroundColor Red "#################################################################################`n"
            $time = date -Format dd/MM/yy`thh:mm:ss.m
            LogWrite "[ERROR] $time- The VM $newvm is having a network issue. Moving to the next VM.`n"
            $outputBox.AppendText("#################################################################################`r`n")
            $outputBox.AppendText("[ERROR] The VM $newvm is having a network issue. Moving to the next VM.`r`n")
            $outputBox.AppendText("#################################################################################`r`n`r`n")
            LogWrite "#################################################################################`n"
            $i = $i+1
            continue
        }
        else
        {
            $NewVMIPaddr = $newvm.guest.IPAddress[0]
            $counttimer = $timerout * 10
            Write-Host -ForeGroundColor Green "`n[INFO] VM $newvm is Online with IP @: $NewVMIPaddr.`n"  # Wait time: $counttimer sec.
            $time = date -Format dd/MM/yy`thh:mm:ss.m
            LogWrite "[INFO] $time- VM $newvm is now Online with IP address: $NewVMIPaddr. After a wait of $counttimer sec.`n"
            $outputBox.AppendText("[INFO] VM $newvm is now Online with IP address: $NewVMIPaddr. After a wait of $counttimer sec.`r`n")
        }

        # Installing and configuring eth Horizon agent on the VM
        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[INFO] $time- Configuring VM $newvm to install Horizon Agent."

        #Remove old installation and configuration folders
        #$cmd = "sudo /usr/lib/vmware/viewagent/bin/uninstall_viewagent.sh; sudo rm /etc/vmware/viewagent-conf*; sudo rm /etc/vmware/viewagent-machine*;  sudo rm -r /etc/vmware/ssl; sudo rm -r /etc/vmware/jms; sudo rm -r $destFolder/VMware-*-linux-*"
        #Write-Host -ForeGroundColor Yellow "[DEBUG] Uninstall old view agent and removing of old configuration."
        #$outputBox.AppendText("[DEBUG] Uninstall old view agent and removing of old configuration.`r`n")
        #RunCmdViaSSH -VM_Name $newvm -User $guestUser -Password $guestPassword -Cmd $cmd

        #Configure Hostname for the VM
        #$cmd = "sudo chmod 777  " + $destFolder + "hostnamer.sh; sudo " + $destFolder + "hostnamer.sh $VMName"
        #Write-Host -ForeGroundColor Green "[INFO] VM $VMName hostname configuration."
        #$outputBox.AppendText("[INFO] VM $VMName hostname configuration.`r`n")
        #UploadFileViaSSH -VM_Name $newvm -User $guestUser -Password $guestPassword -LocalPath ".\hostnamer.sh" -DestPath $destFolder
        #RunCmdViaSSH -VM_Name $newvm -User $guestUser -Password $guestPassword -Cmd $cmd

        #Upload installer tar ball to Linux VM
        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[INFO] $time- Upload installer tar ball to Linux VM $newvm."
        Write-Host -ForeGroundColor Green "[INFO] Upload the Horizon Agent tar ball: '$agentInstaller' to the VM '$newvm' with user '$guestUser'."
        $outputBox.AppendText("[INFO] Upload the Horizon Agent tar ball: '$agentInstaller' to the VM '$newvm' with user '$guestUser'.`r`n")
        UploadFileViaSSH -VM_Name $newvm -User $guestUser -Password $guestPassword -LocalPath $agentInstaller -DestPath $destFolder

        #Extract the installer
        Write-Host -ForeGroundColor Yellow "$newvm : Extract the installer and install VHCI"
        $cmd = "tar -xvf VMware-*-linux-*.tar*; cd /usr/local/vhci-hcd-1.15; sudo  make; sudo make install"
        Write-Host -ForeGroundColor Yellow "Run cmd '$cmd' in VM '$newvm' with user '$guestUser'"
        $taroutput = RunCmdViaSSH -VM_Name $newvm -User $guestUser -Password $guestPassword -Cmd $cmd

        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[INFO] $time- Start the installation and registration to the Horizon connection server.`n"
        # Start the installation and registration to the Horizon connection server
        $cmd = "cd VMware-*-linux* && sudo ./install_viewagent.sh -r yes -a yes -A yes -n $newvm -b $brokerAddress -d $domainName -u $brokerAdminName -p $brokerAdminPassword"
        Write-Host -ForeGroundColor Yellow "[INFO] Run the Horizon agent installation and registration with VM name '$newvm' using the user '$guestUser'."
        $outputBox.AppendText("[INFO] Run the Horizon agent installation and registration with VM name '$newvm' using the user '$guestUser'..`r`n")
        RunCmdViaSSH -VM_Name $newvm -User $guestUser -Password $guestPassword -Cmd $cmd
        Write-Host -ForeGroundColor Yellow "Linux Agent installer will reboot the Linux VM after installation, and you may hit the ssh connection closed error message, which is expectation.`n"


        $time = date -Format dd/MM/yy`thh:mm:ss.m
        Write-Host -ForeGroundColor Green "[INFO] Horizon Agnet installed on VM $newvm. Moving to next VM...`n"
        Write-Host -ForeGroundColor Green "#################################################################################`n"
        LogWrite "[INFO] $time-Horizon Agnet installed on VM $newvm. Moving to next VM...`n"
        LogWrite "#################################################################################`n"
        $outputBox.AppendText("[INFO] Horizon Agnet installed on VM $newvm. Moving to next VM...`r`n")
        $outputBox.AppendText("#################################################################################`r`n")
        $outputBox.SelectionStart = $outputBox.Text.Length
        $outputBox.ScrollToCaret()

        [Console]::ResetColor()
       }
       "(9). Add Network Card"
      {
        # Adding Network adapter to the VM
        $outputBox.AppendText("[INFO] Adding Network card on VM $VMNames...`r`n")
        Write-Host -ForeGroundColor Green "[INFO] Adding Network card on VM $VMNames..."
        Get-VM $VMName | where { $_.PowerState –eq "PoweredOn" } | Stop-VM –confirm:$false

        $newvm = Get-VM $VMName
        $time = date -Format hh:mm:ss.ms
        LogWrite "[INFO] $time- Adding VM $VMName Network adpater.`n"
        New-NetworkAdapter -VM $newvm -Type Vmxnet3 -NetworkName "VLAN 513 - Training LAN (blade)" -WakeOnLan:$true -StartConnected:$true -Confirm:$false
        #Start-sleep -s 1
        Start-VM $VMName
        $outputBox.AppendText("[INFO] VM $VMNames Network Card added.`r`n")
        Write-Host -ForeGroundColor Green "[INFO] VM $VMNames Network Card added."
        $outputBox.AppendText("#################################################################################`r`n`r`n")
        Write-Host -ForeGroundColor Green "#################################################################################`n"
        $time = date -Format hh:mm:ss.ms
        LogWrite "[INFO] $time- Network adpater added. Moving to next VM`n"
        LogWrite "#################################################################################`n"
      }
       "(10). Connect Network Card"
      {
        # Connect VM network card
        $outputBox.AppendText("[INFO] Connecting Network card on VM $VMNames...`r`n")
        Write-Host -ForeGroundColor Green "[INFO] Connecting Network card on VM $VMNames..."
        $NetworkAdapter = Get-NetworkAdapter -VM $VMName
        $time = date -Format hh:mm:ss.ms
        LogWrite "[INFO] $time- Configuring VM $VMName Network adpater.`n"
        Set-NetworkAdapter -NetworkAdapter $NetworkAdapter -StartConnected:$true -Connected:$true -Confirm:$false
        $outputBox.AppendText("[INFO] VM $VMNames Network Card connected.`r`n")
        $outputBox.AppendText("#################################################################################`r`n`r`n")
        Write-Host -ForeGroundColor Green "[INFO] VM $VMNames Network Card connected."
        Write-Host -ForeGroundColor Green "#################################################################################`n"
        $time = date -Format hh:mm:ss.ms
        LogWrite "[INFO] $time- Network adpater conected. Moving to next VM`n"
        LogWrite "#################################################################################`n"

      }
       "(11). Get VM IP Address"
       {
        $VMfile = $Org_VMName
        $VMlist = $Org_VMName + "*"
        $outputBox.AppendText("[INFO] Gathering IP addresses...`r`n")
        Write-Host -ForeGroundColor Green "[INFO] Gathering IP addresses..."

        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[INFO] $time- Gathering IP addresses... `n"

        $VMIPaddress = "\\penelopeprime.courses.ebi.ac.uk\shared\Scripts\IP_CSV\" + $VMfile +"_IP_Address.csv"

        Write-Host -ForeGroundColor Green "[INFO] VM IP addresses list file will be stored to: `n$VMIPaddress"
        $outputBox.AppendText("[INFO] VM IP addresses list file will be stored to: `n$VMIPaddress`r`n")
        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[INFO] $time- The VM list is stored at: $VMIPaddress`n"

        Get-VM $VMlist | select Name, @{N="IPAddress";E={@($_.guest.IPAddress -like '10.7.*')}} | ft -auto | out-file $VMIPaddress -Encoding ASCII

        Write-Host -ForeGroundColor Green "[INFO] IP Address has been gathered and saved into $VMIPaddress"
        Write-Host -ForeGroundColor Green "#################################################################################`n"
        $outputBox.AppendText("[INFO] IP Address has been gathered and saved into $VMIPaddress`r`n")
        $outputBox.AppendText("#################################################################################`r`n`r`n")
        notepad.exe $VMIPaddress
        LogWrite "#################################################################################`n"
        $operationloop = $i           # Break the loop
        #break

       }

       "(12). Set Linux VM Hostname"
       {
        # Set VMs Hostnames
        $outputBox.AppendText("[INFO] Updating Hostname on VM $VMNames...`r`n")
        Write-Host -ForeGroundColor Green "[INFO] Updating Hostname on VM $VMNames..."

        $cmd = "sudo chmod 777  " + $destFolder + "hostnamer.sh ; sudo " + $destFolder + "hostnamer.sh $VMName ; reboot"
        Write-Host "Run Hostname changer in VM '$VMName' with user '$guestUser'"
        UploadFileViaSSH -VM_Name $VMName -User $guestUser -Password $guestPassword -LocalPath ".\hostnamer.sh" -DestPath $destFolder
        RunCmdViaSSH -VM_Name $VMName -User $guestUser -Password $guestPassword -Cmd $cmd

        $outputBox.AppendText("[INFO] Hostname update on VM $VMNames...`r`n")
        $outputBox.AppendText("#################################################################################`r`n`r`n")
        Write-Host -ForeGroundColor Green "[INFO] Hostname update on VM $VMNames..."
        Write-Host -ForeGroundColor Green "#################################################################################`n"
        $time = date -Format hh:mm:ss.ms
        LogWrite "[INFO] $time- Hostname update on VM  $VMName`n"
        LogWrite "#################################################################################`n"

       }

       "(13). Install Nvidia Driver on Linux VM"
       {

        #Install the Nvidia Driver
        $outputBox.AppendText("[INFO] Installing Nvidia Driver into VM $VMNames...`r`n")
        Write-Host -ForeGroundColor Green "[INFO] Installing Nvidia Driver into VM $VMNames..."
        $cmd = "sudo apt-get remove --purge -y nvidia*; sudo add-apt-repository -y ppa:xorg-edgers/ppasudo; sudo apt-get update; apt-get install -y nvidia-352 nvidia-settings; sudo reboot";
        Write-Host "Installing the nvidia Driver 352 usng the cmd: '$cmd'"
        $NVIDIAoutput = RunCmdViaSSH -VM_Name $VMName -User $guestUser -Password $guestPassword -Cmd $cmd
        $outputBox.AppendText("[DEBUG] VM $VMNames is about to restart to apply Nvidia driver changes.`r`n")
        Write-Host -ForeGroundColor Yelllow "[DEBUG] VM $VMNames is about to restart to apply Nvidia driver changes."
        $outputBox.AppendText("#################################################################################`r`n`r`n")
        Write-Host -ForeGroundColor Green "#################################################################################`n"

      }

#########################################################################################################################################################################################
#########################################################################################################################################################################################
#########################################################################################################################################################################################
#########################################################################################################################################################################################
       "(14). Migrate VMs equally between Hosts"
      {
        $VMName = $destVMName
        $time = date -Format dd/MM/yy`thh:mm:ss.m
        write-host -ForeGroundColor Yellow "`n############ Resources Organisation Nbr: $j   On: $VMName      ##########`n"
        $outputBox.AppendText("`r`n############ Resources Organisation Nbr: $j   On: $VMName     ##########`r`n")
        LogWrite "[INFO] $time- Organizing the resources of the VM: $VMName started.`n"
        
        Get-VM $VMName | where { $_.PowerState –eq "PoweredOn" } | Stop-VM –confirm:$false

        #foreach ($vm in (get-vm $VMName)) {get-vmresourceconfiguration $vm | set-vmresourceconfiguration -MemReservationMB $vm.MemoryMB}
        $GPUID = "null"
        get-vm $VMName | get-passthroughdevice | remove-passthroughdevice -Confirm:$false

        Write-Host -ForeGroundColor Green "[INFO] Testing the VM current host $currentHost... `n"
        $newvm = Get-vm $VMName
        $currentHost = $newvm.VMHost.Name
        $ObjHost = Get-EsxCli -VMHost $currentHost
        $GPUsIdslist = $ObjHost.hardware.pci.list("0x300") | Where-Object {$_.ModuleName -eq "pciPassthru"} | select -Property Address
        [array]::Reverse($GPUsIdslist)

        
        $GpuConf=get-vmhost $currentHost | get-vm | get-view
        $IdList = $GpuConf.config.hardware.device | ?{$_.Backing -is "VMware.Vim.VirtualPCIPassthroughDeviceBackingInfo"} | Select-Object  -Property @{N="Id";E={$_.Backing.Id}}
        $SlotLeft = 4 - $IdList.Id.Count
        Write-Host -ForeGroundColor Yellow "[DEBUG] Current host '$currentHost' has  # $SlotLeft #  GPU slots available.`r`n"
        $outputBox.AppendText("[DEBUG] Current host '$currentHost' has  # $SlotLeft #  GPU slots available.`r`n")

        $OnVMlist=Get-VMHost $currentHost | Get-VM | Where-Object {$_.PowerState -eq "PoweredOn"}
        $OnlineVMcount=$OnVMlist.count
        
        if ($false) #$SlotLeft -eq 0 -and $OnlineVMcount -le 4)
######################################### Something Wrong! Fixing it now... The case of having offline VMs with PCI device connected to them #############################################

        {
         $OffVMlist = Get-VMHost $currentHost | Get-VM | Where-Object {$_.PowerState -eq "PoweredOff"}
         Write-Host -ForeGroundColor Yellow "[DEBUG] Removing PCI device from Offline VMs of ESXi host $currentHost..."
         $outputBox.AppendText("[DEBUG] Removing PCI device from Offline VMs of ESXi host $currentHost...`r`n")
         LogWrite "[DEBUG] Removing PCI device from Offline VMs of ESXi host $currentHost...`n"
         foreach ($vOff in $OffVMlist)
         {
            foreach ($vm in (get-vm $vOff)) {get-vmresourceconfiguration $vm | set-vmresourceconfiguration -MemReservationMB $vm.MemoryMB}
            get-vm $vOff | get-passthroughdevice | remove-passthroughdevice -Confirm:$false
         }
         # Trying again while the fix beening applied
         Write-Host -ForeGroundColor Green "[INFO] Trying again while the fix has beening applied..."
         $outputBox.AppendText("[INFO] Trying again while the fix has beening applied...`r`n")
         LogWrite "[INFO] Trying again while the fix has beening applied...`n"
         $destHost=$currentHost
        }

        elseif ($SlotLeft -gt 0 -and $OnlineVMcount -gt 4)
######################################### Listing the extra VMs using resources powered on the hosts ##################################################################################

        {
         Write-Host -ForeGroundColor Yellow "[DEBUG] There is Extra VMs Powered on in the host $currentHost :`r`n`r`n"
         $outputBox.AppendText("[DEBUG] There is Extra VMs Powered on in the host $currentHost :`r`n`r`n")
         LogWrite "[DEBUG] There is Extra VMs Powered on in the host $currentHost :`n`n"

         $OnVMlist = Get-VMHost $currentHost | Get-VM | Where-Object {$_.PowerState -eq "PoweredOn"}
         $OnVMNAmelist = $OnVMlist.Name
         Write-Host -ForeGroundColor Yellow ($OnVMNAmelist | Format-Table | Out-String)
         $outputBox.AppendText(($OnVMNAmelist | Format-Table | Out-String))
         LogWrite ($OnVMNAmelist | Format-Table | Out-String)
         #$operationloop = $i
         $destHost=$currentHost
        }


        if ($SlotLeft -eq 0)
######################################### No available GPUs for the VM to use; Migarating the VM to a suitable ESXi hosts #################################################################

        {
            Write-Host -ForeGroundColor Yellow "[DEBUG] Current ESXi host: $currentHost is full. Migrating VM to an other ESXI Host..."
            $outputBox.AppendText("[DEBUG] Current ESXi host: $currentHost is full. Migrating VM to an other ESXI Host...`r`n")
            LogWrite "[DEBUG] Current ESXi host: $currentHost is full. Migrating VM to an other ESXI Host...`n"


            $GPUID = $null
            $destHost = $null

            if ( $i  % 2 -eq 0)
            {
            foreach ($Hosting in $destHostList1)
            {
                Write-Host -ForeGroundColor Yellow "Testing host $Hosting ..."
                $GpuConf=get-vmhost $Hosting | get-vm | get-view
                $IdList = $GpuConf.config.hardware.device | ?{$_.Backing -is "VMware.Vim.VirtualPCIPassthroughDeviceBackingInfo"} | Select-Object  -Property @{N="Id";E={$_.Backing.Id}}

                if ($IdList.Id.Length -ge 4)
                {
                    Write-Host -ForeGroundColor Yellow "[DEBUG] The ESXi host: $Hosting is full."
                    $outputBox.AppendText("[DEBUG] The ESXi host: $Hosting is full.`r`n")
                    LogWrite "[DEBUG] The ESXi host: $Hosting is full.`n"
                    continue
                }
                else
                {
                    $destHost = $Hosting
                    Write-Host -ForeGroundColor Green "[INFO] The ESXi host: $destHost is Good to go. Migrating the VM $VMName to it..."
                    $outputBox.AppendText("[INFO] The ESXi host: $destHost is Good to go. Migrating the VM $VMName to it...`r`n")
                    LogWrite "[INFO] The ESXi host: $destHost is Good to go. Migrating the VM $VMName to it...`n"
                    break
                }
            }
            }
            else
            {
            foreach ($Hosting in $destHostList2)
            {
                Write-Host -ForeGroundColor Green "[INFO] Testing host $Hosting ..."
                $GpuConf=get-vmhost $Hosting | get-vm | get-view
                $IdList = $GpuConf.config.hardware.device | ?{$_.Backing -is "VMware.Vim.VirtualPCIPassthroughDeviceBackingInfo"} | Select-Object  -Property @{N="Id";E={$_.Backing.Id}}

                if ($IdList.Id.Length -ge 4)
                {
                    Write-Host -ForeGroundColor Yellow "[DEBUG] The ESXi host: $Hosting is full."
                    $outputBox.AppendText("[DEBUG] The ESXi host: $Hosting is full.`r`n")
                    LogWrite "[DEBUG] The ESXi host: $Hosting is full.`n"
                    continue
                }
                else
                {
                    $destHost = $Hosting
                    Write-Host -ForeGroundColor Green "[INFO] The ESXi host: $destHost is Good to go. Migrating the VM $VMName to it..."
                    $outputBox.AppendText("[INFO] The ESXi host: $destHost is Good to go. Migrating the VM $VMName to it...`r`n")
                    LogWrite "[INFO] The ESXi host: $destHost is Good to go. Migrating the VM $VMName to it...`n"
                    break
                }
            }
            }

            if ( $destHost -eq $null)
            {
                Write-Host -ForeGroundColor Red "`n[ERROR] ######!!!!!!!!!!! All ESXi hosts are full  !!!!!!!!!!######`n"
                $outputBox.AppendText("`r`n[ERROR] ######!!!!!!!!!!! All ESXi hosts are full  !!!!!!!!!!######`r`n`r`n")
                LogWrite "`n[ERROR] ######!!!!!!!!!!! All ESXi hosts are full  !!!!!!!!!!######`n`n"
                $lastgoodi = $i - 1
                $lastgood = $Org_VMName + "-" + $lastgoodi.ToString("00")

                Write-Host -ForeGroundColor Yellow "[DEBUG]  Cloning stopped. Last Good VM: $lastgood.`n"
                $outputBox.AppendText("[DEBUG]  Cloning stopped. Last Good VM: $lastgood.`r`n`r`n")
                LogWrite "[DEBUG]  Cloning stopped. Last Good VM: $lastgood.`n`n"
                LogWrite "#################################################################################`n"
                Write-Host -ForeGroundColor Red "#################################################################################`n"
                $outputBox.AppendText("#################################################################################`r`n`r`n")

                #Start-sleep -s 2
                $operationloop = $lastgoodi
                continue
                #break
            }
            # VM Migration happens now
            Get-VM $VMName | Move-VM -Destination (Get-VMHost $destHost)
            Write-Host -ForeGroundColor Green "[INFO] The VM $VMName has been migrated. Adding PCI device..."
            $outputBox.AppendText("[INFO] The VM $VMName has been migrated. Adding PCI device...`r`n")
            LogWrite "[INFO] The VM $VMName has been migrated. Adding PCI device...`n"
        }

        elseif ($SlotLeft -gt 0)
######################################### GOOD !! Adding a PCI device. The VM stays in the current host and then gets a GPU PCI devie added to it #######################################

        {
            Write-Host -ForeGroundColor Green "[INFO] Current ESXi host: $currentHost is good to host the VM. Adding GPU PCI device to the VM $VMName..."
            $outputBox.AppendText("[INFO] Current ESXi host: $currentHost is good to host the VM. Adding GPU PCI device to the VM $VMName...`r`n")
            LogWrite "[INFO] Current ESXi host: $currentHost is good to host the VM. Adding GPU PCI device to the VM $VMName...`n"
            $destHost=$currentHost
        }


######################################### Adding GPU PCI card via passthrough ############################################################################################################
#########################################################################################################################################################################################

        # Add PCi device GPU
        #Get-VM $VMName | where { $_.PowerState –eq "PoweredOn" } | Stop-VM –confirm:$false

        foreach ($vm in (get-vm $VMName)) {get-vmresourceconfiguration $vm | set-vmresourceconfiguration -MemReservationMB $vm.MemoryMB}

        $GPUID = "null"

        #get-vm $VMName | get-passthroughdevice | remove-passthroughdevice -Confirm:$false

        $newvm = Get-vm $VMName

        $destHost = $newvm.VMHost.Name

        $ObjHost = Get-EsxCli -VMHost $destHost
        $GPUsIdslist = $ObjHost.hardware.pci.list("0x300") | Where-Object {$_.ModuleName -eq "pciPassthru"} | select -Property Address
        [array]::Reverse($GPUsIdslist)

        #get VMs from a host

        $GpuConf=get-vmhost $destHost | get-vm | get-view

        $IdList = $GpuConf.config.hardware.device | ?{$_.Backing -is "VMware.Vim.VirtualPCIPassthroughDeviceBackingInfo"} | Select-Object  -Property @{N="Id";E={$_.Backing.Id}}

        $SlotLeft = 4 - $IdList.Id.Count

        "-----------------------------------------------------"
        Write-Host -ForeGroundColor Yellow "[DEBUG] The Host '$destHost' has  # $SlotLeft #  GPU slots left."
        $outputBox.AppendText("[DEBUG] The Host '$destHost' has  # $SlotLeft #'  GPU slots left.`r`n")
        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[DEBUG] The Host '$destHost' has  # $SlotLeft #  GPU slots left.'"
        "-----------------------------------------------------"

        foreach ($Idline in $GPUsIdslist)
        {
            if ($IdList -ne $null)
            {
            if (!($IdList.Id.Contains($Idline.Address)))
            {
                $GPUID = $Idline.Address
                #continue
            }
            }
            else
            {
               $GPUID = $GPUsIdslist[3].Address
            }
        }

        if ($GPUID.Equals("null"))
        {
            "-----------------------------------------------------"
            Write-Host -ForeGroundColor Red "`n[ERROR] The host '$destHost' has no free GPU. Please Migrate the VM '$VMName' to a host with available GPUs.`n"
            $outputBox.AppendText("`n[ERROR] The host '$destHost' has no free GPU. Please Migrate the VM '$VMName' to an ESXi host with available GPUs.`r`n`r`n")
            $time = date -Format hh:mm:ss.ms
            LogWrite "`n[ERROR] $time- The host '$destHost' has no free GPU. Please Migrate the VM '$VMName' to a host with available GPUs.`n"
            "-----------------------------------------------------"
            #$operationloop = $i
            continue

        }

        "-----------------------------------------------------"
        Write-Host -ForeGroundColor Green "[INFO] PCI Device with ID '$GPUID' from the host '$destHost' is going to be added to the VM '$VMName'"
        $outputBox.AppendText("[INFO] PCI Device with ID '$GPUID' from the host '$destHost' is going to be added to the VM '$VMName'`r`n")
        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[INFO] $time- PCI Device with ID '$GPUID' from the host '$destHost' is going to be added to the VM '$VMName'"
        "-----------------------------------------------------"

        add-uniquepcipassthroughdevice $VMName $GPUID $destHost

        Start-Sleep -s 1

        $g=get-view -viewtype VirtualMachine -filter @{"Name"=$VMName}
        $h=$g.config.hardware.device | ?{$_.Backing -like "*Pass*"}
        $h.backing

        $gpuvm = Get-VM $newvm
        $device = Get-PassthroughDevice -VM $gpuvm -Type Pci
        $devname = $device.Name

        $devid = $h.backing.Id


        "-----------------------------------------------------"
        Write-Host -ForeGroundColor Green "[INFO] PCI Device '$devname' with ID: ' $devid ' has been added to the VM '$newvm'"
        $outputBox.AppendText("[INFO] PCI Device '$devname' with ID: ' $devid ' has been added to the VM '$newvm'`r`n")
        $outputBox.AppendText("#################################################################################`r`n`r`n")
        Write-Host -ForeGroundColor Green "#################################################################################`n"
        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[INFO] $time- PCI Device '$devname' with ID: ' $devid ' has been added to the VM '$newvm'`n`n"
        "-----------------------------------------------------"
        #foreach ($vm in (get-vm $newvm)) {get-vmresourceconfiguration $vm | set-vmresourceconfiguration -MemReservationMB $vm.MemoryMB}


######################################### Starting the VM to not confuse it for an offline VM holding a PCI device #########################################################################
############################################################################################################################################################################################
        #Start-sleep -s 2
        Start-VM $VMName
        $outputBox.AppendText("[INFO] VM $VMNames Resources organized. Moving to next one.`r`n")
        $outputBox.AppendText("#################################################################################`r`n`r`n")
        Write-Host -ForeGroundColor Green "VM $VMNames Resources organized. Moving to next one."
        Write-Host -ForeGroundColor Green "#################################################################################`n"
        $time = date -Format hh:mm:ss.ms
        LogWrite "[INFO] $time- VM $VMNames Resources organized. Moving to next one.`n"
        LogWrite "#################################################################################`n"
       }
############################################################################################################################################################################################
############################################################################################################################################################################################
############################################################################################################################################################################################
############################################################################################################################################################################################
        "(15). Clone VMs for an Inactive pool"
       {

        $VMName = $destVMName

        write-host -ForeGroundColor Yellow "`n############ Clone Nbr: $j   On: $VMName      ##########`n"
        $outputBox.AppendText("`r`n############ Clone Nbr: $j   On: $VMName     ##########`r`n")
        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[INFO] $time- Cloning the VM: $VMName started.`n"


	    if (IsVMExists ($destVMName))
	    {
		    Write-Host -ForeGroundColor Yellow "[DEBUG] VM $destVMName already Exists in VC $vcAddress"
            $outputBox.AppendText("[DEBUG] VM $destVMName Already Exists in VC $vcAddress`r`n")
		    if($deleteExisting -eq $true)
		    {
			    Delete_VM ($destVMName)
                $time = date -Format dd/MM/yy`thh:mm:ss.m
                LogWrite "[INFO] $time- VM $VMname is already created. Deleting it now..."
                LogWrite "[INFO] $time- VM $VMname is already created. Deleting...`n"
		    }
		    else
		    {
			    Write-Host -ForeGroundColor Yellow "[DEBUG] Skip clone for $destVMName"
                $outputBox.AppendText("[DEBUG] Skip clone for $destVMName`r`n")
                $time = date -Format dd/MM/yy`thh:mm:ss.m
                LogWrite "[DEBUG] $time- Skip cloning the VM $destVMName as requested.`n"
                LogWrite "#################################################################################`n"
                $i = $i+1
                continue
		    }
	    }

        $GPUID = $null
        $destHost = $null

        if ( $i  % 2 -eq 0)
        {
        foreach ($Hosting in $destHostList1)
        {
            Write-Host -ForeGroundColor Yellow "Testing host $Hosting ..."
            $GpuConf=get-vmhost $Hosting | get-vm | get-view
            $IdList = $GpuConf.config.hardware.device | ?{$_.Backing -is "VMware.Vim.VirtualPCIPassthroughDeviceBackingInfo"} | Select-Object  -Property @{N="Id";E={$_.Backing.Id}}

            if ($IdList.Id.Length -ge 4)
            {
                Write-Host -ForeGroundColor Yellow "[DEBUG] The ESXi host: $Hosting is full"
                $outputBox.AppendText("[DEBUG] The ESXi host: $Hosting is full`r`n")
                LogWrite "[DEBUG] The ESXi host: $Hosting is full`n"
                continue
            }
            else
            {
                $destHost = $Hosting
                break
            }
        }
        }
        else
        {
        foreach ($Hosting in $destHostList2)
        {
            Write-Host -ForeGroundColor Green "[INFO] Testing host $Hosting ..."
            $GpuConf=get-vmhost $Hosting | get-vm | get-view
            $IdList = $GpuConf.config.hardware.device | ?{$_.Backing -is "VMware.Vim.VirtualPCIPassthroughDeviceBackingInfo"} | Select-Object  -Property @{N="Id";E={$_.Backing.Id}}
            if ($IdList.Id.Length -ge 4)
            {
                Write-Host -ForeGroundColor Yellow "[DEBUG] The ESXi host: $Hosting is full"
                $outputBox.AppendText("[DEBUG] The ESXi host: $Hosting is full`r`n")
                LogWrite "[DEBUG] The ESXi host: $Hosting is full`n"
                continue
            }
            else
            {
                $destHost = $Hosting
                break
            }
        }
        }

        if ( $destHost -eq $null)
        {
            Write-Host -ForeGroundColor Red "`n[ERROR] ######!!!!!!!!!!! All ESXi hosts are full  !!!!!!!!!!######`n"
            $outputBox.AppendText("`r`n[ERROR] ######!!!!!!!!!!! All ESXi hosts are full  !!!!!!!!!!######`r`n`r`n")
            LogWrite "`n[ERROR] ######!!!!!!!!!!! All ESXi hosts are full  !!!!!!!!!!######`n`n"
            $lastgoodi = $i - 1
            $lastgood = $Org_VMName + "-" + $lastgoodi.ToString("00")

            Write-Host -ForeGroundColor Yellow "[DEBUG]  Cloning stopped. Last Good VM: $lastgood.`n"
            $outputBox.AppendText("[DEBUG]  Cloning stopped. Last Good VM: $lastgood.`r`n`r`n")
            LogWrite "[DEBUG]  Cloning stopped. Last Good VM: $lastgood.`n`n"
            LogWrite "#################################################################################`n"
            Write-Host -ForeGroundColor Red "#################################################################################`n"
            $outputBox.AppendText("#################################################################################`r`n`r`n")

            #Start-sleep -s 2
            $operationloop = $lastgoodi
            continue
            #break


        }

        #$destHost = $Hosting
        Write-Host -ForeGroundColor Green "[INFO] ESXi host $Hosting has been choosing to host the VM $destVMName"
        $outputBox.AppendText("[INFO] ESXi host $Hosting has been choosing to host the VM $destVMName`r`n")
        LogWrite "[INFO] ESXi host $Hosting has been choosing to host the VM $destVMName`n"

        # Cloning
        $vm = get-vm $srcvm -ErrorAction Stop | get-view -ErrorAction Stop
	    $cloneSpec = new-object VMware.VIM.VirtualMachineCloneSpec
	    $cloneSpec.Location = new-object VMware.VIM.VirtualMachineRelocateSpec
	    if ($CloneType -eq "linked")
	    {
		    $cloneSpec.Location.DiskMoveType = [VMware.VIM.VirtualMachineRelocateDiskMoveOptions]::createNewChildDiskBacking
	    }
	    Write-Host -ForeGroundColor Green "[INFO] Selecting Datastore: $targetDSName"
	    $newDS = Get-Datastore $targetDSName | Get-View
	    $CloneSpec.Location.Datastore =  $newDS.summary.Datastore
        Write-Host -ForeGroundColor Green "[INFO] Cloning on Snapshot: $srcSnapshot"
        Set-VM -vm $srcVM -snapshot (Get-Snapshot -vm $srcVM -Name $srcSnapshot) -confirm:$false
        $cloneSpec.Snapshot = $vm.Snapshot.CurrentSnapshot
	    $cloneSpec.Location.Host = (get-vmhost -Name $destHost).Extensiondata.MoRef
	    #$CloneSpec.Location.Pool = (Get-ResourcePool -Name Resources -Location (Get-VMHost -Name $destHost)).Extensiondata.MoRef
        # Start the Clone task using the above parameters
	    $task = $vm.CloneVM_Task($vm.parent, $destVMName, $cloneSpec)
        # Get the task object
	    $task = Get-Task | where { $_.id -eq $task }
        #Wait for the taks to Complete
        Wait-Task -Task $task

        $newvm = Get-vm $destVMName
        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[INFO] $time- VM $newvm Cloned.`n"
        $customSpec = Get-OSCustomizationSpec $cSpec
        Set-vm -OSCustomizationSpec $cSpec -vm $newvm -confirm:$false
	    if ($disableVMConsole -eq "yes")
	    {
		    Disable_VM_Console($destVMName)
	    }

        # Adding GPU card passthrough
        $ObjHost = Get-EsxCli -VMHost $destHost
        $GPUsIdslist = $ObjHost.hardware.pci.list("0x300") | Where-Object {$_.ModuleName -eq "pciPassthru"} | select -Property Address
        [array]::Reverse($GPUsIdslist)

        $GpuConf=get-vmhost $destHost | get-vm | get-view
        $IdList = $GpuConf.config.hardware.device | ?{$_.Backing -is "VMware.Vim.VirtualPCIPassthroughDeviceBackingInfo"} | Select-Object  -Property @{N="Id";E={$_.Backing.Id}}
        $SlotLeft = 4 - $IdList.Id.Count
        "-----------------------------------------------------"
        Write-Host -ForeGroundColor Yellow "[DEBUG] The Host '$destHost' has  # $SlotLeft #  GPU slots left."
        $outputBox.AppendText("[DEBUG] The Host '$destHost' has  # $SlotLeft #  GPU slots left.`r`n")
        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[DEBUG] The Host '$destHost' has  # $SlotLeft #  GPU slots left.'"
        "-----------------------------------------------------"
        foreach ($Idline in $GPUsIdslist)
      {
         if ($IdList -ne $null)
         {
            if (!($IdList.Id.Contains($Idline.Address)))
            {
                $GPUID = $Idline.Address
                #continue
            }
          }
          else
          {
             $GPUID = $GPUsIdslist[3].Address
          }
      }
        "-----------------------------------------------------"
        Write-Host -ForeGroundColor Green "[INFO] PCI Device with ID '$GPUID' from the host '$destHost' is going to be added to the VM '$destVMName'"
        $outputBox.AppendText("[INFO] PCI Device with ID '$GPUID' from the host '$destHost' is going to be added to the VM '$destVMName'`r`n")
        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[INFO] $time- PCI Device with ID '$GPUID' from the host '$destHost' is going to be added to the VM '$destVMName'"
        "-----------------------------------------------------"

        add-uniquepcipassthroughdevice $newvm $GPUID $destHost

        Start-Sleep -s 1

        $g=get-view -viewtype VirtualMachine -filter @{"Name"=$destVMName}
        $h=$g.config.hardware.device | ?{$_.Backing -like "*Pass*"}
        $h.backing

        $gpuvm = Get-VM $newvm
        $device = Get-PassthroughDevice -VM $gpuvm -Type Pci
        $devname = $device.Name

        $devid = $h.backing.Id

        "-----------------------------------------------------"
        Write-Host -ForeGroundColor Green "[INFO] PCI Device '$devname' with ID: ' $devid ' has been added to the VM '$newvm'`n"
        $outputBox.AppendText("[INFO] PCI Device '$devname' with ID: ' $devid ' has been added to the VM '$newvm'`r`n`n")
        $time = date -Format dd/MM/yy`thh:mm:ss.m
        LogWrite "[INFO] $time- PCI Device '$devname' with ID: ' $devid ' has been added to the VM '$newvm'`n`n"
        "-----------------------------------------------------"

        foreach ($vm in (get-vm $newvm)) {get-vmresourceconfiguration $vm | set-vmresourceconfiguration -MemReservationMB $vm.MemoryMB}

        $time = date -Format dd/MM/yy`thh:mm:ss.m
        Write-Host -ForeGroundColor Green "[INFO] VM $newvm Cloned successfuly. Moving to next VM.`n"
        Write-Host -ForeGroundColor Green "#################################################################################`n"
        $outputBox.AppendText("[INFO] VM $newvm Cloned successfuly. Moving to next VM.`r`n")
        $outputBox.AppendText("#################################################################################.`r`n")
        LogWrite "[INFO] $time- VM $newvm cloned with success. Moving to next VM.`n"
        LogWrite "#################################################################################`n"
        #$outputBox.AppendText("###############  VM $newvm Cloned successfuly. Moving to next VM  ##############`r`n")
        $outputBox.SelectionStart = $outputBox.Text.Length
        $outputBox.ScrollToCaret()

        [Console]::ResetColor()
       }
        "(16) Remove GPU from VM"
       {
        # Remove PCI device GPU
        $outputBox.AppendText("[INFO] Removinging GPU PCI card from VM $VMName...`r`n")
        Write-Host -ForeGroundColor Green "[INFO] Removinging GPU PCI card from VM $VMName..."

        Get-VM $VMName | where { $_.PowerState –eq "PoweredOn" } | Stop-VM –confirm:$false

        #foreach ($vm in (get-vm $VMName)) {get-vmresourceconfiguration $vm | set-vmresourceconfiguration -MemReservationMB $vm.MemoryMB}
        get-vm $VMName | get-passthroughdevice | remove-passthroughdevice -Confirm:$false

        $outputBox.AppendText("[INFO] VM $VMName has its GPU PCI card removed and it is kept shutdown.`r`n")
        Write-Host -ForeGroundColor Green "[INFO] VM $VMName has its GPU PCI card removed and it is kept shutdown."
        $outputBox.AppendText("#################################################################################`r`n`r`n")
        Write-Host -ForeGroundColor Green "#################################################################################`n"
        $time = date -Format hh:mm:ss.ms
        LogWrite "[INFO] $time- GPU PCI Device Removed from VM $VMName`n"
        LogWrite "#################################################################################`n"

       }

        "(17). Change network VLAN configuration"
       {
        
        #Configure VLAN setting
        $outputBox.AppendText("[INFO] Configuring Network card with New VLAN on VM $VMNames...`r`n")
        Write-Host -ForeGroundColor Green "[INFO] Configuring Network card with New VLAN on VM $VMNames..."
        $time = date -Format hh:mm:ss.ms
        LogWrite "[INFO] $time- Configuring Network card with New VLAN on VM $VMName.`n"

        $newvm=$VMName
        write-host -ForeGroundColor Green "[INFO] Shutting down VM $VMName Guest..."
        Get-VM $VMName | where { $_.PowerState –eq "PoweredOn" } | Stop-VM -Confirm:$false

        $NetworkAdapter = Get-NetworkAdapter -VM $newvm
        Set-NetworkAdapter -NetworkAdapter $NetworkAdapter -NetworkName 'VLAN 515 (blade)' -Confirm:$false 

        write-host -ForeGroundColor Green "[INFO] Powering on the VM $VMName ..."
        Get-VM $VMName | where { $_.PowerState –eq "PoweredOff" } | Start-VM -Confirm:$false

        $time = date -Format dd/MM/yy`thh:mm:ss.m
        Write-Host -ForeGroundColor Green "[INFO] Link the VM $newvm to the appropriate VLAN.`n"
        LogWrite "[INFO] $time- Link the VM $newvm to the appropriate VLAN.`n"
        $outputBox.AppendText("[INFO] Link the VM $newvm to the appropriate VLAN.`r`n")
       }

    }

    Write-Host -ForeGroundColor Green "[INFO] Operation for the VM $destVMName Done.`n`n"
    $outputBox.AppendText("[INFO] Operation for the VM $destVMName Done.`r`n")

    $i = $i+1
    }

    Write-Host -ForeGroundColor Yellow "##################   All VM Operation Done.    ##################"
    $outputBox.AppendText("##################   Virtual Machines Operation Done.   ##################`r`n")
    $outputBox.SelectionStart = $outputBox.Text.Length
    $outputBox.ScrollToCaret()
    $time = date -Format dd/MM/yy`thh:mm:ss.m
    LogWrite "[INFO] $time- There is no Next VM. Script is done. Exiting.`n"
    $timedate1 = date -Format dd/MM/yy`thh:mm:ss.m
    LogWrite "[INFO]- The script has ended at: $timedate1"
    LogWrite "#################################################################################`n"
    LogWrite "#################################################################################`n"

    }

}

#####################  Form Activation  ##########################

$Form.Add_Shown({$Form.Activate()})
[void] $Form.ShowDialog()                                                         #activating the form
