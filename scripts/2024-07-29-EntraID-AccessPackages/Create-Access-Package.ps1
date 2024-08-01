<#
.SYNOPSIS
Selects a group from the list of dynamic groups.

.DESCRIPTION
This function fetches the dynamic groups and allows the user to select a group from the list using a graphical interface. If no group is selected, an exception is thrown.

.PARAMETER None

.INPUTS
None

.OUTPUTS
System.Management.Automation.PSCustomObject

.EXAMPLE
$selectedGroup = Select-Group
# Selects a group from the list of dynamic groups and assigns it to the $selectedGroup variable.

.NOTES
This function requires the `Get-MgGroup` cmdlet from the Microsoft Graph PowerShell module.

.LINK
Get-MgGroup
#>

function Select-Group {
    # Function code here
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
        } else {
            Write-Host "🧙‍♂️ Activating PIM role $roleName for 1 hour..."
            $params = @{
                action = "selfActivate"
                principalId = $currentUserObjectId
                roleDefinitionId = $roleId
                directoryScopeId = "/"
                justification = "Script execution: Activating $roleName role"
                scheduleInfo = @{
                    startDateTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
                    expiration = @{
                        type = "AfterDuration"
                        duration = "PT1H"
                    }
                }
            }
            try {
                New-MgRoleManagementDirectoryRoleAssignmentScheduleRequest -BodyParameter $params
                Write-Host "✨ PIM role $roleName activation requested." -ForegroundColor Green
                $activationPerformed = $true
            } catch {
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
        [Parameter(Mandatory=$true)]
        [string]$RoleName,
        
        [Parameter(Mandatory=$true)]
        [string]$RoleId,
        
        [Parameter(Mandatory=$true)]
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
        CatalogId = $CatalogId
        IsHidden = $false
    }

    Write-Host "✨ Creating new access package: $displayName..."
    $newPackage = New-MgBetaEntitlementManagementAccessPackage -BodyParameter $params
    Write-Host "✅ Access package created successfully for $RoleName" -ForegroundColor Green
    return $newPackage
}

