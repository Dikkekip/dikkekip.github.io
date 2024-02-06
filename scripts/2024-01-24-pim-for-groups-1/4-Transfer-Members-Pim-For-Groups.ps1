# Import the required module
Import-Module Microsoft.Graph.Identity.Governance

# Get all the assignments
$assignments = Get-MgIdentityGovernancePrivilegedAccessGroupAssignmentSchedule

# Iterate over each assignment
foreach ($assignment in $assignments) {
    # Check if the AssignmentType is 'assigned'
    if ($assignment.AssignmentType -eq 'assigned') {
        # Create a new eligibility request
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