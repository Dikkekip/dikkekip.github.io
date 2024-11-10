#params
param (
    [Parameter(Mandatory = $true)]
    [string]$tenantName
)

#variables
$logFile = "$PSScriptRoot\Phishing-resistant-authentication-onboarding.log"

$requiredScopes = @(
    "AdministrativeUnit.ReadWrite.All"
    "application.ReadWrite.All"
    "User.ReadWrite.All"
    "UserAuthenticationMethod.Read.All"
)

$testUserPrincipalName = ""

# Define application display name
$appDisplayName = "IAM Custom Attributes Manager"

# ------------------------------
# Define Required Modules
# ------------------------------

$requiredModules = @(
    "Microsoft.Graph.Beta.Identity.DirectoryManagement"
)

#functions

## base functions
function Write-log {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $logFile -Append
}

function Import-RequiredModules {
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$Modules
    )

    foreach ($module in $Modules) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            Write-Host "Module $module not found. Installing..." -ForegroundColor Yellow
            Write-log "Module $module not found. Installing..."
            try {
                Install-Module -Name $module -Scope CurrentUser -Force -ErrorAction Stop
                Write-Host "Module $module installed successfully." -ForegroundColor Green
                Write-log "Module $module installed successfully."
            }
            catch {
                Write-Host "Failed to install module $module. Error: $_" -ForegroundColor Red
                Write-log "Failed to install module $module. Error: $_"
                exit
            }
        }
        try {
            Import-Module $module -ErrorAction Stop
            Write-Host "Module $module imported successfully." -ForegroundColor Green
            Write-log "Module $module imported successfully."
        }
        catch {
            Write-Host "Failed to import module $module. Error: $_" -ForegroundColor Red
            Write-log "Failed to import module $module. Error: $_"
            exit
        }
    }
}
function Connect-ToMicrosoftGraph {
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$Scopes
    )

    if (-not (Get-MgContext)) {
        try {
            Write-Host "Connecting to Microsoft Graph. A sign-in prompt may appear..." -ForegroundColor Cyan
            Connect-MgGraph -Scopes $Scopes -ErrorAction Stop
            Write-Host "Connected to Microsoft Graph successfully." -ForegroundColor Green
            Write-log "Connected to Microsoft Graph successfully."
        }
        catch {
            Write-Host "Failed to connect to Microsoft Graph. Error: $_" -ForegroundColor Red
            Write-log "Failed to connect to Microsoft Graph. Error: $_"
            exit
        }
    }
    else {
        $currentScopes = Get-MgContext | Select-Object -ExpandProperty Scopes
        Write-Host "Already connected to Microsoft Graph with scopes: $($currentScopes -join ', ')." -ForegroundColor Yellow
        $missingScopes = $Scopes | Where-Object { $currentScopes -notcontains $_ }
        if ($missingScopes) {
            Write-Host "Reconnecting with required scopes..." -ForegroundColor Cyan
            try {
                Disconnect-MgGraph -ErrorAction Stop
                Connect-MgGraph -Scopes $Scopes -ErrorAction Stop
                Write-Host "Reconnected to Microsoft Graph successfully." -ForegroundColor Green
                Write-log "Reconnected to Microsoft Graph successfully."
            }
            catch {
                Write-Host "Failed to reconnect to Microsoft Graph. Error: $_" -ForegroundColor Red
                Write-log "Failed to reconnect to Microsoft Graph. Error: $_"
                exit
            }
        }
    }
}



## AU Creation ##

function Add-GetCreateAU {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    Write-Host "[DEBUG] Checking if Administrative Unit '$Name' exists..." -ForegroundColor Cyan
    try {
        $existingAU = Get-MgBetaDirectoryAdministrativeUnit -Filter "displayName eq '$Name'" -ErrorAction SilentlyContinue
        if ($null -ne $existingAU) {
            Write-Host "[DEBUG] Administrative Unit '$Name' already exists. AU ID: $($existingAU.Id)" -ForegroundColor Green
            return $existingAU
        }
    }
    catch {
        Write-Host "[ERROR] Error while checking for existing Administrative Unit: $_" -ForegroundColor Red
        continue
    }

    try {
        Write-Host "[DEBUG] Creating new Administrative Unit with name '$Name'..." -ForegroundColor Cyan
        $auParams = @{
            DisplayName                  = $Name
            Description                  = $Description
            isMemberManagementRestricted = $true
        }
        $au = New-MgBetaDirectoryAdministrativeUnit -BodyParameter $auParams -ErrorAction Stop
        Write-Host "[DEBUG] Administrative Unit '$Name' created successfully. AU ID: $($au.Id)" -ForegroundColor Green
        return $au
    }
    catch {
        Write-Host "[ERROR] Failed to create Administrative Unit. Error: $_" -ForegroundColor Red
        continue
    }
}

