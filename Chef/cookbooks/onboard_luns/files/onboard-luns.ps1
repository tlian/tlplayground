<#
    .SYNOPSIS
    Onboard Quorum and E drives; initialize, partition and format the disk.

    .DESCRIPTION
    Map LunID to local Disk drive number. LunID came from storage team
    Make sure to provide correct Lun IDs for the Quorum and E drives.

    .PARAMETER DLunId

    .PARAMETER DriveLetter

    .PARAMETER DriveLabel

    .EXAMPLE
    ScriptName.ps1 -DLunId 0 -DriveLetter "E" -DriveLabel "E Drive"

    .NOTES
    Author Thawngzapum Lian
    Date 05/16/2017
#>

param(
  [Parameter(Mandatory=$True)]
  $DLunId=-1,
  [Parameter(Mandatory=$True)]
  [String]$DriveLetter,
  [Parameter(Mandatory=$True)]
  [String]$DriveLabel
)

# Set var
$DiskModelPrefix = "3PARdata"

Function _IsMpioInstalled {
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
          ? { $_.SCSILogicalUnit -eq $LunId -and $_.partitions -eq 0 -and $_.Model -Like "$DiskModelPrefix*" }
  # The following may not be needed. PS returns everything so cast the desired value in the calling subroutine.
  if (!($disk.Index.length -eq 1)) { 
    return $null
  }
  $DiskNum = $disk.Index
  return $DiskNum
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

Function MountPartition {
  Param(
    [Int]$DiskNumber,
    [string]$MountPath,
    [string]$FStype = "NTFS",
    [string]$FSlabel
  )
    New-Item $MountPath -type Directory
    New-Partition -DiskNumber $DiskNumber -UseMaximumSize
    # PartitionNumber should always be '2', the first one '1' is the small formatting partition
    Add-PartitionAccessPath -DiskNumber $DiskNumber -PartitionNumber 2 -AccessPath $MountPath -PassThru `
       | Format-Volume -FileSystem $FStype -NewFileSystemLabel $FSlabel -Confirm:$false
}

# Install MPIO if not already - ONLY HELPER FUNCTION per dev
#If (!(_IsMpioInstalled)) {
#  _InstallMPIOFeature
#  $msg = "WARNING: Reboot required post MPIO install. Re-run the script after reboot."
#  throw $msg
#}

# Add 3PARdata device if not already
#If (!(_Is3PARdataSupported)) { 
#  _Add3PARdataMpioDevice
#  $msg = "WARNING: Reboot required post configuring MPIO. Re-run the script after reboot."
#  throw $msg
#}

# Convert LunId to Int type
$DLunId = [int]$DLunId
# Drive Letter may contain some colon and slash, strip it
$MountPath = $DriveLetter
$DriveLetter, $Path = $DriveLetter.split(':')

# Onboard a drive
if ( ($DLunId -ne -1) -and $DriveLetter -and $DriveLabel ) {
  $DiskNum = MapLunIdToDiskNumber -LunId $DLunId
  if ( $DiskNum ) {
      # Only with RAW disk, attempt to exe all tasks
      if ( InitializeDisk -DiskNumber $DiskNum ) {
        # Disable ShellHWDetection to supress window dialog prompt to format
        Stop-Service -Name ShellHWDetection
        if ( $Path.length -lt 3 ) {
            PartitionDisk -DiskNumber $DiskNum -DriveLetter $DriveLetter
            FormatDisk -DriveLetter $DriveLetter -FSlabel $DriveLabel
        }
        else {
          MountPartition -DiskNumber $DiskNum -MountPath $MountPath -FSlabel $DriveLabel
        }
      }
  }
  else
  {
    Write-Host "Could NOT map LunId $DLunId to Disk Drive Number. Looked like disk already onboarded." 
  }
}
