Write-Host "🔮 Starting the enchantment to enable Privileged Identity Management (PIM) for groups" -ForegroundColor Cyan

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
if (!$groupsCreated) {
    Write-Host "🔍 No newly created groups detected. Retrieving all available groups for PIM activation." -ForegroundColor Yellow
    $groups = Get-MgGroup -All

    # Using a magical grid view to select groups
    $groupsToEnable = $groups | Select-Object DisplayName, Id | Out-ConsoleGridView -Title "Select groups to activate in PIM" -OutputMode Multiple
}
else {
    Write-Host "✨ Newly conjured groups detected. Preparing to enable PIM for these groups." -ForegroundColor Green
    $groupsToEnable = $groupsCreated
}

# Displaying the groups chosen for PIM enablement
# Inquiring the wizard (you) about their intention to create new groups
$enableGroups = Read-Host "enable groups in Privileged Identity Management ? (y/n)"
if ($enableGroups -eq "y") {
    # Ensure the user is connected to Azure
    Write-Host "Fetching the current Azure context..."
    $context = Get-AzContext
    if ($null -eq $context) {
        Write-Host "❗ Azure connection not detected. Requesting user to log in." -ForegroundColor Red
        Connect-AzAccount
    }
    else {
        Write-Host "🔗 Already connected to Azure as $($context.Account.Id)" -ForegroundColor Green
    }

    # Acquiring the token to communicate with the PIM API
    Write-Host "🔑 Acquiring the token to communicate with the Privileged Identity Management (PIM) API..." -ForegroundColor Cyan
    $accessTokenPim = (Get-AzAccessToken -ResourceUrl 'https://api.azrbac.mspim.azure.com').Token
    $headers = @{
        "Authorization" = "Bearer $accessTokenPim"
        "Content-Type"  = "application/json"
    }

    Write-Host "📋 Preparing to enable Privileged Identity Management for the following groups:" -ForegroundColor Cyan
    foreach ($group in $groupsToEnable) {
        Write-Host "🔎 Analyzing group: $($group.DisplayName) with ID: $($group.Id)" -ForegroundColor Magenta
    

        # Checking the current status of the group in PIM
        $findGroupInPim = Get-MgIdentityGovernancePrivilegedAccessGroupEligibilitySchedule -Filter "groupId eq '$($group.Id)'"

        if (!$findGroupInPim) {
            Write-Host "⚡ Group $($group.DisplayName) is not yet part of PIM. Preparing to onboard." -ForegroundColor Yellow
           
            write-host "🔮 Starting the enchantment to enable Privileged Identity Management (PIM) for groups" -ForegroundColor Cyan
            # The URL to the PIM API for group registration
            $url = "https://api.azrbac.mspim.azure.com/api/v2/privilegedAccess/aadGroups/resources/register" 
    
            # Onboarding the group to PIM
            Write-Host "🧙‍♂️ Onboarding group '$($group.DisplayName)' (ID: $($group.Id)) to PIM." -ForegroundColor Cyan
            Invoke-RestMethod -Uri $url -Headers $headers -Method Post -Body "{`"externalId`":`"$($group.id)`"}"
            Write-Host "✅ Group '$($group.DisplayName)' successfully onboarded to PIM." -ForegroundColor Green
        }
        else {
            Write-Host "🚫 Group $($group.DisplayName) is already part of PIM. No action needed." -ForegroundColor Gray
        }
    }
    
}
else {
    Write-Host "🔮 The wizard has decided not to enable PIM for the selected groups. Ending the enchantment." -ForegroundColor Cyan
}