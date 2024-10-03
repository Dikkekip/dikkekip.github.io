<#
.SYNOPSIS
Creates or updates access packages for Entra ID admin roles with a touch of magic.

.DESCRIPTION
This script is your magical wand for managing Entra ID admin roles through access packages. 
It creates a catalog, adds Entra ID roles to it, and sets up access packages with custom 
approval and review settings. It's like organizing a grand wizard's spellbook, but for 
Entra ID permissions!

.PARAMETER None
This script doesn't take any parameters. It's as user-friendly as a friendly dragon!

.EXAMPLE
.\Create-EntraIDAccessPackages.ps1
# Run the script and follow the magical prompts to create your access packages.

.NOTES
- Requires the following PowerShell modules:
  * Microsoft.Graph.Authentication
  * Microsoft.Graph.Beta.Identity.Governance
  * Microsoft.Graph.Identity.DirectoryManagement
- You need to be a Global Administrator or Identity Governance Administrator to run this script.
- The Global Administrator role is excluded from the access packages for security reasons.
- Prepare for a whimsical journey through Entra ID management!

.LINK
https://learn.microsoft.com/en-us/entra/id-governance/entitlement-management-access-package-first
#>

# Function to select a group

# Define log file path
$logDirectory = "C:\Logs"
$logFile = Join-Path -Path $logDirectory -ChildPath "EntraIDAccessPackageCreation.log"

# Function to log messages
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] $Message"
    Add-Content -Path $logFile -Value $logEntry
}

# Ensure the log directory exists
if (-not (Test-Path -Path $logDirectory)) {
    try {
        New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
        Write-Log "Created log directory at $logDirectory."
    }
    catch {
        Write-Host "❌ Failed to create log directory at $logDirectory. Error: $_" -ForegroundColor Red
        throw "Failed to create log directory."
    }
}

# Function to ensure required modules are installed and imported
function Ensure-Modules {
    $requiredModules = @(
        "Microsoft.Graph.Authentication",
        "Microsoft.Graph.Identity.Governance",
        "Microsoft.Graph.Identity.DirectoryManagement",
        "Microsoft.PowerShell.ConsoleGuiTools"
    )

    foreach ($module in $requiredModules) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            Write-Host "📦 Installing missing module: $module" -ForegroundColor Yellow
            try {
                Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser
                Write-Log "Installed module: $module"
            }
            catch {
                Write-Host "❌ Failed to install module: $module. Error: $_" -ForegroundColor Red
                Write-Log "Failed to install module: $module. Error: $_"
                throw "Module installation failed."
            }
        }
        try {
            Import-Module $module -ErrorAction Stop
            Write-Log "Imported module: $module"
        }
        catch {
            Write-Host "❌ Failed to import module: $module. Error: $_" -ForegroundColor Red
            Write-Log "Failed to import module: $module. Error: $_"
            throw "Module import failed."
        }
    }
}

function Select-Group {
    Write-Host "🔍 Fetching dynamic groups for selection..."
    $groups = Get-MgGroup -Filter "groupTypes/any(g:g eq 'DynamicMembership')" | Select-Object DisplayName, Id
    Write-Host "🔮 Select the Cloud Admin Group..."
    $selectedGroup = $groups | Out-ConsoleGridView -Title "Select the Cloud Admin Group" -OutputMode Single
    if ($null -eq $selectedGroup) {
        throw "No group selected. Exiting script."
    }
    return $selectedGroup
}



# Function to get the current user's Object ID
function Get-CurrentUserObjectId {
    $currentUser = Get-MgContext
    $user = Get-MgUser -UserId $currentUser.Account
    return $user.Id
}

