
# Displaying the groups chosen for PIM enablement
Write-Host "===================================================================================================="
Write-Host "🔮 [$($context.Account)] Final phase initiated: Assigning users to groups in Privileged Identity Management." -ForegroundColor Cyan

# Initiating the process of assigning users to the selected groups
Write-Host "🚀 [$($context.Account)] Commencing the user assignment to groups." -ForegroundColor Magenta

$context = Get-MgContext

if ($null -eq $context) {
    Write-Host "Graph connection not detected. Requesting user to log in."
    Connect-MgGraph -Scopes "User.Read.All", "PrivilegedAccess.ReadWrite.AzureADGroup"
    Write-Host "🧙‍♂️ Context acquired. Current wizard in control: $($context.Account)" -ForegroundColor Yellow

}
else {
    Write-Host "🧙‍♂️ Already connected to Graph as $($context.Account.Id)" -ForegroundColor Yellow
}

# Deciding which groups to enable PIM for
write-host "🔍 No newly created groups detected. Retrieving all available groups for PIM activation." -ForegroundColor Yellow
# Determining the groups for user assignment
if (!$groupsToEnable) {
    Write-Host "🤔 [$($context.Account)] No groups specified for enabling. Retrieving all groups for user assignment selection." -ForegroundColor Yellow
    $groupsToConfigure = Get-MgGroup -All | Select-Object DisplayName, Id | Out-ConsoleGridView -Title "Select groups for user assignment" -OutputMode Multiple
}
else {
    Write-Host "✨ [$($context.Account)] Preparing to assign users to the recently enabled groups." -ForegroundColor Green
    $groupsToConfigure = $groupsToEnable
}

# Selecting the users to assign to the groups
Write-Host "👥 Selecting users to assign to the groups." -ForegroundColor Cyan
$usersToAssign = Get-MgUser -Filter "AccountEnabled eq true" | Select-Object DisplayName, Id | Out-ConsoleGridView -Title "Select users for assignment" -OutputMode Multiple

foreach ($group in $groupsToConfigure) {
    foreach ($user in $usersToAssign) {
        # Checking if the user is already assigned to the group
        Write-Host "🔍 Checking if user '$($user.DisplayName)' is already assigned to group '$($group.DisplayName)'." -ForegroundColor Blue
        $isAssigned = Get-MgIdentityGovernancePrivilegedAccessGroupEligibilityScheduleRequest -Filter "groupId eq '$($group.Id)' and principalId eq '$($user.Id)'"
        
        if (!$isAssigned) {
            Write-Host "👩‍🏫 [$($context.Account)] Assigning user '$($user.DisplayName)' to group '$($group.DisplayName)'." -ForegroundColor Cyan
            # Setting the assignment start and end times
            $startTime = Get-Date
            $endTime = $startTime.AddMonths(12).AddDays(-1)

            # Preparing parameters for the assignment
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

            # Executing the assignment
            New-MgIdentityGovernancePrivilegedAccessGroupEligibilityScheduleRequest -BodyParameter $params
            Write-Host "✅ User '$($user.DisplayName)' successfully assigned to group '$($group.DisplayName)'." -ForegroundColor Green
        }
        else {
            Write-Host "🔄 [$($context.Account)] User '$($user.DisplayName)' is already a member of group '$($group.DisplayName)'. No action required." -ForegroundColor Gray
        }
    }
}