function Add-MembersToAU {
    param (
        [Parameter(Mandatory = $true)]
        [string]$AUId
    )

    # Prompt user for member type to add
    while ($true) {
        Write-Host "Do you want to add Users, Groups, Both, or Skip adding members to the Administrative Unit?" -ForegroundColor Cyan
        $memberTypeChoice = Read-Host "Enter 'U' for Users, 'G' for Groups, 'B' for Both, or 'S' to Skip"

        if ($memberTypeChoice -match '^[UGBS]$') {
            if ($memberTypeChoice -eq 'S') {
                Write-Host "Skipping adding members to the AU." -ForegroundColor Cyan
                Write-log "User chose to skip adding members to the AU."
                return  # Exit the function
            }
            break
        }
        else {
            Write-Host "Invalid selection. Please enter 'U' for Users, 'G' for Groups, 'B' for Both, or 'S' to Skip." -ForegroundColor Yellow
        }
    }

    # Retrieve members based on choice
    $allMembers = @()

    try {
        switch ($memberTypeChoice) {
            'U' {
                Write-Host "Retrieving all users..." -ForegroundColor Cyan
                $allMembers = Get-MgUser -All -Select DisplayName, UserPrincipalName, Id -ErrorAction Stop
            }
            'G' {
                Write-Host "Retrieving all groups..." -ForegroundColor Cyan
                $allMembers = Get-MgGroup -All -Select DisplayName, Id -ErrorAction Stop
            }
            'B' {
                Write-Host "Retrieving all users and groups..." -ForegroundColor Cyan
                $allUsers = Get-MgUser -All -Select DisplayName, UserPrincipalName, Id -ErrorAction Stop
                $allGroups = Get-MgGroup -All -Select DisplayName, Id -ErrorAction Stop
                $allMembers = $allUsers + $allGroups
            }
        }
    }
    catch {
        Write-Host "❌ Error retrieving members: $_" -ForegroundColor Red
        Write-log "Error retrieving members: $_"
        return
    }

    if ($allMembers.Count -eq 0) {
        Write-Host "No members found to add." -ForegroundColor Yellow
        Write-log "No members found to add."
        return
    }

    # Use Out-ConsoleGridView for selection
    if (Get-Command -Name Out-ConsoleGridView -ErrorAction SilentlyContinue) {
        $selectedMembers = $allMembers | Out-ConsoleGridView -Title "Select Members to Add to the AU" -OutputMode Multiple
    }
    else {
        Write-Host "❌ Out-ConsoleGridView is not available. Please install it using 'Install-Module Microsoft.PowerShell.ConsoleGuiTools'." -ForegroundColor Red
        Write-log "Out-ConsoleGridView is not available."
        return
    }

    if (-not $selectedMembers -or $selectedMembers.Count -eq 0) {
        Write-Host "❌ No members selected. Skipping adding members to the AU." -ForegroundColor Yellow
        Write-log "No members selected. Skipping adding members to the AU."
        return
    }

    # Add selected members to AU
    Write-Host "[DEBUG] Starting to add members to Administrative Unit ID: $AUId..." -ForegroundColor Cyan
    foreach ($member in $selectedMembers) {
        try {
            Write-Host "[DEBUG] Adding member '$($member.DisplayName)' (ID: $($member.Id)) to AU ID: $AUId..." -ForegroundColor Cyan
            New-MgBetaDirectoryAdministrativeUnitMemberByRef -AdministrativeUnitId $AUId -BodyParameter @{ "@odata.id" = "https://graph.microsoft.com/beta/directoryObjects/$($member.Id)" } -ErrorAction Stop
            Write-Host "[DEBUG] Member '$($member.DisplayName)' added successfully." -ForegroundColor Green
        }
        catch {
            Write-Host "[ERROR] Failed to add member '$($member.DisplayName)' to AU. Error: $_" -ForegroundColor Red
        }
    }
    Write-Host "[DEBUG] Completed adding members to Administrative Unit ID: $AUId." -ForegroundColor Cyan
}