# Function to check and activate PIM roles
function Ensure-PimRolesActive {
    param (
        [string[]]$RequiredRoles = @(
            "Global Administrator",
            "Identity Governance Administrator"
        )
    )

    $currentUserObjectId = Get-CurrentUserObjectId
    Write-Host "Current user Object ID: $currentUserObjectId"

    $activationPerformed = $false

    foreach ($roleName in $RequiredRoles) {
        # Get the role definition
        $roleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -Filter "displayName eq '$roleName'"
        if ($null -eq $roleDefinition) {
            Write-Host "❌ Role definition for $roleName not found. Exiting script." -ForegroundColor Red
            return $false
        }

        $roleId = $roleDefinition.Id

        # Check if the role is already active
        $activeAssignments = Get-MgRoleManagementDirectoryRoleAssignmentScheduleInstance -Filter "roleDefinitionId eq '$roleId' and principalId eq '$currentUserObjectId'"
        if ($activeAssignments) {
            Write-Host "✅ PIM role $roleName is already active." -ForegroundColor Green
        }
        else {
            Write-Host "🧙‍♂️ Activating PIM role $roleName for 1 hour..."
            $params = @{
                action           = "selfActivate"
                principalId      = $currentUserObjectId
                roleDefinitionId = $roleId
                directoryScopeId = "/"
                justification    = "Script execution: Activating $roleName role"
                scheduleInfo     = @{
                    startDateTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
                    expiration    = @{
                        type     = "AfterDuration"
                        duration = "PT1H"
                    }
                }
            }
            try {
                New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $params
                Write-Host "✨ PIM role $roleName activation requested." -ForegroundColor Green
                $activationPerformed = $true
            }
            catch {
                Write-Host "❌ Failed to activate PIM role $roleName. Error: $_" -ForegroundColor Red
                return $false
            }
        }
    }

    if ($activationPerformed) {
        Write-Host "🔄 Reconnecting to Microsoft Graph to apply new permissions..." -ForegroundColor Yellow
        Disconnect-MgGraph | Out-Null
        Connect-MgGraph -Scopes "RoleManagement.ReadWrite.Directory", "Directory.Read.All"
        Write-Host "✅ Reconnected to Microsoft Graph. New permissions are now active." -ForegroundColor Green
    }

    return $true
}

function Get-OrCreateAccessPackage {
    param (
        [Parameter(Mandatory = $true)]
        [string]$RoleName,
        
        [Parameter(Mandatory = $true)]
        [string]$RoleId,
        
        [Parameter(Mandatory = $true)]
        [string]$CatalogId
    )

    $displayName = "Access Package - $RoleName"
    
    # Check if the access package already exists
    Write-Host "🔍 Searching for existing access package: $displayName..."
    $existingPackage = Get-MgBetaEntitlementManagementAccessPackage -Filter "displayName eq '$displayName'" -All | Where-Object { $_.CatalogId -eq $CatalogId }
    
    if ($existingPackage) {
        Write-Host "⚠️ Access package for $RoleName already exists. Skipping creation." -ForegroundColor Yellow
        return $existingPackage
    }

    $params = @{
        DisplayName = $displayName
        Description = "Access package for $RoleName role"
        CatalogId   = $CatalogId
        IsHidden    = $false
    }

    Write-Host "✨ Creating new access package: $displayName..."
    $newPackage = New-MgBetaEntitlementManagementAccessPackage -BodyParameter $params
    Write-Host "✅ Access package created successfully for $RoleName" -ForegroundColor Green
    return $newPackage
}

