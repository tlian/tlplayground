Function cleanup {
  3..53 | % { Clear-Disk -Number $_ -RemoveData -Confirm:$false}
}

Function runtest {
    $jobj = (Get-Content attributes.json) -join "`n" | ConvertFrom-Json

    foreach ($i in $jobj.storage)
    {
       $args = @()
       $args += ("-DLunId", $i.LUN)
       $args += ("-DriveLetter", $i.Path)
       $args += ("-DriveLabel", $i.Name)
       Invoke-Expression "C:\onboard-luns.ps1 $args"
       #Invoke-Expression -Command "C:\onboard-luns.ps1"
    }
}

cleanup
