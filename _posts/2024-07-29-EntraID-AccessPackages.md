---
layout: post
title: "🏰 Automating Access Package Creation for Entra ID roles with PowerShell"
date: 2024-08-01 07:40:59 +0100
description: "Discover the magic of automating Entra ID roles with PowerShell and GraphAPI in Azure."
categories: [Azure, PowerShell, Cloud Computing, DevOps, Entra ID, GraphAPI]
tags:
  [
    Azure PIM,
    PowerShell Scripting,
    GraphAPI,
    Cloud Security,
    Access Management,
    Azure Automation,
    IT Security,
    Cloud Administration,
    Microsoft Azure,
    DevOps Practices,
  ]
image:
  path: /assets/img/myaccess.jpeg
  src: /assets/img/myaccess.jpeg
---
# 🏰 Automating Access Package Creation for Entra ID roles with PowerShell

Greetings, fellow wizards of the tech realm! 🧙‍♂️ Today, we embark on a mystical journey into the enchanted forest of PowerShell scripting and Microsoft Graph. Our quest? To automate the creation and management of Access Packages for Entra ID roles. So grab your wands (or keyboards) and let's dive in!

## 🎭 The Quest Begins: Understanding Our Mission

In the ever-evolving landscape of cloud security, managing access to Entra ID (formerly Azure AD) admin roles efficiently is crucial. Microsoft has recently empowered us with the ability to assign Entra ID roles through Access Packages in Identity Governance. This new feature allows for more granular control and easier management of administrative access.

Our mission today is to create a set of Access Packages designed to assign Entra ID Admin roles automatically. By automating this process, we'll:

1. Save valuable time for IT administrators
2. Reduce human error in role assignments
3. Ensure access reviews on critical admin roles
4. Improve security by standardizing the approval process for admin roles

<!-- markdownlint-capture -->
<!-- markdownlint-disable -->
> **Note**: The script had a small bug so I updated the full version of the script. The script is now fully functional and ready for use. 03-10-2024
{: .prompt-info }
<!-- markdownlint-restore -->

