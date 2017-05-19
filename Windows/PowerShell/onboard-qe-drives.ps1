<#
    .SYNOPSIS
    Onboard Quorum and E drives; initialize, partition and format the disk.

    .DESCRIPTION
    Map LunID to local Disk drive number. LunID came from storage team
    Make sure to provide correct Lun IDs for the Quorum and E drives.

    .PARAMETER QdriveLunId

    .PARAMETER EdriveLunId

    .EXAMPLE
    ScriptName.ps1 -QdriveLunId 0 -EdriveLunId 1

    .NOTES
    Author Thawngzapum Lian
    Date 05/16/2017
#>

param(
  [Int]$QdriveLunId=-1,
  [String]$QdriveLetter="Q",
  [String]$QdriveFSLabel="quorum",
  [Int]$EdriveLunId=-1,
  [String]$EdriveLetter="E",
  [String]$EdriveFSLabel="E Drive"
)

# Set var
$DiskModelPrefix = "3PARdata"
# Command line argument override env var
if ( $QdriveLunId -eq -1 ) {
  try {
    $QdriveLunId = (Get-ChildItem env:QdriveLunId -ErrorAction Stop).Value
  } catch {
    $QdriveLunId = -1
}
  
}
if ( $EdriveLunId -eq -1 ) {
  try {
    $EdriveLunId = (Get-ChildItem env:EdriveLunId -ErrorAction Stop).Value
  } catch {
    $EdriveLunId = -1
  }
}

Function IsMpioInstalled {
  $mpio = Get-WindowsFeature "*multipath*"
  return $mpio.Installed
}

Function _Is3PARdataSupported {
  # this is only a helper function
  # MPIO configuration should be handled by a cookbook in the pipeline
  return (Get-MSDSMSupportedHW).VendorId -contains $DiskModelPrefix
}

Function _InstallMPIOFeature {
  # Only Helper function - should be handled by Chef Cookbook
  Add-WindowsFeature -Name "Multipath-IO"
}

Function _Add3PARdataMpioDevice {
  # Helper function only - should be handled by Chef cookbook
  New-MSDSMSupportedHW -VendorId $DiskModelPrefix -ProductId "VV"
}

Function _RebootComputer {
  # Only helper function
  Restart-Computer
}

Function MapLunIdToDiskNumber {
  # Map LunID to correct local disk number
  # Each LunID may be associated with multiple disk number.
  # One example of additional associating disk number that of Local Hard dirve (C:\)
  # It needs to be completely sure what disk number belongs to Q or E drives.
  Param(
    [Int]$LunId
  )
  $disk = gwmi -class Win32_DiskDrive | `
          ? { $_.SCSILogicalUnit -eq $LunId -and $_.partitions -eq 0 -and $_.Model -like "$DiskModelPrefix*" }
  # The following may not be needed. PS returns everything so cast the desired value in the calling subroutine.
  if (!($disk.Index.length -eq 1)) { 
    return $null
  }
  $driveNum = $disk.Index
  return $driveNum
}

Function InitializeDisk {
  Param(
    [Int]$DiskNumber,
    [String]$PartitionType = "GPT"
  )
  # Initialize only if it was not
  if ((Get-Disk -Number $DiskNumber).PartitionStyle -eq 'RAW') {
    Initialize-Disk -Number $DiskNumber -PartitionStyle $PartitionType -Confirm:$false
    return $true
  }
  return $false
}

Function PartitionDisk {
  Param(
    [Int]$DiskNumber,
    [string]$DriveLetter
  )
  # Partition only if it was not
  if ( (Get-Disk -Number $DiskNumber).NumberOfPartitions -eq 1 ) {
    New-Partition -DiskNumber $DiskNumber -DriveLetter $DriveLetter -UseMaximumSize
  }
}

Function FormatDisk {
  Param(
    [string]$DriveLetter,
    [string]$FStype = "NTFS",
    [string]$FSlabel
  )
  # Fomat it only if it was not
  if (!((Get-Volume -DriveLetter $DriveLetter).FileSystem)) {
    Format-Volume -DriveLetter $DriveLetter -FileSystem $FStype -NewFileSystemLabel $FSlabel -Confirm:$false
  }
}

# Install MPIO if not already
If (!(IsMpioInstalled)) {
  _InstallMPIOFeature
  $msg = "WARNING: Reboot required post MPIO install. Re-run the script after reboot."
  throw $msg
}

# Add 3PARdata device if not already
If (!(_Is3PARdataSupported)) { 
  _Add3PARdataMpioDevice
  $msg = "WARNING: Reboot required post configuring MPIO. Re-run the script after reboot."
  throw $msg
}

# Onboard Quorum drive
if ( $QdriveLunId -ne -1 ) {
  $QdiskNum = MapLunIdToDiskNumber -LunId $QdriveLunId
  if ( $QdiskNum ) {
      # Only with RAW disk, attempt to exe all tasks
      if ( InitializeDisk -DiskNumber $QdiskNum ) {
        # Disable ShellHWDetection to supress window dialog prompt to format
        Stop-Service -Name ShellHWDetection
        PartitionDisk -DiskNumber $QdiskNum -DriveLetter $QdriveLetter
        FormatDisk -DriveLetter $QdriveLetter -FSlabel $QdriveFSLabel
      }
  }
  else
  {
    Write-Host "Could NOT map Quorum Drive LunId to Disk Drive Number. Looked like disk already onboarded." 
  }
}

# Onboard E Drive
if ( $EdriveLunId -ne -1 ) {
  $EdiskNum = MapLunIdToDiskNumber -LunId $EdriveLunId
  if ( $EdiskNum ) {
      if ( InitializeDisk -DiskNumber $EdiskNum ) {
        Stop-Service -Name ShellHWDetection
        PartitionDisk -DiskNumber $EdiskNum -DriveLetter $EdriveLetter
        FormatDisk -DriveLetter $EdriveLetter -FSlabel $EdriveFSLabel
      }
  }
  else 
  {
    Write-Host "Could NOT map E Drive LunId to Disk Drive Number. Looked like disk already onboarded." 
  }
}