function Add-RoleScopeToAccessPackage {
    param (
        [Parameter(Mandatory=$true)]
        [string]$AccessPackageId,
        
        [Parameter(Mandatory=$true)]
        [string]$CatalogId,
        
        [Parameter(Mandatory=$true)]
        [object]$Role
    )

    Write-Host "🔍 Attempting to add role scope for $($Role.DisplayName) to access package $AccessPackageId" -ForegroundColor Yellow

    try {
        $roleResource = Get-MgEntitlementManagementCatalogResource -AccessPackageCatalogId $CatalogId -Filter "originId eq '$($Role.RoleTemplateId)' and originSystem eq 'DirectoryRole'"
        
        if (-not $roleResource) {
            Write-Host "⚠️ Role resource not found in catalog. Attempting to add it..." -ForegroundColor Yellow
            Add-EntraRoleToCatalog -CatalogId $CatalogId -Role $Role
            Start-Sleep -Seconds 10  # Wait for a bit to ensure the role is added
            $roleResource = Get-MgEntitlementManagementCatalogResource -AccessPackageCatalogId $CatalogId -Filter "originId eq '$($Role.RoleTemplateId)' and originSystem eq 'DirectoryRole'"
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
        BodyParameter = @{
            accessPackageResourceRole = @{
                originId = "Eligible"
                displayName = "Eligible Member"
                originSystem = "DirectoryRole"
                accessPackageResource = @{
                    id = $roleResource.Id
                    resourceType = "Built-in"
                    originId = $Role.RoleTemplateId
                    originSystem = "DirectoryRole"
                }
            }
            accessPackageResourceScope = @{
                originId = $Role.RoleTemplateId
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
            displayName = $CatalogName
            description = "Catalog for Entra Admin roles"
            isExternallyVisible = $false
        }
        $catalog = New-MgEntitlementManagementCatalog -BodyParameter $newCatalog
        Write-Host "✅ Catalog '$CatalogName' created successfully." -ForegroundColor Green
    }
    return $catalog
}

function Add-EntraRoleToCatalog {
    param (
        [Parameter(Mandatory=$true)]
        [string]$CatalogId,
       
        [Parameter(Mandatory=$true)]
        [object]$Role
    )

    Write-Host "🔍 Checking if role $($Role.DisplayName) exists in the catalog..."
    $existingResource = Get-MgEntitlementManagementCatalogResource -AccessPackageCatalogId $CatalogId -Filter "originId eq '$($Role.RoleTemplateId)' and originSystem eq 'DirectoryRole'"

    if ($existingResource) {
        Write-Host "⚠️ Role $($Role.DisplayName) already exists in the catalog. Skipping." -ForegroundColor Yellow
        return
    }

    $params = @{
        catalogId = $CatalogId
        requestType = "AdminAdd"
        accessPackageResource = @{
            displayName = $Role.DisplayName
            description = $Role.Description
            resourceType = "Built-in"
            originId = $Role.RoleTemplateId
            originSystem = "DirectoryRole"
        }
        justification = "Adding Directory Role to Catalog"
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
        [Parameter(Mandatory=$true)]
        [array]$EntraIDUsers
    )
    $approvalMode = Read-Host "🔮 Do you want a 1 or 2 step verification process? (Enter '1' or '2')"
    $firstStageApprovers = @()
    $secondStageApprovers = @()
    
    if ($approvalMode -eq '1' -or $approvalMode -eq '2') {
        $approverType = Read-Host "🔮 Do you want the first stage to be approved by a 'Manager' or 'User(s)'?"
        if ($approverType -eq 'Manager') {
            $firstStageApprovers += @{
                "@odata.type" = "#microsoft.graph.requestorManager"
                managerLevel = 1
            }
            
            # Select multiple backup approvers
            $backupApprovers = $EntraIDUsers | Out-ConsoleGridView -Title "Select backup user(s) for first stage" -OutputMode Multiple
            foreach ($approver in $backupApprovers) {
                $firstStageApprovers += @{
                    "@odata.type" = "#microsoft.graph.singleUser"
                    userId = $approver.Id
                    isBackup = $true
                }
                Write-Host "Added $($approver.DisplayName) as a backup approver."
            }
        } elseif ($approverType -eq 'User(s)') {
            # Select multiple primary approvers
            $primaryApprovers = $EntraIDUsers | Out-ConsoleGridView -Title "Select primary approver(s) for first stage" -OutputMode Multiple
            foreach ($approver in $primaryApprovers) {
                $firstStageApprovers += @{
                    "@odata.type" = "#microsoft.graph.singleUser"
                    userId = $approver.Id
                }
                Write-Host "Added $($approver.DisplayName) as a primary approver."
            }

            # Select multiple backup approvers
            $backupApprovers = $EntraIDUsers | Out-ConsoleGridView -Title "Select backup user(s) for first stage" -OutputMode Multiple
            foreach ($approver in $backupApprovers) {
                $firstStageApprovers += @{
                    "@odata.type" = "#microsoft.graph.singleUser"
                    userId = $approver.Id
                    isBackup = $true
                }
                Write-Host "Added $($approver.DisplayName) as a backup approver."
            }
        } else {
            throw "Invalid approver type selected. Exiting script."
        }
    }

    if ($approvalMode -eq '2') {
        # Second stage
        $secondStageApproverType = Read-Host "🔮 Do you want the second stage to be approved by 'Manager' or 'User(s)'?"
        
        if ($secondStageApproverType -eq 'Manager') {
            $secondStageApprovers += @{
                "@odata.type" = "#microsoft.graph.requestorManager"
                managerLevel = 1
            }
        } elseif ($secondStageApproverType -eq 'User(s)') {
            # Select multiple primary approvers for second stage
            $primaryApprovers = $EntraIDUsers | Out-ConsoleGridView -Title "Select primary approver(s) for second stage" -OutputMode Multiple
            foreach ($approver in $primaryApprovers) {
                $secondStageApprovers += @{
                    "@odata.type" = "#microsoft.graph.singleUser"
                    userId = $approver.Id
                }
                Write-Host "Added $($approver.DisplayName) as a primary approver for second stage."
            }
        } else {
            throw "Invalid approver type selected for second stage. Exiting script."
        }

        # Select multiple backup approvers for second stage
        $backupApprovers = $EntraIDUsers | Out-ConsoleGridView -Title "Select backup user(s) for second stage" -OutputMode Multiple
        foreach ($approver in $backupApprovers) {
            $secondStageApprovers += @{
                "@odata.type" = "#microsoft.graph.singleUser"
                userId = $approver.Id
                isBackup = $true
            }
            Write-Host "Added $($backupApprover.DisplayName) as a backup approver for second stage."
        }
    } elseif ($approvalMode -ne '1') {
        throw "Invalid verification process selected. Exiting script."
    }

    return @{
        ApprovalMode = $approvalMode
        FirstStageApprovers = $firstStageApprovers
        SecondStageApprovers = $secondStageApprovers
    }
}

# get access review settings with improved multiple reviewer selection
function Get-AccessReviewSettings {
    param (
        [Parameter(Mandatory=$true)]
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
                userId = $reviewer.Id
                isBackup = $true
            }
            Write-Host "Added $($reviewer.DisplayName) as a backup reviewer for access review."
        }

        return @{
            isEnabled = $true
            recurrenceType = "quarterly"
            reviewerType = if ($reviewerType -eq 'Yes') { "Manager" } else { "Self" }
            startDateTime = (Get-Date).AddDays(1).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            durationInDays = 25
            reviewers = $reviewers
            isAccessRecommendationEnabled = $true
            isApprovalJustificationRequired = $true
            accessReviewTimeoutBehavior = "keepAccess"
        }
    }
    return @{ isEnabled = $false }
}

