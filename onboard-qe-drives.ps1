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
  [Int]$EdriveLunId]
)

$DiskModelPrefix = "3PARdata"

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
  $driveNum = $disk.Index
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
    [string]$DriveLetter,
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