function Add-RoleAssignentToAU {
    param (
        [Parameter(Mandatory = $true)]
        [string]$PrincipalId,

        [Parameter(Mandatory = $true)]
        [string]$RoleName,

        [Parameter(Mandatory = $true)]
        [PSCustomObject]$adminUnit,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Active", "Eligible")]
        [string]$AssignmentType
    )

    $RoleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -Filter "displayName eq '$RoleName'"
    if (-not $RoleDefinition) {
        Write-Host "[ERROR] Role '$RoleName' not found." -ForegroundColor Red
        return
    }
    $RoleDefinitionId = $RoleDefinition.Id
    $ScopeId = "/administrativeUnits/$($adminUnit.id)"

    if ($AssignmentType -eq "Active") {
        Write-Host "[DEBUG] Checking if active role assignment already exists for Principal ID: $PrincipalId in Scope: $ScopeId..." -ForegroundColor Cyan
        try {
            $existingAssignment = Get-MgRoleManagementDirectoryRoleAssignment -Filter "principalId eq '$PrincipalId' and roleDefinitionId eq '$RoleDefinitionId' and directoryScopeId eq '$ScopeId'" -ErrorAction SilentlyContinue
            if ($null -ne $existingAssignment) {
                Write-Host "[DEBUG] Role already assigned to principal with ID '$PrincipalId' in scope '$ScopeId'." -ForegroundColor Yellow
                return
            }
        }
        catch {
            Write-Host "[ERROR] Error while checking existing role assignment: $_" -ForegroundColor Red
        }

        Write-Host "[DEBUG] Assigning role (ID: $RoleDefinitionId) to Principal (ID: $PrincipalId) for Scope (ID: $ScopeId)..." -ForegroundColor Cyan
        try {
            New-MgRoleManagementDirectoryRoleAssignment -PrincipalId $PrincipalId -RoleDefinitionId $RoleDefinitionId -DirectoryScopeId $ScopeId -ErrorAction Stop
            Write-Host "[DEBUG] Active role assigned successfully." -ForegroundColor Green
        }
        catch {
            Write-Host "[ERROR] Failed to assign active role. Error: $_" -ForegroundColor Red
        }
    }
    elseif ($AssignmentType -eq "Eligible") {
        Write-Host "[DEBUG] Checking if eligible role assignment already exists for Principal ID: $PrincipalId in Scope: $ScopeId..." -ForegroundColor Cyan
        try {
            $eligibilitySchedules = Get-MgRoleManagementDirectoryRoleEligibilitySchedule -Filter "principalId eq '$PrincipalId' and roleDefinitionId eq '$RoleDefinitionId' and directoryScopeId eq '$ScopeId'" -ErrorAction Stop
            if ($eligibilitySchedules.Count -gt 0) {
                Write-Host "[DEBUG] Principal ID '$PrincipalId' already has eligibility for the role in scope '$ScopeId'." -ForegroundColor Yellow
                return
            }
        }
        catch {
            Write-Host "[ERROR] Error checking eligibility: $_" -ForegroundColor Red
        }

        Write-Host "[DEBUG] Assigning eligible role to Principal (ID: $PrincipalId) for Scope (ID: $ScopeId)..." -ForegroundColor Cyan
        $currentDateTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $expirationDateTime = (Get-Date).AddYears(1).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $params = @{
            Action           = "adminAssign"
            Justification    = "Assign $RoleName eligibility to user"
            RoleDefinitionId = $RoleDefinitionId
            DirectoryScopeId = $ScopeId
            PrincipalId      = $PrincipalId
            ScheduleInfo     = @{
                StartDateTime = $currentDateTime
                Expiration    = @{
                    Type        = "AfterDateTime"
                    EndDateTime = $expirationDateTime
                }
            }
        }

        try {
            New-MgRoleManagementDirectoryRoleEligibilityScheduleRequest -BodyParameter $params -ErrorAction Stop
            Write-Host "[DEBUG] Eligible role assigned successfully." -ForegroundColor Green
        }
        catch {
            Write-Host "[ERROR] Failed to assign eligible role. Error: $_" -ForegroundColor Red
        }
    }
    else {
        Write-Host "[ERROR] Invalid AssignmentType specified. Use 'Active' or 'Eligible'." -ForegroundColor Red
    }
}
function New-EligibeRoleActivationForAU {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$adminUnit, # Administrative Unit as an object

        [Parameter(Mandatory = $true)]
        [string]$UserObjectId, # The Object ID of the user

        [string]$roleName = "User Administrator" # Default role to be activated
    )

    Write-Host "Current user Object ID: $UserObjectId"
    Write-log "Current user Object ID: $UserObjectId"

    # Get the role definition for the provided role name
    $roleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -Filter "displayName eq '$roleName'" -All
    if (-not $roleDefinition) {
        Write-Host "❌ Role definition for $roleName not found. Exiting script." -ForegroundColor Red
        Write-log "Role definition for $roleName not found."
        return $false
    }

    $roleId = $roleDefinition.Id
    Write-Host "[DEBUG] RoleDefinition ID: $roleId" -ForegroundColor Cyan
    Write-log "RoleDefinition ID: $roleId"

    # Check if the user has an eligible assignment for the role in the specified AU
    try {
        $eligibleAssignments = Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance -Filter "roleDefinitionId eq '$roleId' and principalId eq '$UserObjectId' and directoryScopeId eq '/administrativeUnits/$($adminUnit.Id)'" -All
    }
    catch {
        Write-Host "❌ Error while fetching eligible assignments: $_" -ForegroundColor Red
        Write-log "Error while fetching eligible assignments: $_"
        return $false
    }

    if (-not $eligibleAssignments -or $eligibleAssignments.Count -eq 0) {
        Write-Host "❌ No eligible assignment found for $roleName in AU $($adminUnit.Id). Please create an eligible role assignment first." -ForegroundColor Red
        Write-log "No eligible assignment found for $roleName in AU $($adminUnit.Id)."
        Write-Host "[DEBUG] Eligible assignments fetched: $($eligibleAssignments | Out-String)" -ForegroundColor Yellow
        return $false
    }

    $eligibleAssignmentId = $eligibleAssignments.Id
    if (-not $eligibleAssignmentId) {
        Write-Host "❌ Eligible assignment ID could not be determined." -ForegroundColor Red
        Write-log "Eligible assignment ID could not be determined."
        return $false
    }

    Write-Host "✅ Eligible assignment found for role $roleName in AU: $($adminUnit.Id). Assignment ID: $eligibleAssignmentId" -ForegroundColor Green
    Write-log "Eligible assignment found for role $roleName in AU: $($adminUnit.Id). Assignment ID: $eligibleAssignmentId"

    # Check if the role is already active for the specified AU
    try {
        $activeAssignments = Get-MgRoleManagementDirectoryRoleAssignmentScheduleInstance -All | Where-Object {
            $_.RoleDefinitionId -eq $roleId -and $_.PrincipalId -eq $UserObjectId -and $_.DirectoryScopeId -eq "/administrativeUnits/$($adminUnit.Id)"
        }
    }
    catch {
        Write-Host "❌ Error while fetching active assignments: $_" -ForegroundColor Red
        Write-log "Error while fetching active assignments: $_"
        return $false
    }

    if ($activeAssignments -and $activeAssignments.Count -gt 0) {
        Write-Host "✅ PIM role $roleName is already active for the AU: $($adminUnit.Id)." -ForegroundColor Green
        Write-log "PIM role $roleName is already active for the AU: $($adminUnit.Id)."
        return $true
    }

    # Activate the eligible role assignment for 1 hour
    Write-Host "🧙‍♂️ Activating PIM role $roleName for 1 hour on AU: $($adminUnit.Id)..."
    Write-log "Activating PIM role $roleName for 1 hour on AU: $($adminUnit.Id)."
    $params = @{
        Action                         = "selfActivate"
        PrincipalId                    = $UserObjectId
        RoleDefinitionId               = $roleId
        DirectoryScopeId               = "/administrativeUnits/$($adminUnit.Id)"
        LinkedEligibleRoleAssignmentId = $eligibleAssignmentId
        Justification                  = "Script execution: Activating $roleName role for AU $($adminUnit.Name)"
        ScheduleInfo                   = @{
            StartDateTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            Expiration    = @{
                Type     = "AfterDuration"
                Duration = "PT1H"
            }
        }
    }
    try {
        New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $params | Out-Null
        Write-Host "✨ PIM role $roleName activation requested for AU: $($adminUnit.Id)." -ForegroundColor Green
        Write-log "PIM role $roleName activation requested for AU: $($adminUnit.Id)."
    }
    catch {
        Write-Host "❌ Failed to activate PIM role $roleName for AU: $($adminUnit.Id). Error: $_" -ForegroundColor Red
        Write-log "Failed to activate PIM role $roleName for AU: $($adminUnit.Id). Error: $_"
        return $false
    }

    return $true
}


## App Registration ##