# Modified function to select a group
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
# Modified Add-PolicyToAccessPackage function
function Add-PolicyToAccessPackage {
    param (
        [Parameter(Mandatory=$true)]
        [string]$AccessPackageId,
        
        [Parameter(Mandatory=$true)]
        [string]$RoleName,
        
        [Parameter(Mandatory=$true)]
        [string]$GroupId,

        [Parameter(Mandatory=$true)]
        [hashtable]$ApprovalSettings,

        [Parameter(Mandatory=$true)]
        [hashtable]$AccessReviewSettings
    )

    Write-Host "🔍 Processing policy for access package..." -ForegroundColor Yellow

    $policyDisplayName = "Policy for assigning $RoleName"

    # Check if policy already exists
    $existingPolicies = Get-MgBetaEntitlementManagementAccessPackageAssignmentPolicy -All
    $existingPolicy = $existingPolicies | Where-Object { $_.AccessPackageId -eq $AccessPackageId -and $_.DisplayName -eq $policyDisplayName }

    $policyParams = @{
        accessPackageId = $AccessPackageId
        displayName = $policyDisplayName
        description = "Policy for requesting the following EntraID role: $RoleName"
        canExtend = $false
        durationInDays = 365
        requestorSettings = @{
            scopeType = "SpecificDirectorySubjects"
            acceptRequests = $true
            allowedRequestors = @(
                @{
                    "@odata.type" = "#microsoft.graph.groupMembers"
                    groupId = $GroupId
                }
            )
        }
        requestApprovalSettings = @{
            isApprovalRequired = $true
            isApprovalRequiredForExtension = $false
            isRequestorJustificationRequired = $true
            approvalMode = "Serial"
            approvalStages = @(
                @{
                    approvalStageTimeOutInDays = 14
                    isApproverJustificationRequired = $true
                    isEscalationEnabled = $false
                    primaryApprovers = $ApprovalSettings.FirstStageApprovers
                }
            )
        }
        accessReviewSettings = $AccessReviewSettings
        questions = @(
            @{
                isRequired = $true
                text = @{
                    defaultText = "Why do you require this role?"
                    localizedTexts = @()
                }
                "@odata.type" = "#microsoft.graph.accessPackageTextInputQuestion"
                isSingleLineQuestion = $false
            }
        )
    }

    if ($ApprovalSettings.ApprovalMode -eq '2') {
        $policyParams.requestApprovalSettings.approvalStages += @{
            approvalStageTimeOutInDays = 14
            isApproverJustificationRequired = $true
            isEscalationEnabled = $false
            primaryApprovers = $ApprovalSettings.SecondStageApprovers
        }
    }

    try {
        if ($existingPolicy) {
            Write-Host "⚠️ Policy already exists. Updating existing policy." -ForegroundColor Yellow
            $result = Set-MgBetaEntitlementManagementAccessPackageAssignmentPolicy -AccessPackageAssignmentPolicyId $existingPolicy.Id -BodyParameter $policyParams
            Write-Host "✅ Successfully updated policy for $RoleName." -ForegroundColor Green
        } else {
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


# Main script section

Write-Host "🔮 Starting the magical process..."

# Import required modules
Write-Host "🔮 Summoning PowerShell modules..."
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Beta.Identity.Governance
Import-Module Microsoft.Graph.Identity.DirectoryManagement

# Authenticate to Microsoft Graph
Write-Host "🧙‍♂️ Authenticating to Microsoft Graph..."
Connect-MgGraph -Scopes "Directory.Read.All", "EntitlementManagement.ReadWrite.All"



# Ensure required PIM roles are active
if (Ensure-PimRolesActive -RequiredRoles @("Global Administrator", "Identity Governance Administrator")) {
    Write-Host "All required roles are active or activation has been requested." -ForegroundColor Green
} else {
    Write-Host "Failed to ensure all required roles are active. Please check the output above for details." -ForegroundColor Red
}


$defaultCatalogName = "Entra ID Admin Roles"
$catalogName = Read-Host "🔮 Enter the name of the catalog to create or update access packages for: [$defaultCatalogName]"
if ([string]::IsNullOrEmpty($catalogName)) {
    $catalogName = $defaultCatalogName
}
$catalog = Get-OrCreateCatalog -CatalogName $catalogName


# Get all Directory roles
Write-Host "📜 Gathering all Directory roles..."
$directoryRoles = Get-MgDirectoryRole -All | Where-Object { $null -ne $_.RoleTemplateId }

# Select the cloud admin group
$cloudAdminGroup = Select-Group
Write-Host "✅ Selected Cloud Admin Group: $($cloudAdminGroup.DisplayName)"
# Get all enabled Entra ID users

Write-Host "👥 Fetching all enabled Entra ID users..."
$entraIDUsers = Get-MgUser -Filter "AccountEnabled eq true" -All | Select-Object DisplayName, Id


# Get approval settings once
$approvalSettings = Get-ApprovalSettings -EntraIDUsers $entraIDUsers

# Get access review settings once
$accessReviewSettings = Get-AccessReviewSettings -EntraIDUsers $entraIDUsers

# Add each role to the catalog
foreach ($role in $directoryRoles) {
    Write-Host "✨ Adding role $($role.DisplayName) to catalog..."
    Add-EntraRoleToCatalog -CatalogId $catalog.Id -Role $role
}

# Add each role to the catalog and create access packages
foreach ($role in $directoryRoles) {
    $roleName = $role.DisplayName
    Write-Host "🔮 Processing access package for role: $roleName"

    try {
        Write-Host "✨ Adding role $($role.DisplayName) to catalog..."
        Add-EntraRoleToCatalog -CatalogId $catalog.Id -Role $role

        $accessPackage = Get-OrCreateAccessPackage -RoleName $roleName -CatalogId $catalog.Id -RoleId $role.RoleTemplateId
        
        # Add role scope to the access package
        Add-RoleScopeToAccessPackage -AccessPackageId $accessPackage.Id -Role $role -CatalogId $catalog.Id

        # Add policy to the access package
        Add-PolicyToAccessPackage -AccessPackageId $accessPackage.Id -RoleName $roleName -GroupId $cloudAdminGroup.Id -ApprovalSettings $approvalSettings -AccessReviewSettings $accessReviewSettings
    }
    catch {
        Write-Host "❌ Failed to process access package for "$roleName": $_" -ForegroundColor Red
    }
}

Write-Host "🏁 Process completed. Access packages have been created or updated for all Directory roles in the '$catalogName' catalog."

# Disconnect from Microsoft Graph
Write-Host "🔌 Disconnecting from Microsoft Graph..."
Disconnect-MgGraph
