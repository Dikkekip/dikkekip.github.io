# Check if the Microsoft.Graph module is installed
if (-not (Get-Module -Name Microsoft.Graph -ListAvailable)) {
    # Not installed? No problem! Let's install the MgGraph module.
    Install-Module -Name Microsoft.Graph -Scope CurrentUser -Force
}

# Check if the Microsoft.Graph module is installed
if (-not (Get-Module -Name Az.Accounts -ListAvailable)) {
    # Not installed? No problem! Let's install the MgGraph module.
    Install-Module -Name Az.Accounts -Scope CurrentUser -Force
}


# Import the Microsoft.Graph module like a boss
Import-Module Microsoft.Graph.Identity.Governance

# Time to connect to Microsoft Graph with the right spells... I mean, scopes!
Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read.All", "PrivilegedAccess.ReadWrite.AzureADGroup"

# Let's summon all groups - you never know what lurks in there!
$groups = Get-MgGroup

$context = Get-MgContext
$userPrincipalName = $context.Account 

# Now you, dear reader, can define your own group names and descriptions!
$CreateGroups = Read-Host "Do you want to create new groups? (y/n)"
if ($CreateGroups -eq "y") {
    $groupsToCreate = Read-Host "Enter your group names and descriptions in the format 'name:description', separated by commas"
    $groupArray = $groupsToCreate -split "," | ForEach-Object { 
        $split = $_ -split ":", 2  # Split only at the first occurrence of ":"
        if ($split.Length -eq 2) {
            [PSCustomObject]@{ name = $split[0].Trim(); description = $split[1].Trim() }
        }
        else {
            Write-Host "Invalid input format: $_"
        }
    }    
}

$groupsCreated = @()

foreach ($entry in $groupArray) {
    # Check if the groups already exist in your magical Entra ID realm
    $group = Get-MgGroup -Filter "DisplayName eq '$($entry.name)'"
    if ($group) {
        # If the group exists but the description is off, let's update it.
        if ($entry.description -and $group.description -ne $entry.description) {
            Write-Host "[$($context.Account)] Updating description for Group [$($entry.name)][$($group.Id)]"
            Update-MgGroup -GroupId $group.Id -Description $entry.description
        }
        else {
            Write-Host "[$($context.Account)] Group [$($entry.name)][$($group.Id)] already exists. Skipping."
        }
        $groupsCreated += $group
    }
    else {
        Write-Host "[$($context.Account)] Creating group [$($entry.name)]."
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

if (!$groupCreated) {
    $groups = Get-MgGroup -all 
    $groupsToEnable = $groups | Select-Object DisplayName, Id | Out-ConsoleGridView -Title "Select the groups to activate" -OutputMode Multiple
}
else {
    $groupsToEnable = $groupsCreated
}


Write-Host "[$($context.Account)] Enabling Privileged Identity Management for the following groups:"
foreach ($group in $groupsToEnable) {
    # If you want to find out more about the group, you can use the following command
    $findGroupInPim = Get-MgIdentityGovernancePrivilegedAccessGroupAssignmentSchedule -Filter "groupId eq '$($group.Id)'"
    if (!$findGroupInPim) {
        # Check if the user is connected
        $context = Get-AzContext

        if ($null -eq $context) {
            # If not connected, prompt the user to login
            Write-Host "You are not connected. Please login."
            Connect-AzAccount
        }
        else {
            Write-Host "You are already connected as $($context.Account.Id)"
        }
        Write-Host "[$($context.Account)] [$($group.DisplayName)][$($group.Id)]"
        # Let's add the group to the Privileged Identity Management (PIM)"
        $accessTokenPim = (Get-AzAccessToken -ResourceUrl 'https://api.azrbac.mspim.azure.com').Token
        $headers = @{
            "Authorization" = "Bearer $accessTokenPim"
            "Content-Type"  = "application/json"
        }
        $url = "https://api.azrbac.mspim.azure.com/api/v2/privilegedAccess/aadGroups/resources/register" 
        Write-Host "[$($context.Account)] Adding group [$($group.DisplayName)][$($group.Id)] to Privileged Identity Management | Groups."
        Invoke-RestMethod -Uri $url -Headers $headers -Method Post -Body "{`"externalId`":`"$($group.id)`"}"
    }    
}

Write-Host "===================================================================================================="
Write-Host "[$($context.Account)] All done! You can now assign users to the groups in Privileged Identity Management."

# Let's assign the user to the group
Write-Host "[$($context.Account)] Assigning users to the groups."
if (!$groupsToEnable) {
    Write-Host "[$($context.Account)] Select the groups to activate."
    $groupsToConfigure = Get-MgGroup -all | Select-Object DisplayName, Id | Out-ConsoleGridView -Title "Select the groups to activate" -OutputMode Multiple
}
else {
    Write-Host "[$($context.Account)] Using the groups that were just created."
    $groupsToConfigure = $groupsToEnable
}


$usersToAssign = Get-MgUser -Filter "AccountEnabled eq true" | Select-Object DisplayName, Id | Out-ConsoleGridView -Title "Select the users to assign" -OutputMode Multiple

# If you want to find out more about the group, you can use the following command
#Get-MgIdentityGovernancePrivilegedAccessGroupAssignmentSchedule -Filter "groupId eq '8c1d0ae5-cb49-4aa4-acf4-a5b703e9cb7a'"

foreach ($group in $groupsToConfigure) {
    foreach ($user in $usersToAssign) {
        $isAssinged = Get-MgIdentityGovernancePrivilegedAccessGroupEligibilityScheduleRequest -Filter "groupId eq '$($group.Id)' and principalId eq '$($user.Id)'"
        if (!$isAssinged) {
            <# Action to perform if the condition is true #>
            Write-Host "[$($context.Account)] Assigning user [$($user.DisplayName)][$($user.Id)] to group [$($group.DisplayName)][$($group.Id)]"
            $startTime = Get-Date # the start time of the assignment, here it is set to now
            $endTime = $startTime.AddMonths(12).AddDays(-1) # the end time of the assignment, here it is set to 12 months minus 1 day from the start time

            $params = @{
                accessId      = "member"
                principalId   = "$($user.Id)"
                groupId       = "$($group.Id)"
                action        = "AdminAssign"
                scheduleInfo  = @{
                    startDateTime = $startTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                    expiration    = @{
                        type        = "AfterDateTime"
                        endDateTime = $endTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                    }
                }
                justification = "Entra ID - PIM Group Assignment - $($group.DisplayName) - $($user.DisplayName)"
            }

            New-MgIdentityGovernancePrivilegedAccessGroupEligibilityScheduleRequest -BodyParameter $params
        }
        else {
            Write-Host "[$($context.Account)] User [$($user.DisplayName)][$($user.Id)] is already assigned to group [$($group.DisplayName)][$($group.Id)]"
        }
    }
}