function Add-RoleScopeToAccessPackage {
    param (
        [Parameter(Mandatory = $true)]
        [string]$AccessPackageId,
        
        [Parameter(Mandatory = $true)]
        [string]$CatalogId,
        
        [Parameter(Mandatory = $true)]
        [object]$Role
    )

    Write-Host "🔍 Attempting to add role scope for $($Role.DisplayName) to access package $AccessPackageId" -ForegroundColor Yellow

    try {
        $roleResource = Get-MgEntitlementManagementCatalogResource -AccessPackageCatalogId $CatalogId -Filter "originId eq '$($Role.TemplateId)' and originSystem eq 'DirectoryRole'"
        
        if (-not $roleResource) {
            Write-Host "⚠️ Role resource not found in catalog. Attempting to add it..." -ForegroundColor Yellow
            Add-EntraRoleToCatalog -CatalogId $CatalogId -Role $Role
            Start-Sleep -Seconds 10  # Wait for a bit to ensure the role is added
            $roleResource = Get-MgEntitlementManagementCatalogResource -AccessPackageCatalogId $CatalogId -Filter "originId eq '$($Role.TemplateId)' and originSystem eq 'DirectoryRole'"
        }

        if (-not $roleResource) {
            throw "❌ Failed to find or add role resource to catalog"
        }

        Write-Host "✅ Role resource found in catalog: $($roleResource.DisplayName)" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to retrieve or add role resource: $_" -ForegroundColor Red
        return
    }

    $params = @{
        AccessPackageId = $AccessPackageId
        BodyParameter   = @{
            accessPackageResourceRole  = @{
                originId              = "Eligible"
                displayName           = "Eligible Member"
                originSystem          = "DirectoryRole"
                accessPackageResource = @{
                    id           = $roleResource.Id
                    resourceType = "Built-in"
                    originId     = $Role.TemplateId
                    originSystem = "DirectoryRole"
                }
            }
            accessPackageResourceScope = @{
                originId     = $Role.TemplateId
                originSystem = "DirectoryRole"
            }
        }
    }

    try {
        Write-Host "✨ Adding role scope to access package..."
        $result = New-MgBetaEntitlementManagementAccessPackageResourceRoleScope @params -ErrorAction Stop
        Write-Host "✅ Successfully added role scope for $($Role.DisplayName) to access package." -ForegroundColor Green
        return $result
    }
    catch {
        Write-Host "❌ Failed to add role scope for $($Role.DisplayName) to access package: $_" -ForegroundColor Red
        Write-Host "Request details:" -ForegroundColor Yellow
        $params | ConvertTo-Json -Depth 10 | Write-Host
    }
}

function Get-OrCreateCatalog {
    param (
        [string]$CatalogName
    )

    Write-Host "🔍 Searching for catalog: $CatalogName..."
    $catalog = Get-MgEntitlementManagementCatalog -Filter "displayName eq '$CatalogName'" -All
    if ($null -eq $catalog) {
        Write-Host "⚠️ Catalog '$CatalogName' not found. Creating new catalog..." -ForegroundColor Yellow
        $newCatalog = @{
            displayName         = $CatalogName
            description         = "Catalog for Entra Admin roles"
            isExternallyVisible = $false
        }
        $catalog = New-MgEntitlementManagementCatalog -BodyParameter $newCatalog
        Write-Host "✅ Catalog '$CatalogName' created successfully." -ForegroundColor Green
    }
    return $catalog
}

function Add-EntraRoleToCatalog {
    param (
        [Parameter(Mandatory = $true)]
        [string]$CatalogId,
       
        [Parameter(Mandatory = $true)]
        [object]$Role
    )

    Write-Host "🔍 Checking if role $($Role.DisplayName) exists in the catalog..."
    $existingResource = Get-MgEntitlementManagementCatalogResource -AccessPackageCatalogId $CatalogId -Filter "originId eq '$($Role.TemplateId)' and originSystem eq 'DirectoryRole'"

    if ($existingResource) {
        Write-Host "⚠️ Role $($Role.DisplayName) already exists in the catalog. Skipping." -ForegroundColor Yellow
        return
    }

    $params = @{
        catalogId             = $CatalogId
        requestType           = "AdminAdd"
        accessPackageResource = @{
            displayName  = $Role.DisplayName
            description  = $Role.Description
            resourceType = "Built-in"
            originId     = $Role.TemplateId
            originSystem = "DirectoryRole"
        }
        justification         = "Adding Directory Role to Catalog"
    }

    try {
        Write-Host "✨ Adding role $($Role.DisplayName) to the catalog..."
        $null = New-MgBetaEntitlementManagementAccessPackageResourceRequest -BodyParameter $params
        Write-Host "✅ Successfully added $($Role.DisplayName) to the catalog." -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to add $($Role.DisplayName) to the catalog: $_" -ForegroundColor Red
    }
}


