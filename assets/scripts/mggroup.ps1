# Check if the Microsoft.Graph module is installed
if (-not (Get-Module -Name Microsoft.Graph -ListAvailable)) {
    # Not installed? No problem! Let's install the MgGraph module.
    Install-Module -Name Microsoft.Graph -Scope CurrentUser -Force
}

# Import the Microsoft.Graph module like a boss
Import-Module Microsoft.Graph

# Time to connect to Microsoft Graph with the right spells... I mean, scopes!
Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read.All"

# Let's summon all groups - you never know what lurks in there!
$groups = Get-MgGroup

$context = Get-MgContext
$userPrincipalName = $context.Account 

# Now you, dear reader, can define your own group names and descriptions!
$groupsToCreate = Read-Host "Enter your group names and descriptions in the format 'name:description', separated by commas"
$groupArray = $groupsToCreate -split "," | ForEach-Object { 
    $split = $_ -split ":"
    @{ name = $split[0].Trim(); description = $split[1].Trim() }
}

$groupsCreated = @()

foreach ($entry in $groupArray) {
    # Check if the groups already exist in your magical Entra ID realm
    $group = $groups | Where-Object { $_.DisplayName -eq $entry.name }
    if ($group) {
        # If the group exists but the description is off, let's update it.
        if ($entry.description -and $group.description -ne $entry.description) {
            Write-Host "[$($user.UserPrincipalName)] Updating description for Group [$($entry.name)][$($group.Id)]"
            Update-MgGroup -GroupId $group.Id -Description $entry.description
        } else {
            Write-Host "[$($user.UserPrincipalName)] Group [$($entry.name)][$($group.Id)] already exists. Skipping."
        }
        $groupsCreated += $group
    } else {
        Write-Host "[$($user.UserPrincipalName)] Creating group [$($entry.name)]."
        # Time to create the group, with you as the owner. Why, you ask?
        $GroupBody = @{
            DisplayName         = $entry.name
            Description         = $entry.description
            MailEnabled         = $false
            MailNickname        = $entry.name
            SecurityEnabled     = $true
            "Owners@odata.bind" = @("https://graph.microsoft.com/v1.0/users/$userPrincipalName")
        }
        $newGroup = New-MgGroup -BodyParameter $GroupBody
        $groupsCreated += $newGroup
    }
}


$accessTokenPim = (Get-AzAccessToken -ResourceUrl 'https://api.azrbac.mspim.azure.com').Token
$headers = @{
    "Authorization" = "Bearer $accessTokenPim"
    "Content-Type"  = "application/json"
}
$payload = @{"externalId":"8c1d0ae5-cb49-4aa4-acf4-a5b703e9cb7a"}

# https://api.azrbac.mspim.azure.com/api/v2/privilegedAccess/aadGroups/resources/register


(Get-MgIdentityGovernancePrivilegedAccessGroup -GroupId 8c1d0ae5-cb49-4aa4-acf4-a5b703e9cb7a).Id
Get-MgIdentityGovernancePrivilegedAccessGroup -ExpandProperty   