You can find the script here on GitHub:
[Create-Access-Package - Github](https://github.com/Dikkekip/dikkekip.github.io/blob/main/scripts/2024-07-29-EntraID-AccessPackages/Create-Access-Package.ps1){:target="_blank"}
[Create-Access-Package - RAW](https://raw.githubusercontent.com/Dikkekip/dikkekip.github.io/main/scripts/2024-07-29-EntraID-AccessPackages/Create-Access-Package.ps1){:target="_blank"}


## 📚 Gathering Our Magical Artifacts

Before we begin our incantations, we must gather the essential magical artifacts — our PowerShell modules. These modules are the conduits through which we'll channel the power of Microsoft Graph to bend Entra ID to our will.

```powershell
# Import required modules
Write-Host "🔮 Summoning PowerShell modules..."
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Beta.Identity.Governance
Import-Module Microsoft.Graph.Identity.DirectoryManagement
Import-Module Microsoft.Graph.Users
Import-Module Microsoft.Graph.Groups

# Authenticate to Microsoft Graph
Write-Host "🧙‍♂️ Authenticating to Microsoft Graph..."
Connect-MgGraph -Scopes "Directory.Read.All", "EntitlementManagement.ReadWrite.All"
```

Let's break down these modules and their purposes:

- `Microsoft.Graph.Authentication`: This is our key to the kingdom, allowing us to authenticate with Microsoft Graph.
- `Microsoft.Graph.Beta.Identity.Governance`: This module grants access to Identity Governance features, crucial for working with Access Packages.
- `Microsoft.Graph.Identity.DirectoryManagement`: We'll use this to interact with directory objects, including roles and role assignments.
- `Microsoft.Graph.Users` and `Microsoft.Graph.Groups`: These modules help us work with user and group objects in Entra ID.

## 🏰 The Arcane Knowledge: Permissions Required

Beware, young apprentice! To perform this powerful magic, you must possess the right scrolls of power. You need to wield the Global Administrator role to add Entra ID roles to the Catalog. However, our script will exclude the Global Administrator role itself from the Access Packages for security reasons.

> 🔑 Pro Tip: Always test your spells in a demo realm before unleashing them upon your production kingdom. This ensures you don't accidentally turn your users into digital toads!

## ☁️ Selecting the Chosen Ones: The Cloud Admin Group

In the realm of best practices, we use dedicated Cloud Admin accounts. These accounts are the keepers of the cloud, governed by different policy sets. We'll use an interactive selection spell to choose the appropriate group for these cloud admin accounts.

```powershell
# Function to select a group
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
```

This function fetches all dynamic groups in your Entra ID and presents them in a grid view. You can then select the group that contains your cloud admin accounts. This approach ensures flexibility and allows you to easily update the script if your admin group changes in the future.


```powershell
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


```

This function activates the correct PIM roles in order to execute the script

## 🎨 Crafting the Access Package Spell

Our `Get-OrCreateAccessPackage` function is the cornerstone of our automation. It ensures we don't duplicate our efforts by checking if the package already exists before creating a new one.


```powershell

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


```

This function performs the following magical feats:
1. Checks if an Access Package for the given role already exists
2. If it doesn't exist, creates a new Access Package with a standardized name and description
3. Returns the existing or newly created Access Package

By using this function, we ensure our script is idempotent — it can be run multiple times without creating duplicate packages.

## 🔓 Adding Role Scope: The Arcane Ritual

The `Add-RoleScopeToAccessPackage` function is where the real magic happens. It binds the Entra ID role to the access package, ensuring the role resource exists in the catalog.

```powershell
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
```

This function performs these mystical steps:
1. Checks if the role resource exists in the catalog
2. If it doesn't exist, adds the role to the catalog
3. Creates a role scope in the Access Package, linking it to the Entra ID role

This ensures that when someone is granted the Access Package, they receive the correct Entra ID role permissions.

## 📜 Conjuring the Catalog

Before we can summon the roles, we need a magical repository — a catalog. Our `Get-OrCreateCatalog` function creates this mystical container if it doesn't already exist.

```powershell
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
```

This function either retrieves an existing catalog or creates a new one, ensuring we have a place to store our Access Packages.

## ✨ Adding Roles to the Catalog: A Bit of Hocus Pocus

The `Add-EntraRoleToCatalog` function adds our Entra ID roles to the catalog, ensuring each role is ready for use in our access packages.

```powershell
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
```

This function checks if the role already exists in the catalog and adds it if it doesn't. This step is crucial, as roles must be in the catalog before we can include them in Access Packages.

## 📝 Enchanting the Access Packages with Policies

Our policy creation functions, `Get-ApprovalSettings` and `Get-AccessReviewSettings`, have been significantly improved to provide a more user-friendly experience:

```powershell

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
```

These functions allow you to interactively:
1. Choose between a one or two-step approval process
2. Select managers or specific users as approvers
3. Set up backup approvers for each stage
4. Configure access review settings

By separating these settings, we make our script more modular and easier to maintain.

Finally, we use the `Add-PolicyToAccessPackage` function to apply these settings to our Access Package:

```powershell
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
```
This function creates or updates the assignment policy for the Access Package, incorporating our approval and review settings.

## 🎭 The Grand Finale: Bringing It All Together

Our main script now excludes the Global Administrator role and uses our new approval settings function:

```powershell
# Main script section
Write-Host "🔮 Starting the magical process..."

# ... [Authentication and module import] ...

$defaultCatalogName = "Entra ID Admin Roles"
$catalogName = Read-Host "🔮 Enter the name of the catalog to create or update access packages for: [$defaultCatalogName]"
if ([string]::IsNullOrEmpty($catalogName)) {
    $catalogName = $defaultCatalogName
}
$catalog = Get-OrCreateCatalog -CatalogName $catalogName

# Get all Directory roles, excluding Global Administrator
Write-Host "📜 Gathering all Directory roles (excluding Global Administrator)..."
$directoryRoles = Get-MgDirectoryRole -All | Where-Object { 
    $null -ne $_.RoleTemplateId -and 
    $_.DisplayName -ne "Global Administrator" -and 
    $_.DisplayName -ne "Company Administrator"
}

Write-Host "Found $($directoryRoles.Count) eligible directory roles."

# Get all enabled Entra ID users
Write-Host "👥 Fetching all enabled Entra ID users..."
$EntraIDUsers = Get-MgUser -Filter "AccountEnabled eq true" -All | Select-Object DisplayName, Id

# Select the cloud admin group
$cloudAdminGroup = Select-Group
Write-Host "✅ Selected Cloud Admin Group: $($cloudAdminGroup.DisplayName)"

# Get approval settings once
$approvalSettings = Get-ApprovalSettings -EntraIDUsers $EntraIDUsers

# Get access review settings once
$accessReviewSettings = Get-AccessReviewSettings -EntraIDUsers $EntraIDUsers

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
        Write-Host "❌ Failed to process access package for '$roleName': $_" -ForegroundColor Red
    }
}

Write-Host "🏁 Process completed. Access packages have been created or updated for all eligible Directory roles in the '$catalogName' catalog."

# Disconnect from Microsoft Graph
Write-Host "🔌 Disconnecting from Microsoft Graph..."
Disconnect-MgGraph
```


This script:
1. Authenticates to Microsoft Graph
2. Creates or retrieves the catalog
3. Fetches all Entra ID roles (excluding Global Administrator)
4. Selects the Cloud Admin group
5. Gets approval and access review settings
6. For each role, creates an Access Package, adds the role scope, and applies the policy

By the end of this magical performance, you'll have a fully automated system for managing access to your Entra ID admin roles!

## 🌟 Conclusion: The Magic is in Your Hands

And there you have it, dear wizards! Our spellbook of PowerShell scripts to automate Access Package creation is complete. With this magic, you can ensure that access to your Entra ID admin roles (except Global Administrator) is consistently managed, properly approved, and regularly reviewed.

Remember, with great power comes great responsibility. Use these scripts wisely, always test in a non-production environment first, and may your access governance be ever strong and your security posture unbreakable!

> 📚 Further Learning: To deepen your understanding of Access Packages and Identity Governance, check out the [official Microsoft documentation](https://docs.microsoft.com/en-us/azure/active-directory/governance/entitlement-management-overview).

Until next time, keep conjuring those magical scripts! ☕🧙‍♂️

You can find the full script on GitHub: [Create-Access-Package.ps1](https://raw.githubusercontent.com/Dikkekip/dikkekip.github.io/main/scripts/2024-07-29-EntraID-AccessPackages/Create-Access-Package.ps1)