function Get-ApprovalSettings {
    param (
        [Parameter(Mandatory = $true)]
        [array]$EntraIDUsers
    )
    $approvalMode = Read-Host "🔮 Do you want a 1 or 2 step verification process? (Enter '1' or '2')"
    $firstStageApprovers = @()
    $secondStageApprovers = @()
    
    if ($approvalMode -eq '1' -or $approvalMode -eq '2') {
        $approverType = Read-Host "🔮 Choose the approver type for the first stage:
1. Manager
2. Specific User(s)
Enter the number of your choice (1 or 2)"

        switch ($approverType) {
            "1" {
                # Manager
                $firstStageApprovers += @{
                    "@odata.type" = "#microsoft.graph.requestorManager"
                    managerLevel  = 1
                }
                
                # Select multiple backup approvers
                $backupApprovers = $EntraIDUsers | Out-ConsoleGridView -Title "Select backup user(s) for first stage" -OutputMode Multiple
                foreach ($approver in $backupApprovers) {
                    $firstStageApprovers += @{
                        "@odata.type" = "#microsoft.graph.singleUser"
                        userId        = $approver.Id
                        isBackup      = $true
                    }
                    Write-Host "Added $($approver.DisplayName) as a backup approver."
                }
            }
            "2" {
                # Specific User(s)
                # Select multiple primary approvers
                $primaryApprovers = $EntraIDUsers | Out-ConsoleGridView -Title "Select primary approver(s) for first stage" -OutputMode Multiple
                foreach ($approver in $primaryApprovers) {
                    $firstStageApprovers += @{
                        "@odata.type" = "#microsoft.graph.singleUser"
                        userId        = $approver.Id
                    }
                    Write-Host "Added $($approver.DisplayName) as a primary approver."
                }

                # Select multiple backup approvers
                $backupApprovers = $EntraIDUsers | Out-ConsoleGridView -Title "Select backup user(s) for first stage" -OutputMode Multiple
                foreach ($approver in $backupApprovers) {
                    $firstStageApprovers += @{
                        "@odata.type" = "#microsoft.graph.singleUser"
                        userId        = $approver.Id
                        isBackup      = $true
                    }
                    Write-Host "Added $($approver.DisplayName) as a backup approver."
                }
            }
            default {
                throw "Invalid approver type selected. Exiting script."
            }
        }
    }

    if ($approvalMode -eq '2') {
        # Second stage
        $secondStageApproverType = Read-Host "🔮 Choose the approver type for the second stage:
1. Manager
2. Specific User(s)
Enter the number of your choice (1 or 2)"
        
        switch ($secondStageApproverType) {
            "1" {
                # Manager
                $secondStageApprovers += @{
                    "@odata.type" = "#microsoft.graph.requestorManager"
                    managerLevel  = 1
                }
            }
            "2" {
                # Specific User(s)
                # Select multiple primary approvers for second stage
                $primaryApprovers = $EntraIDUsers | Out-ConsoleGridView -Title "Select primary approver(s) for second stage" -OutputMode Multiple
                foreach ($approver in $primaryApprovers) {
                    $secondStageApprovers += @{
                        "@odata.type" = "#microsoft.graph.singleUser"
                        userId        = $approver.Id
                    }
                    Write-Host "Added $($approver.DisplayName) as a primary approver for second stage."
                }
            }
            default {
                throw "Invalid approver type selected for second stage. Exiting script."
            }
        }

        # Select multiple backup approvers for second stage
        $backupApprovers = $EntraIDUsers | Out-ConsoleGridView -Title "Select backup user(s) for second stage" -OutputMode Multiple
        foreach ($approver in $backupApprovers) {
            $secondStageApprovers += @{
                "@odata.type" = "#microsoft.graph.singleUser"
                userId        = $approver.Id
                isBackup      = $true
            }
            Write-Host "Added $($approver.DisplayName) as a backup approver for second stage."
        }
    }
    elseif ($approvalMode -ne '1') {
        throw "Invalid verification process selected. Exiting script."
    }

    return @{
        ApprovalMode         = $approvalMode
        FirstStageApprovers  = $firstStageApprovers
        SecondStageApprovers = $secondStageApprovers
    }
}