# Helper function to update user phishing-resistant statusfunction Ensure-IAMExtension 
function Get-IAMExtensionProperty {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage = 'The application object containing Id and AppId.')]
        [ValidateNotNull()]
        [Microsoft.Graph.PowerShell.Models.IMicrosoftGraphApplication]$Application,

        [Parameter(Mandatory = $true, HelpMessage = 'The name of the extension property.')]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true, HelpMessage = 'The data type of the extension property (e.g., "Boolean", "String").')]
        [ValidateSet('Binary', 'Boolean', 'DateTime', 'Integer', 'LargeInteger', 'String')]
        [string]$DataType
    )

    <#
    .SYNOPSIS
        Retrieves a custom extension property for an application, creating it if it doesn't already exist.

    .DESCRIPTION
        This function checks if a custom extension property with the specified name and data type exists for the given application.
        If it exists, it returns the full name of the extension property.
        If it does not exist, it creates the extension property and then returns the full name.

    .PARAMETER Application
        The application object containing Id and AppId properties.

    .PARAMETER Name
        The name of the extension property.

    .PARAMETER DataType
        The data type of the extension property.

    .OUTPUTS
        String

    .EXAMPLE
        $extensionName = Get-IAMExtensionProperty -Application $app -Name "phishingResistantEnabled" -DataType "Boolean"
    #>

    try {
        # Ensure that the application object has both Id and AppId properties
        if (-not $Application.Id -or -not $Application.AppId) {
            throw "The Application object must contain both 'Id' and 'AppId' properties."
        }

        # Retrieve existing extension properties
        $extensions = Get-MgApplicationExtensionProperty -ApplicationId $Application.Id -ErrorAction Stop

        # Clean the AppId by removing hyphens
        $cleanAppId = $Application.AppId -replace '-', ''
        $fullName = "extension_$($cleanAppId)_$Name"

        # Check if the extension property already exists
        $existing = $extensions | Where-Object { $_.Name -eq $fullName }

        if ($existing) {
            Write-Verbose "Extension property '$Name' already exists as '$fullName'."
        }
        else {
            # Create the new extension property
            $params = @{
                Name          = $Name
                DataType      = $DataType
                TargetObjects = @('User')
            }
            $newExtension = New-MgApplicationExtensionProperty -ApplicationId $Application.Id -BodyParameter $params -ErrorAction Stop
            Write-Verbose "Created new extension property: $($newExtension.Name)"
        }
        return $fullName
    }
    catch {
        Write-Error "Failed to create or retrieve extension property: $_"
    }
}

    
function Get-IAMDynamicGroup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, HelpMessage = 'The display name of the group.')]
        [ValidateNotNullOrEmpty()]
        [string]$DisplayName,

        [Parameter(Mandatory = $true, HelpMessage = 'The membership rule for dynamic group membership.')]
        [ValidateNotNullOrEmpty()]
        [string]$MembershipRule,

        [Parameter(Mandatory = $false, HelpMessage = 'The description of the group.')]
        [string]$Description = 'Dynamically managed group',

        [Parameter(Mandatory = $false, HelpMessage = 'Additional properties for the group.')]
        [hashtable]$AdditionalProperties
    )

    <#
    .SYNOPSIS
        Retrieves a dynamic group if it exists; otherwise, creates it with the specified membership rule.

    .DESCRIPTION
        This function checks if a dynamic group with the specified display name exists.
        If it exists, it returns the group object.
        If it does not exist, it creates a new dynamic group with the provided membership rule and returns the group object.

    .PARAMETER DisplayName
        The display name of the group.

    .PARAMETER MembershipRule
        The membership rule for dynamic group membership.

    .PARAMETER Description
        The description of the group.

    .PARAMETER AdditionalProperties
        A hashtable of additional properties to set on the group.

    .OUTPUTS
        Microsoft.Graph.PowerShell.Models.IMicrosoftGraphGroup

    .EXAMPLE
        $group = Get-IAMDynamicGroup -DisplayName 'PhishingResistantInactiveUsers' -MembershipRule $membershipRule
    #>

    try {
        # Attempt to retrieve the existing group
        $existingGroup = Get-MgGroup -Filter "DisplayName eq '$DisplayName'" -ConsistencyLevel eventual -CountVariable count -ErrorAction Stop

        if ($existingGroup) {
            Write-Verbose "Dynamic group already exists: $DisplayName"
            return $existingGroup
        }
        else {
            Write-Verbose "Dynamic group '$DisplayName' does not exist. Creating a new group."

            # Prepare the group properties
            $mailNickname = $DisplayName -replace '[-\s]', ''
            $groupBody = @{
                DisplayName                   = $DisplayName
                Description                   = $Description
                MailEnabled                   = $false
                MailNickname                  = $mailNickname
                SecurityEnabled               = $true
                GroupTypes                    = @('DynamicMembership')
                MembershipRule                = $MembershipRule
                MembershipRuleProcessingState = 'On'
            }

            # Add any additional properties
            if ($AdditionalProperties) {
                $groupBody += $AdditionalProperties
            }

            # Create the new dynamic group
            $group = New-MgGroup -BodyParameter $groupBody -ErrorAction Stop
            Write-Verbose "Created new dynamic group: $DisplayName"
            return $group
        }
    }
    catch {
        Write-Error "Failed to retrieve or create dynamic group: $_"
    }
}
 
