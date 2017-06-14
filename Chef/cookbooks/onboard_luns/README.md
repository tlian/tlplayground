# onboard-luns

This cookbook onboard a LUN disk give the LUN ID. 
Onboarding in this case is initializing, partitioning and fomatting. 
The powershell script run by this cookbook guard itself as its best
so that it does not acidentally delete/erase a disk/volume. 
The initialize/partition/format task executes only on a RAW and RAW disk only.

Even if the cookbook is run multiple times at a specified interval (Chef client per se),
it should not cause harm theoretically.

The LUN IDs are read off of node's attribute. Thus, the attributes should be all set
before hand.

The powershell script may be run on the host locally as the following. 

**Example**

   ScriptName.ps1 -DLunId 0 -DriveLetter "E" -DriveLabel "E Drive"