# get access review settings with improved multiple reviewer selection
function Get-AccessReviewSettings {
    param (
        [Parameter(Mandatory = $true)]
        [array]$EntraIDUsers
    )
    $enableAccessReview = Read-Host "🔮 Do you want to enable access reviews? (Enter 'Yes' or 'No')"
    if ($enableAccessReview -eq 'Yes') {
        $reviewerType = Read-Host "🔮 Should the manager be the reviewer? (Enter 'Yes' or 'No')"
        
        $backupReviewers = $EntraIDUsers | Out-ConsoleGridView -Title "Select backup reviewer(s) for access review" -OutputMode Multiple

        $reviewers = @()
        foreach ($reviewer in $backupReviewers) {
            $reviewers += @{
                "@odata.type" = "#microsoft.graph.singleUser"
                userId        = $reviewer.Id
                isBackup      = $true
            }
            Write-Host "Added $($reviewer.DisplayName) as a backup reviewer for access review."
        }

        return @{
            isEnabled                       = $true
            recurrenceType                  = "quarterly"
            reviewerType                    = if ($reviewerType -eq 'Yes') { "Manager" } else { "Self" }
            startDateTime                   = (Get-Date).AddDays(1).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            durationInDays                  = 25
            reviewers                       = $reviewers
            isAccessRecommendationEnabled   = $true
            isApprovalJustificationRequired = $true
            accessReviewTimeoutBehavior     = "keepAccess"
        }
    }
    return @{ isEnabled = $false }
}


function Add-PolicyToAccessPackage {
    param (
        [Parameter(Mandatory = $true)]
        [string]$AccessPackageId,
        
        [Parameter(Mandatory = $true)]
        [string]$RoleName,
        
        [Parameter(Mandatory = $true)]
        [string]$GroupId,

        [Parameter(Mandatory = $true)]
        [hashtable]$ApprovalSettings,

        [Parameter(Mandatory = $true)]
        [hashtable]$AccessReviewSettings
    )

    Write-Host "🔍 Processing policy for access package..." -ForegroundColor Yellow

    $policyDisplayName = "Policy for assigning $RoleName"

    # Check if policy already exists
    $existingPolicies = Get-MgBetaEntitlementManagementAccessPackageAssignmentPolicy -All
    $existingPolicy = $existingPolicies | Where-Object { $_.AccessPackageId -eq $AccessPackageId -and $_.DisplayName -eq $policyDisplayName }

    $policyParams = @{
        accessPackageId         = $AccessPackageId
        displayName             = $policyDisplayName
        description             = "Policy for requesting the following EntraID role: $RoleName"
        canExtend               = $false
        durationInDays          = 365
        requestorSettings       = @{
            scopeType         = "SpecificDirectorySubjects"
            acceptRequests    = $true
            allowedRequestors = @(
                @{
                    "@odata.type" = "#microsoft.graph.groupMembers"
                    groupId       = $GroupId
                }
            )
        }
        requestApprovalSettings = @{
            isApprovalRequired               = $true
            isApprovalRequiredForExtension   = $false
            isRequestorJustificationRequired = $true
            approvalMode                     = "Serial"
            approvalStages                   = @(
                @{
                    approvalStageTimeOutInDays      = 14
                    isApproverJustificationRequired = $true
                    isEscalationEnabled             = $false
                    primaryApprovers                = $ApprovalSettings.FirstStageApprovers
                }
            )
        }
        accessReviewSettings    = $AccessReviewSettings
        questions               = @(
            @{
                isRequired           = $true
                text                 = @{
                    defaultText    = "Why do you require this role?"
                    localizedTexts = @()
                }
                "@odata.type"        = "#microsoft.graph.accessPackageTextInputQuestion"
                isSingleLineQuestion = $false
            }
        )
    }

    if ($ApprovalSettings.ApprovalMode -eq '2') {
        $policyParams.requestApprovalSettings.approvalStages += @{
            approvalStageTimeOutInDays      = 14
            isApproverJustificationRequired = $true
            isEscalationEnabled             = $false
            primaryApprovers                = $ApprovalSettings.SecondStageApprovers
        }
    }

    try {
        if ($existingPolicy) {
            Write-Host "⚠️ Policy already exists. Updating existing policy." -ForegroundColor Yellow
            $result = Set-MgBetaEntitlementManagementAccessPackageAssignmentPolicy -AccessPackageAssignmentPolicyId $existingPolicy.Id -BodyParameter $policyParams
            Write-Host "✅ Successfully updated policy for $RoleName." -ForegroundColor Green
        }
        else {
            Write-Host "✨ Creating new policy..." -ForegroundColor Yellow
            $result = New-MgBetaEntitlementManagementAccessPackageAssignmentPolicy -BodyParameter $policyParams
            Write-Host "✅ Successfully created new policy for $RoleName." -ForegroundColor Green
        }
        return $result
    }
    catch {
        Write-Host "❌ Failed to create or update policy: $_" -ForegroundColor Red
        Write-Host "Policy details:" -ForegroundColor Yellow
        $policyParams | ConvertTo-Json -Depth 10 | Write-Host
    }
}