function Update-IAMPhishingResistantStatus {
    param (
        [Parameter(Mandatory = $true, HelpMessage = 'The user or group object.')]
        [PSCustomObject]$Object,

        [Parameter(Mandatory = $true, HelpMessage = 'Specify whether the object is a "Group" or "User".')]
        [ValidateSet("Group", "User")]
        [string]$ObjectType,

        [Parameter(Mandatory = $true, HelpMessage = 'The custom extension attribute for phishing-resistant enabled status.')]
        [string]$PhishingResistantEnabledAttr,

        [Parameter(Mandatory = $true, HelpMessage = 'The custom extension attribute for the last checked timestamp.')]
        [string]$PhishingResistantLastCheckedAttr,

        [Parameter(Mandatory = $true, HelpMessage = 'The custom extension attribute for phishing-resistant status ("Active"/"Inactive").')]
        [string]$PhishingResistantStatusAttr
    )

    try {
        # If the object is a group, retrieve all members of the group
        if ($ObjectType -eq "Group") {
            Write-Host "Retrieving members of group with ID: $($Object.Id)"
            $members = Get-MgGroupMember -GroupId $Object.Id -All -ErrorAction Stop
        }
        # If the object is a user, treat it as a single member
        elseif ($ObjectType -eq "User") {
            Write-Host "Processing single user with ID: $($Object.Id)"
            $members = @()
            $members += @{ Id = $Object.Id }  # Create a pseudo-member object with only the ID
        }

        # Loop through each member (user)
        foreach ($member in $members) {
            $userId = $member.Id

            Write-Host "`nProcessing user with ID: $userId"

            # Get the user's current attributes
            $user = Get-MgUser -UserId $userId -ErrorAction Stop
            $currentAttributes = $user.AdditionalProperties

            # Check the user's authentication methods
            $authMethods = Get-MgUserAuthenticationMethod -UserId $userId
            $hasPhishingResistant = $false

            foreach ($method in $authMethods) {
                if ($method.AdditionalProperties["@odata.type"] -eq "#microsoft.graph.fido2AuthenticationMethod") {
                    $hasPhishingResistant = $true
                    break
                }
            }

            # Log phishing-resistant detection
            Write-Host "Phishing Resistant detected: $hasPhishingResistant"

            # Prepare new attribute values
            $newPhishingResistantEnabled = $hasPhishingResistant
            $newPhishingResistantLastChecked = (Get-Date).ToString("o")
            $newPhishingResistantStatus = if ($hasPhishingResistant) { "Active" } else { "Inactive" }

            # Update the user's custom extension attributes
            $params = @{
                $PhishingResistantEnabledAttr     = $newPhishingResistantEnabled
                $PhishingResistantLastCheckedAttr = $newPhishingResistantLastChecked
                $PhishingResistantStatusAttr      = $newPhishingResistantStatus
            }

            try {
                Write-Output "Updating custom extension attributes for user: $($user.UserPrincipalName)"
                Write-Output "New attribute values:"
                Write-Output "  Phishing Resistant Enabled: $newPhishingResistantEnabled"
                Write-Output "  Phishing Resistant Last Checked: $newPhishingResistantLastChecked"
                Write-Output "  Phishing Resistant Status: $newPhishingResistantStatus"
                Update-MgUser -UserId $userId -BodyParameter $params
                Write-Host "Successfully updated attributes for user: $($user.UserPrincipalName)"
            }
            catch {
                Write-Error "Failed to update attributes for user: $($user.UserPrincipalName). Error details: $_"
            }
        }

        Write-Host "`nPhishing Resistant Status update completed."
    }
    catch {
        Write-Error "Failed to process: $_"
    }
}

function New-IAMhourlyCheckerScript {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AppId,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PhishingResistantEnabledAttr,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PhishingResistantLastCheckedAttr,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PhishingResistantStatusAttr,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject[]]$Groups,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath = (Join-Path -Path (Get-Location) -ChildPath 'hourlyCheckerScript.ps1')
    )

    try {
        # Convert groups array to a string representation
        $groupsArrayString = $Groups | ForEach-Object {
            "        @{ Id = '$($_.Id)'; Name = '$($_.DisplayName)' }"
        } | Join-String -Separator ",`n"

        $hourlyCheckerScriptContent = @"
#Requires -Modules Microsoft.Graph.Authentication
#Requires -Modules Microsoft.Graph.Users
# Hourly Checker Script for IAM Custom Extension Attributes
# Generated on: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
`$ErrorActionPreference = 'Stop'

# Initialize logging for Azure Automation
function Write-Log {
    param(
        [string]`$Message,
        [ValidateSet('INFO', 'WARNING', 'ERROR')]
        [string]`$Level = 'INFO'
    )
    
    `$TimeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    `$LogMessage = "`$TimeStamp [`$Level] `$Message"
    
    # Write to Azure Automation log
    Write-Output `$LogMessage
    
    switch (`$Level) {
        'INFO'    { Write-Verbose `$LogMessage -Verbose }
        'WARNING' { Write-Warning `$LogMessage }
        'ERROR'   { Write-Error `$LogMessage }
    }
}

$retryCount = 3
for ($i = 0; $i -lt $retryCount; $i++) {
    try {
        Write-Log "Attempting to connect to Microsoft Graph (Attempt $($i + 1))"
        Connect-MgGraph -Identity -ErrorAction Stop
        Write-Log "Successfully connected to Microsoft Graph"
        break
    }
    catch {
        Write-Log "Attempt $($i + 1) failed to connect to Microsoft Graph: $_" -Level 'WARNING'
        if ($i -eq ($retryCount - 1)) {
            throw "Failed to connect to Microsoft Graph after $retryCount attempts."
        }
        Start-Sleep -Seconds 5
    }
}

try {
    Write-Log "Starting IAM attribute check process"

    `$appId = '$AppId'
    `$phishingResistantEnabledAttr = '$PhishingResistantEnabledAttr'
    `$phishingResistantLastCheckedAttr = '$PhishingResistantLastCheckedAttr'
    `$phishingResistantStatusAttr = '$PhishingResistantStatusAttr'

    `$groups = @(
$groupsArrayString
    )

    function Test-MgPermissions {
        param (
            [string]`$UserId,
            [string]`$UserPrincipalName
        )

        `$permissionTests = @(
            @{
                Name = "Get-MgUserAuthenticationMethod"
                Test = {
                    Get-MgUserAuthenticationMethod -UserId `$UserId -ErrorAction Stop | Out-Null
                }
            },
            @{
                Name = "Update-MgUser"
                Test = {
                    `$currentUser = Get-MgUser -UserId `$UserId -ErrorAction Stop
                    Update-MgUser -UserId `$UserId -BodyParameter @{ displayName = `$currentUser.DisplayName } -ErrorAction Stop
                }
            }
        )

        foreach (`$test in `$permissionTests) {
            try {
                & `$test.Test
                Write-Log "Permission check passed: `$(`$test.Name)" -Level 'INFO'
            }
            catch {
                Write-Log "Permission check failed for `$(`$test.Name) on user `$UserPrincipalName : `$_" -Level 'ERROR'
                return `$false
            }
        }
        return `$true
    }

    foreach (`$group in `$groups) {
        Write-Log "Processing group: `$(`$group.Name)"

        try {
            `$groupMembers = Get-MgGroupMember -GroupId `$group.Id -All -ErrorAction Stop
            
            if (-not `$groupMembers) {
                Write-Log "No members found in group: `$(`$group.Name)" -Level 'WARNING'
                continue
            }

            # Test permissions with first user
            `$testUser = Get-MgUser -UserId `$groupMembers[0].Id -ErrorAction Stop
            if (-not (Test-MgPermissions -UserId `$testUser.Id -UserPrincipalName `$testUser.UserPrincipalName)) {
                Write-Log "Skipping group `$(`$group.Name) due to insufficient permissions" -Level 'WARNING'
                continue
            }

            foreach (`$member in `$groupMembers) {
                try {
                    `$user = Get-MgUser -UserId `$member.Id -ErrorAction Stop
                    Write-Log "Processing user: `$(`$user.UserPrincipalName)"

                    `$authMethods = Get-MgUserAuthenticationMethod -UserId `$user.Id -ErrorAction Stop
                    `$hasPhishingResistant = `$authMethods.AdditionalProperties.'@odata.type' -contains '#microsoft.graph.fido2AuthenticationMethod'

                    `$params = @{
                        `$phishingResistantEnabledAttr = `$hasPhishingResistant
                        `$phishingResistantLastCheckedAttr = (Get-Date).ToString('o')
                        `$phishingResistantStatusAttr = if (`$hasPhishingResistant) { 'Active' } else { 'Inactive' }
                    }

                    Update-MgUser -UserId `$user.Id -BodyParameter `$params -ErrorAction Stop
                    Write-Log "Successfully updated attributes for user: `$(`$user.UserPrincipalName)"
                }
                catch {
                    Write-Log "Error processing user `$(`$user.UserPrincipalName): `$_" -Level 'ERROR'
                }
            }
        }
        catch {
            Write-Log "Error processing group `$(`$group.Name): `$_" -Level 'ERROR'
        }
    }
}
catch {
    Write-Log "Critical error in script execution: `$_" -Level 'ERROR'
}
finally {
    try {
        Disconnect-MgGraph -ErrorAction Stop
        Write-Log "Successfully disconnected from Microsoft Graph"
    }
    catch {
        Write-Log "Error disconnecting from Microsoft Graph: `$_" -Level 'ERROR'
    }
}
"@

        # Save the script content to a file
        $hourlyCheckerScriptContent | Set-Content -Path $OutputPath -Encoding UTF8
        Write-Host "[INFO] Hourly Checker Script created at: $OutputPath" -ForegroundColor Green
        return $OutputPath
    }
    catch {
        Write-Error -Message "Failed to create hourly checker script: $_"
    }
}


