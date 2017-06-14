#
# Cookbook:: onboard-luns
# Recipe:: default
#
# Copyright:: 2017, The Authors, All Rights Reserved.

case node['platform_family']
when 'windows'
  if node.attribute?('storage')
    cookbook_file 'files/onboard-luns.ps1' do
      path 'c:/onboard-luns.ps1'
    end

    # storage is the node's attributes which are the LUNs
    # info attached to the node
    node['storage'].each do |x|
      lun_id = x['LUN']
      drive_letter = x['Path']
      drive_label = x['Name']
      powershell_script 'Run onboard-luns.ps1' do
        code ". c:/onboard-luns.ps1 -DLunId #{lun_id} -DriveLetter #{drive_letter} -DriveLabel #{drive_label}"
      end
    end
  end
end