# Function to retrieve all PIM role definitions
function Get-AllPimRoleDefinitions {
    Write-Host "🔍 Fetching all PIM role definitions..." -ForegroundColor Cyan
    Write-Log "Fetching all PIM role definitions."
    try {
        $allRoles = Get-MgRoleManagementDirectoryRoleDefinition -All
        if (-not $allRoles) {
            Write-Host "❌ No role definitions found." -ForegroundColor Red
            Write-Log "No role definitions found."
            return @()
        }

        # Filter roles client-side
        $pimRoleDefinitions = $allRoles | Where-Object {
            $_.DisplayName -notin @("Global Administrator", "Company Administrator") -and
            $_.IsBuiltIn -eq $true -and
            $_.RolePermissions -ne $null
        }

        if (-not $pimRoleDefinitions) {
            Write-Host "❌ No PIM role definitions found after filtering." -ForegroundColor Red
            Write-Log "No PIM role definitions found after filtering."
            return @()
        }
        Write-Host "🎭 Found $($pimRoleDefinitions.Count) PIM role definitions." -ForegroundColor Green
        Write-Log "Found $($pimRoleDefinitions.Count) PIM role definitions."
        return $pimRoleDefinitions
    }
    catch {
        Write-Host "❌ Error fetching PIM role definitions: $_" -ForegroundColor Red
        Write-Log "Error fetching PIM role definitions: $_"
        return @()
    }
}

# Function to select multiple roles using Out-ConsoleGridView
function Select-Roles {
    param (
        [array]$Roles
    )
    Write-Host "🔮 Select the roles you want to create access packages for..." -ForegroundColor Yellow
    Write-Log "Prompting user to select roles."
    $selectedRoles = $Roles | Select-Object DisplayName, Id, TemplateId | Out-ConsoleGridView -Title "Select PIM Roles" -OutputMode Multiple
    if (-not $selectedRoles) {
        Write-Host "🚫 No roles selected. Exiting script." -ForegroundColor Red
        Write-Log "No roles selected by user."
        throw "No roles selected. Exiting script."
    }
    Write-Log "$($selectedRoles.DisplayName -join ', ') roles selected by user."
    return $selectedRoles
}

# Main script section

Write-Host "🧙‍♂️✨ Welcome to the Enhanced Entra ID Access Packages Creation Script! ✨🧙‍♂️" -ForegroundColor Magenta
Write-Log "Script started."

# Ensure required modules are installed and imported
Ensure-Modules

# Authenticate to Microsoft Graph
Write-Host "🔮 Connecting to Microsoft Graph..." -ForegroundColor Cyan
Write-Log "Connecting to Microsoft Graph."

Write-Host "🧙‍♂️✨ Welcome to the Magical World of Entra ID Access Packages! ✨🧙‍♂️" -ForegroundColor Magenta

# Authenticate to Microsoft Graph
Write-Host "🔮 Channeling the mystical energies of Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "Directory.Read.All", "EntitlementManagement.ReadWrite.All"

# Ensure required PIM roles are active
Write-Host "🏰 Unlocking the gates to the admin kingdom..." -ForegroundColor Yellow
if (Ensure-PimRolesActive -RequiredRoles @("Global Administrator", "Identity Governance Administrator")) {
    Write-Host "🗝️ The gates are open! You now wield the power of the admins!" -ForegroundColor Green
}
else {
    Write-Host "🚫 Alas! The magical keys were out of reach. Our quest ends here." -ForegroundColor Red
    exit
}