function New-AuthenticationStrength {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$Description,
        [Parameter(Mandatory = $true)]
        [string[]]$AllowedCombinations
    )

    Write-Host "[DEBUG] Checking if Authentication Strength '$Name' exists..." -ForegroundColor Cyan
    try {
        $existingStrength = Get-MgBetaIdentityConditionalAccessAuthenticationStrengthPolicy -Filter "displayName eq '$Name'" -ErrorAction SilentlyContinue
        if ($null -ne $existingStrength) {
            Write-Host "[DEBUG] Authentication Strength '$Name' already exists. Strength ID: $($existingStrength.Id)" -ForegroundColor Green
            return $existingStrength
        }
    }
    catch {
        Write-Host "[ERROR] Error while checking for existing Authentication Strength: $_" -ForegroundColor Red
        exit
    }

    try {
        Write-Host "[DEBUG] Creating new Authentication Strength with name '$Name'..." -ForegroundColor Cyan
        $strengthParams = @{
            DisplayName = $Name
            Description = $Description
            AllowedCombinations = $AllowedCombinations
            CombinationConfigurations = @()
        }
        $authStrength = New-MgBetaIdentityConditionalAccessAuthenticationStrengthPolicy -BodyParameter $strengthParams -ErrorAction Stop
        Write-Host "[DEBUG] Authentication Strength '$Name' created successfully. Strength ID: $($authStrength.Id)" -ForegroundColor Green
        return $authStrength
    }
    catch {
        Write-Host "[ERROR] Failed to create Authentication Strength. Error: $_" -ForegroundColor Red
        exit
    }
}

function Get-AuthenticationStrength {
    param (
        [Parameter(Mandatory = $false)]
        [string]$Name
    )

    Write-Host "[DEBUG] Retrieving Authentication Strength..." -ForegroundColor Cyan
    try {
        if ($Name) {
            $authStrength = Get-MgBetaIdentityConditionalAccessAuthenticationStrengthPolicy -Filter "displayName eq '$Name'" -ErrorAction Stop
            if ($null -eq $authStrength) {
                Write-Host "[DEBUG] No Authentication Strength found with the name '$Name'." -ForegroundColor Yellow
            } else {
                Write-Host "[DEBUG] Authentication Strength '$Name' found. Strength ID: $($authStrength.Id)" -ForegroundColor Green
            }
            return $authStrength
        } else {
            $authStrengths = Get-MgBetaIdentityConditionalAccessAuthenticationStrengthPolicy -ErrorAction Stop
            Write-Host "[DEBUG] Retrieved all Authentication Strengths." -ForegroundColor Green
            return $authStrengths
        }
    }
    catch {
        Write-Host "[ERROR] Failed to retrieve Authentication Strength. Error: $_" -ForegroundColor Red
        exit
    }
}

function New-ConditionalAccessPolicy {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$PolicyParams
    )

    Write-Host "[DEBUG] Creating new Conditional Access policy..." -ForegroundColor Cyan
    try {
        New-MgIdentityConditionalAccessPolicy -BodyParameter $PolicyParams -ErrorAction Stop
        Write-Host "Policy '$($PolicyParams.DisplayName)' created successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] Failed to create policy '$($PolicyParams.DisplayName)': $_" -ForegroundColor Red
    }
}

