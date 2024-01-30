# # Ensuring the presence of the Microsoft.Graph module
if (-not (Get-Module -Name Microsoft.Graph -ListAvailable)) {
    Install-Module -Name Microsoft.Graph -Scope CurrentUser -Force
}


# Ensuring the presence of the Az.Accounts module
if (-not (Get-Module -Name Az.Accounts -ListAvailable)) {
    Install-Module -Name Az.Accounts -Scope CurrentUser -Force
}

# Import the Microsoft.Graph.Identity.Governance module
Import-Module Microsoft.Graph.Identity.Governance

# Establishing a connection to Microsoft Graph
# Think of this as tuning your crystal ball to the right magical frequency
Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read.All", "PrivilegedAccess.ReadWrite.AzureADGroup"

# Summoning all groups from the depths of Azure
# Like casting a net into the sea of the cloud to see what mysteries we can uncover
Get-MgGroup

# Preparing the environment for our Azure ritual
$context = Get-MgContext
Write-Host "Context acquired. Current wizard in control: $($context.Account)"

# Inquiring the wizard (you) about their intention to create new groups
$CreateGroups = Read-Host "Do you wish to conjure new groups into existence? (y/n)"
if ($CreateGroups -eq "y") {
    Write-Host "Ah, a brave decision! Let's define the names and destinies of these new groups."
    $groupsToCreate = Read-Host "Enter your group names and descriptions in the format 'name:description', separated by commas"
    $groupArray = $groupsToCreate -split "," | ForEach-Object { 
        $split = $_ -split ":", 2  # Splitting the input to extract name and description
        if ($split.Length -eq 2) {
            Write-Host "Preparing to conjure group named $($split[0].Trim()) with a purpose of $($split[1].Trim())"
            [PSCustomObject]@{ name = $split[0].Trim(); description = $split[1].Trim() }
        }
        else {
            Write-Host "Beware! Invalid format detected for '$_'. A group name and description are required."
        }
    }
    Write-Host "The list of groups to be conjured has been prepared."
}

$groupsCreated = @()

foreach ($entry in $groupArray) {
    # Consulting the Azure oracles to see if the group already exists
    Write-Host "Consulting the Azure oracles for the existence of $($entry.name)..."
    $group = Get-MgGroup -Filter "DisplayName eq '$($entry.name)'"
    if ($group) {
        Write-Host "The group $($entry.name) already exists in the realm of Azure."
        # Updating the group's description if needed
        if ($entry.description -and $group.description -ne $entry.description) {
            Write-Host "Updating the lore (description) of $($entry.name) to match our records."
            Update-MgGroup -GroupId $group.Id -Description $entry.description
        }
        else {
            Write-Host "No updates required for $($entry.name). Its lore remains unchanged."
        }
        $groupsCreated += $group
    }
    else {
        # The spell to create a new group
        Write-Host "The group $($entry.name) is not yet part of our realm. Let's bring it to life!"
        $GroupBody = @{
            DisplayName         = $entry.name
            Description         = $entry.description
            MailEnabled         = $false
            MailNickname        = $entry.name
            SecurityEnabled     = $true
            "Owners@odata.bind" = @("https://graph.microsoft.com/v1.0/users/$($context.Account)")
        }
        $newGroup = New-MgGroup -BodyParameter $GroupBody
        Write-Host "Group $($entry.name) has been successfully conjured!"
        $groupsCreated += $newGroup
    }
}

# Revealing our group crafting achievements
Write-Host "Behold the groups that have been created or updated in this session:"
foreach ($group in $groupsCreated) {
    Write-Host "Group Name: $($group.DisplayName), ID: $($group.Id)"
}