$defaultCatalogName = "Entra ID Admin Roles"
$catalogName = Read-Host "🏷️ What shall we name our grand catalog of roles? [$defaultCatalogName]"
if ([string]::IsNullOrEmpty($catalogName)) {
    $catalogName = $defaultCatalogName
}
$catalog = Get-OrCreateCatalog -CatalogName $catalogName

# Get all Directory roles, excluding Global Administrator
Write-Host "📜 Unrolling the ancient scroll of Directory roles..." -ForegroundColor Cyan
# Get and select roles
$directoryRoles = Get-AllPimRoleDefinitions
if ($directoryRoles.Count -eq 0) {
    Write-Host "🚫 No Directory role definitions retrieved. Exiting script." -ForegroundColor Red
    Write-Log "No Directory role definitions retrieved."
    Disconnect-MgGraph
    exit
}
$selectedRoles = Select-Roles -Roles $directoryRoles
Write-Log "Selected roles: $($selectedRoles.DisplayName -join ', ')"

# Select the cloud admin group
Write-Host "☁️ Now, let's find the keepers of the cloud..." -ForegroundColor Yellow
$cloudAdminGroup = Select-Group
Write-Host "👑 The chosen ones: $($cloudAdminGroup.DisplayName)" -ForegroundColor Green

# Get all enabled Entra ID users
Write-Host "🧑‍🤝‍🧑 Summoning all the active users in the realm..." -ForegroundColor Cyan
$entraIDUsers = Get-MgUser -Filter "AccountEnabled eq true" -All | Select-Object DisplayName, Id
Write-Host "🎉 $($entraIDUsers.Count) brave souls answered the call!" -ForegroundColor Green

# Get approval settings once
Write-Host "⚖️ Time to set the rules of engagement..." -ForegroundColor Yellow
$approvalSettings = Get-ApprovalSettings -EntraIDUsers $entraIDUsers

# Get access review settings once
Write-Host "🔍 And now, for the grand inspection ritual..." -ForegroundColor Yellow
$accessReviewSettings = Get-AccessReviewSettings -EntraIDUsers $entraIDUsers

# Add each role to the catalog and create access packages
Write-Host "🎨 Painting our masterpiece of access management..." -ForegroundColor Magenta
foreach ($role in $selectedRoles ) {
    $roleName = $role.DisplayName
    Write-Host "🎭 Weaving the tale of $roleName..." -ForegroundColor Cyan

    try {
        Write-Host "✨ Adding a sprinkle of $roleName to our magical catalog..."
        Add-EntraRoleToCatalog -CatalogId $catalog.Id -Role $role

        $accessPackage = Get-OrCreateAccessPackage -RoleName $roleName -CatalogId $catalog.Id -RoleId $role.TemplateId
        
        Write-Host "🔓 Unlocking the secrets of $roleName..."
        Add-RoleScopeToAccessPackage -AccessPackageId $accessPackage.Id -Role $role -CatalogId $catalog.Id

        Write-Host "📜 Inscribing the ancient laws for $roleName..."
        Add-PolicyToAccessPackage -AccessPackageId $accessPackage.Id -RoleName $roleName -GroupId $cloudAdminGroup.Id -ApprovalSettings $approvalSettings -AccessReviewSettings $accessReviewSettings
    }
    catch {
        Write-Host "💥 Alas! The spell for $roleName fizzled: $_" -ForegroundColor Red
    }
}

Write-Host "🎊 Huzzah! Our grand opus of access packages is complete! 🎊" -ForegroundColor Green
Write-Host "The tomes of '$catalogName' now hold the secrets to all Directory roles." -ForegroundColor Cyan

# Disconnect from Microsoft Graph
Write-Host "👋 Bidding farewell to the mystical realms of Microsoft Graph..." -ForegroundColor Yellow
Disconnect-MgGraph

Write-Host "🌟 Your journey through the Entra ID wonderland is complete! May your access packages bring order to the chaos! 🌟" -ForegroundColor Magenta