function Get-GroupIdByName {
    param (
        [Parameter(Mandatory = $true)]
        [string]$GroupName,
        [Parameter(Mandatory = $true)]
        [array]$Groups
    )

    $group = $Groups | Where-Object { $_.DisplayName -eq $GroupName }
    if ($group) {
        return $group.Id
    }
    else {
        Write-Host "[ERROR] Group '$GroupName' not found." -ForegroundColor Yellow
        return $null
    }
}

function Update-ConditionalAccessPolicy {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Policy,
        [Parameter(Mandatory = $true)]
        [hashtable]$ExistingPolicy
    )

    Write-Host "[DEBUG] Updating Conditional Access policy '$($Policy.DisplayName)'..." -ForegroundColor Cyan
    try {
        Update-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $ExistingPolicy.Id -BodyParameter $Policy -ErrorAction Stop
        Write-Host "Policy '$($Policy.DisplayName)' updated successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] Failed to update policy '$($Policy.DisplayName)': $_" -ForegroundColor Red
        Add-Content -Path ".\failed_policies.log" -Value "Failed to update policy '$($Policy.DisplayName)': $_"
    }
}

function New-ConditionalAccessPoliciesNew {
    param (
        [Parameter(Mandatory = $true)]
        [array]$Policies
    )

    $groups = Get-MgGroup -All | Select-Object DisplayName, Id
    Write-Host "[DEBUG] Retrieved all groups for Conditional Access policies." -ForegroundColor Cyan

    foreach ($policy in $Policies) {
        if ($policy.Conditions.Users.IncludeGroups) {
            $policy.Conditions.Users.IncludeGroups = $policy.Conditions.Users.IncludeGroups | ForEach-Object { Get-GroupIdByName -GroupName $_ -Groups $groups }
        }
        if ($policy.Conditions.Users.ExcludeGroups) {
            $policy.Conditions.Users.ExcludeGroups = $policy.Conditions.Users.ExcludeGroups | ForEach-Object { Get-GroupIdByName -GroupName $_ -Groups $groups }
        }
    }

    $existingPolicies = Get-MgIdentityConditionalAccessPolicy -All
    Write-Host "[DEBUG] Retrieved existing Conditional Access policies." -ForegroundColor Cyan

    foreach ($policy in $Policies) {
        $existingPolicy = $existingPolicies | Where-Object { $_.DisplayName -eq $policy.DisplayName }
        
        if ($existingPolicy) {
            Write-Host "Policy '$($policy.DisplayName)' already exists. Checking settings..." -ForegroundColor Yellow
            if ($existingPolicy.Conditions -ne $policy.Conditions -or $existingPolicy.State -ne $policy.State) {
                Write-Host "Policy '$($policy.DisplayName)' settings differ. Updating policy..." -ForegroundColor Cyan
                Update-ConditionalAccessPolicy -Policy $policy -ExistingPolicy $existingPolicy
            }
            else {
                Write-Host "Policy '$($policy.DisplayName)' settings are identical. No update needed." -ForegroundColor Green
            }
        }
        else {
            Write-Host "Creating policy '$($policy.DisplayName)'..." -ForegroundColor Cyan
            New-ConditionalAccessPolicy -PolicyParams $policy
        }
    }
}


# ------------------------------


#Script 

# Import required modules
Import-RequiredModules -Modules $requiredModules


# ------------------------------
# Connect to Microsoft Graph
# ------------------------------


# Call the function
Connect-ToMicrosoftGraph -Scopes $requiredScopes


Write-Host "[INFO] Starting to provision Administrative Units and assign roles..." -ForegroundColor Cyan
$administrativeUnit = Add-GetCreateAU -Name "$tenantName Platform Admins" -Description "Administrative Unit for $tenantName Platform Admins"

write-host "[INFO] Adding members to the Administrative Unit..." -ForegroundColor Cyan
Add-MembersToAU -AUId $administrativeUnit.Id

$adminUserName = Get-MgContext | Select-Object -ExpandProperty Account
$adminUser = Get-MgUser -Filter "userPrincipalName eq '$adminUserName'" -ErrorAction SilentlyContinue
write-host "[INFO] Assigning roles to $adminUserName in $administrativeUnit..." -ForegroundColor Cyan
Add-RoleAssignentToAU -PrincipalId $adminUser.Id -roleName "User Administrator" -adminUnit $administrativeUnit -AssignmentType "Eligible"
Write-Host "[INFO] User Administrator role assigned to $adminUserName in $administrativeUnit." -ForegroundColor Green
Add-RoleAssignentToAU -PrincipalId $adminUser.Id -roleName "Privileged Authentication Administrator" -adminUnit $administrativeUnit -AssignmentType "Eligible"

# Define app registration properties
Write-Host "[INFO] Checking app registration for Custom Attribute Manament..." -ForegroundColor Cyan
$app = Get-MgApplication -Filter "displayName eq '$appDisplayName'" -ErrorAction SilentlyContinue 
if (!$app) {
    write-host "[INFO] Creating app registration for Custom Attribute Manament..." -ForegroundColor Cyan
    $app = New-MgApplication -DisplayName $appDisplayName -SignInAudience "AzureADMyOrg"
    $servicePrincipal = New-MgServicePrincipal -AppId $app.AppId
}


# Output the app registration details
Write-Host "[INFO] $app registration created successfully." -ForegroundColor Green


# Create custom extension properties
Write-Host "[INFO] Creating custom extension properties for phishing-resistant status..." -ForegroundColor Cyan
$enabledAttr = Get-IAMExtensionProperty -Application $app -Name 'phishingResistantEnabled' -DataType 'Boolean'
$lastCheckedAttr = Get-IAMExtensionProperty -Application $app -Name 'phishingResistantLastChecked' -DataType 'DateTime'
$statusAttr = Get-IAMExtensionProperty -Application $app -Name 'phishingResistantStatus' -DataType 'String'


# Clean the application AppId (client ID) by removing hyphens
write-host "[INFO] setting Application Attributes dynamic group..." -ForegroundColor Cyan
$applicationId = $app.AppId -replace '-', ''
$extensionAttribute = "extension_$applicationId`_phishingResistantStatus"
$inactiveMembershipRule = '(user.' + $extensionAttribute + ' -eq "Inactive") and (user.userType -eq "Member") and (user.userPrincipalName -match "admin") and (user.department -match "Cloud Admins")'
$activeMembershipRule = '(user.' + $extensionAttribute + ' -eq "Active") and (user.userType -eq "Member") and (user.userPrincipalName -match "admin") and (user.department -match "Cloud Admins")'



