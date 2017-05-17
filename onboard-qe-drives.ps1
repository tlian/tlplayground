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
  [Int]$QdriveLunId,
  [Int]$EdriveLunId
)

$DiskModelPrefix = "3PARdata"

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
  if (!($disk.Index.length -eq 1)) { throw "FAILED to map LunID to Disk Drive Number. Found zero or multiple drives!"}
  $driveNum = $disk.Index
  return $driveNum
}

Function InitializeDisk {
  Param(
    [Int]$DiskNumber,
    [String]$PartitionType = "GPT"
  )
  Initialize-Disk -Number $DiskNumber -PartitionStyle $PartitionType
}

Function PartitionDisk {
  Param(
    [Int]$DiskNumber,
    [string]$DriveLetter
  )
  New-Partition -DiskNumber $DiskNumber -UseMaximumSize
  # New-Partition -DiskNumber $DiskNumber -AssignDriveLetter -UseMaximumSize
}

Function FormatDisk {
  Param(
    [string]$DriveLetter,
    [string]$FStype = "NTFS",
    [string]$FSlabel
  )
  Format-Volume -DriveLetter $DriveLetter -FileSystem $FStype -NewFileSystemLabel $FSlabel -Confirm:$false
}

# Install MPIO if not already
If (!(IsMpioInstalled)) { _InstallMPIOFeature }

# Add 3PARdata device if not already
If (!(_Is3PARdataSupported)) { 
  _Add3PARdataMpioDevice
  _RebootComputer
  Start-Sleep -m 5
}

# Extract Disk number
$QdiskNum = MapLunIdToDiskNumber -LunId $QdriveLunId

# Initialize Disk
InitializeDisk -DiskNumber $QdiskNum

# Partition Disk
PartitionDisk -DiskNumber $QdiskNum

# Format Disk
FormatDisk -DriveLetter "Q" -FSlabel "quorum"
