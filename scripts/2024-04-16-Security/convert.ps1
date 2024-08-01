# Load the old JSON file  
$oldJson = Get-Content -Raw -Path 'D:\the world\Device-Security-Guidance-Configuration-Packs\Microsoft\Windows\MDM\Configurations\NCSC_-_BitLocker.json' | ConvertFrom-Json  
  
# Create a new PowerShell object for the new JSON  
$newJson = New-Object PSObject  
  
# Set the properties in the new JSON that match the old JSON  
$newJson | Add-Member -Type NoteProperty -Name 'Id' -Value $oldJson.id  
$newJson | Add-Member -Type NoteProperty -Name 'DisplayName' -Value $oldJson.displayName  
$newJson | Add-Member -Type NoteProperty -Name 'Version' -Value ($oldJson.version + 1)  
  
# Create a nested object for 'AdditionalProperties'  
$additionalProperties = New-Object PSObject  
  
# Set the properties in 'AdditionalProperties' that match the old JSON  
$additionalProperties | Add-Member -Type NoteProperty -Name '@odata.type' -Value $oldJson.'@odata.type'  
$additionalProperties | Add-Member -Type NoteProperty -Name 'firewallPreSharedKeyEncodingMethod' -Value $oldJson.firewallPreSharedKeyEncodingMethod  
$additionalProperties | Add-Member -Type NoteProperty -Name 'firewallIPSecExemptionsAllowNeighborDiscovery' -Value $oldJson.firewallIPSecExemptionsAllowNeighborDiscovery  
# ... Add the rest of the properties here ...  
  
# Add 'AdditionalProperties' to the new JSON  
$newJson | Add-Member -Type NoteProperty -Name 'AdditionalProperties' -Value $additionalProperties  
  
# Save the new JSON to a file  
$newJson | ConvertTo-Json -Depth 32 | Set-Content -Path 'C:\tmp\intune\NewFile.json'  