# Retrieve or create the dynamic groups
Write-Host "[INFO] Creating dynamic groups for phishing-resistant status..." -ForegroundColor Cyan
$inactiveGroup = Get-IAMDynamicGroup -DisplayName 'ca-persona-admins-phishingResistantInactiveUsers' -MembershipRule $inactiveMembershipRule -Verbose
$activeGroup = Get-IAMDynamicGroup -DisplayName 'ca-persona-admins-phishingResistantActiveUsers' -MembershipRule $activeMembershipRule -Verbose

# Prompt to select a user if the user principal name is not provided
if (-not $testUserPrincipalName) {
    # Let the user select a test user interactively using Out-ConsoleGridView
    if (!$testUser) {
        $testUser = Get-MgUser -All | Out-ConsoleGridView -OutputMode Single -Title "Select a test user"
    }
    
}
else {
    # If a user principal name is provided, retrieve the corresponding user
    $testUser = Get-MgUser -Filter "userPrincipalName eq '$testUserPrincipalName'" -ErrorAction SilentlyContinue

    # If the specified user is not found, exit the script
    if (-not $testUser) {
        Write-Host "User with UserPrincipalName '$testUserPrincipalName' not found. Exiting..."
        return
    }
}

# Output the selected user's principal name for verification
Write-Output "Test user: $($testUser.UserPrincipalName)"

# Ensure that the PIM role is active for the specified AU
$userAuth = New-EligibeRoleActivationForAU -adminUnit $administrativeUnit -roleName "User Administrator" -UserObjectId $adminUser.Id
$mfaAuth = New-EligibeRoleActivationForAU -adminUnit $administrativeUnit -roleName "Privileged Authentication Administrator" -UserObjectId $adminUser.Id
if ($userAuth -and $mfaAuth) {
    $success = $true
}
if (-not $success) {
    Write-Host "❌ Failed to activate the required roles for the specified AU. Exiting script." -ForegroundColor Red
    return
}
else {
    Update-IAMPhishingResistantStatus -Object $testUser -ObjectType 'User' `
        -PhishingResistantEnabledAttr $enabledAttr `
        -PhishingResistantLastCheckedAttr $lastCheckedAttr `
        -PhishingResistantStatusAttr $statusAttr
}
# Update phishing-resistant status for the selected user


# Update phishing-resistant status
Write-Host "[INFO] Updating phishing-resistant status for the selected user..." -ForegroundColor Cyan
$selectedGroups = Get-MgGroup -All | Out-ConsoleGridView -OutputMode Multiple -Title "Select the admin group"
if ($selectedGroups.Count -gt 0) {
    foreach ($group in $selectedGroups) {
        Update-IAMPhishingResistantStatus -Object $group -ObjectType "Group" -PhishingResistantEnabledAttr $enabledAttr -PhishingResistantLastCheckedAttr $lastCheckedAttr -PhishingResistantStatusAttr $statusAttr
    }
}
else {
    Write-Host "No groups selected. Exiting..."
}

# Create daily checker script
$script = New-IAMhourlyCheckerScript -AppId $app.Id `
    -PhishingResistantEnabledAttr $enabledAttr `
    -PhishingResistantLastCheckedAttr $lastCheckedAttr `
    -PhishingResistantStatusAttr $statusAttr `
    -Groups $selectedGroups

# Step: Create Authentication Strength
$authStrengthParams = @{
    Name = "Phishing-resistant-firsttimeUse"
    Description = "Authentication strength for first-time use with phishing-resistant methods"
    AllowedCombinations = @("fido2", "windowsHelloForBusiness", "x509CertificateMultiFactor", "temporaryAccessPassOneTime")
}
$authStrength = New-AuthenticationStrength @authStrengthParams
Write-Host "Authentication Strength created: $($authStrength.DisplayName)"


$caPolicy1Params = @{
    DisplayName   = "CA109-Admins-BaseProtection-AllApps-AnyPlatform-PhishingResistant"
    State         = "disabled"
    Conditions    = @{
        ClientAppTypes = @("all")
        Applications   = @{ IncludeApplications = @("All") }
        Users          = @{
            IncludeGroups = @("ca-Persona--Admins")
            ExcludeGroups = @(
                "ca-BreakGlassAccounts",
                "ca-Persona--Admins-BaseProtection-Exclusions",
                "ca-Persona--Microsoft365ServiceAccounts",
                "ca-Persona--AzureServiceAccounts",
                "ca-Persona--CorpServiceAccounts",
                "ca-Persona--admins-PhishingResistant-Exclusions"
            )
        }
    }
    GrantControls = @{
        operator               = "AND"
        builtInControls        = @()
        authenticationStrength = @{ id = "00000000-0000-0000-0000-000000000004" }
    }
}
New-ConditionalAccessPoliciesNew -Params $caPolicy1Params

$caPolicy2Params = @{
    DisplayName   = "CA110-Admins-BaseProtection-AllApps-AnyPlatform-TapFirstTimeUse"
    State         = "disabled"
    Conditions    = @{
        ClientAppTypes = @("all")
        Applications   = @{ IncludeApplications = @("All") }
        Users          = @{
            IncludeGroups = @("ca-Persona--Admins")
            ExcludeGroups = @(
                "ca-BreakGlassAccounts",
                "ca-Persona-Admins-BaseProtection-Exclusions",
                "ca-Persona-Microsoft365ServiceAccounts",
                "ca-Persona-AzureServiceAccounts",
                "ca-Persona-CorpServiceAccounts",
                "ca-Persona-admins-PhishingResistant-Inclusions"
            )
        }
    }
    GrantControls = @{
        operator               = "AND"
        builtInControls        = @()
        authenticationStrength = @{ id = $authStrength.Id }
    }
}
New-ConditionalAccessPoliciesNew -Params $caPolicy2Params

