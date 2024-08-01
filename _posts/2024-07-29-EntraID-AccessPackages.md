---
layout: post
title: "🚀 Automating Access Package Creation for Entra ID roles with PowerShell"
date: 2024-08-01 07:40:59 +0100
comments: true
description: "Discover the magic of automating PIM for groups with PowerShell and GraphAPI in Azure."
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
  path: /assets/img/pim-for-groups/thumbnail.png
  src: /assets/img/pim-for-groups/thumbnail.png
toc: true
---

# Unleashing the Magic: Automating Access Package Creation for Entra ID roles with PowerShell

Greetings, fellow wizards of the tech realm! 🧙‍♂️ Today, we embark on a mystical journey into the enchanted forest of PowerShell scripting and Microsoft Graph. Our quest? To automate the creation and management of Access Packages for Entra ID roles. So grab your wands (or keyboards) and let's dive in!

Today we will onbark on a juerney to Create a set of new access packages designed in to assign to Entra ID Admin roles.
Microsoft has made it avalible in Identity Govenance to assign Entra ID roles in PIM with Access packages.
https://learn.microsoft.com/en-us/entra/id-governance/entitlement-management-roles

therefor I wanted to go to the steps to automate this and write a small blog on it if you are looking for the same, as per usuall it requirs some deduction work on the MgGraph powershell modules, so I hope this can help you get started.



## Summoning the Essentials

First, we must gather our magical artifacts—PowerShell modules. These modules are essential to harness the power of Microsoft Graph and bend it to our will.

```powershell
# Import required modules
Write-Host "🔮 Summoning PowerShell modules..."
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Beta.Identity.Governance
Import-Module Microsoft.Graph.Identity.DirectoryManagement

# Authenticate to Microsoft Graph
Write-Host "🧙‍♂️ Authenticating to Microsoft Graph..."
Connect-MgGraph -Scopes "Directory.Read.All", "EntitlementManagement.ReadWrite.All"
```

### Permission required
as of the time of writing this, to add the Entra ID roles to the Catalog, 
you need to have the Global Administrator role avalible in pim, 
I had hoped I could get away with the "Privileged Authentication Administrator" role but this seems not to work (yet)
please test this out in a demo tenant and add a comment if there is another way. 

https://learn.microsoft.com/en-us/entra/id-governance/entitlement-management-roles



With these incantations, we authenticate to Microsoft Graph and prepare for the magic ahead.

## Selecting the Cloud Admin Group

It is best practice to use dedicated Cloud Admin accounts, with different policy sets and
We will use an interactive selection to choose the appropriate group for cloud admin accounts.

```powershell
# Function to select a group
function Select-Group {
    Write-Host "🔍 Fetching groups for selection..."
    $groups = Get-MgGroup -Filter "groupTypes/any(c:c eq 'Unified')" | Select-Object DisplayName, Id
    $selectedGroup = $groups | Out-ConsoleGridView -Title "Select the Cloud Admin Group" -PassThru
    if ($null -eq $selectedGroup) {
        throw "No group selected. Exiting script."
    }
    return $selectedGroup
}

# Select the cloud admin group
$cloudAdminGroup = Select-Group
Write-Host "✅ Selected Cloud Admin Group: $($cloudAdminGroup.DisplayName)"
```

## Crafting the Access Package Spell

Now, let's brew a powerful potion—a function to get or create an Access Package. This spell ensures we don't duplicate our efforts by checking if the package already exists before creating a new one.

With these incantations, we authenticate to Microsoft Graph and prepare for the magic ahead.

Crafting the Access Package Spell
Now, let's brew a powerful potion—a function to get or create an Access Package. This spell ensures we don't duplicate our efforts by checking if the package already exists before creating a new one.

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

## Adding Role Scope: The Arcane Ritual

Next, we must bind the role to the access package—a delicate ritual. We ensure the role resource exists in the catalog, and if not, we summon it.

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

## Conjuring the Catalog

Before we summon the roles, we need a magical repository—a catalog. If it doesn't exist, we create it.

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

## Adding Roles to the Catalog: A Bit of Hocus Pocus

Now, we add our Entra ID roles to the catalog, ensuring each role is ready for use in our access packages.

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

## Enchanting the Access Packages with Policies

Finally, we must add policies to our access packages, defining how and who can request these roles. This part requires precision and care.

```powershell

function Add-PolicyToAccessPackage {
    param (
        [Parameter(Mandatory=$true)]
        [string]$AccessPackageId,
        
        [Parameter(Mandatory=$true)]
        [string]$RoleName,
        
        [Parameter(Mandatory=$true)]
        [string]$GroupId
    )

    Write-Host "🔍 Processing policy for access package..." -ForegroundColor Yellow

    $policyDisplayName = "Policy for assigning $RoleName"

    # Check if policy already exists
    $existingPolicies = Get-MgBetaEntitlementManagementAccessPackageAssignmentPolicy -All
    $existingPolicy = $existingPolicies | Where-Object { $_.AccessPackageId -eq $AccessPackageId -and $_.DisplayName -eq $policyDisplayName }

    $approvalMode = Read-Host "🔮 Do you want a 1 or 2 step verification process? (Enter '1' or '2')"
    $firstStageApprovers = @()
    $secondStageApprovers = @()
    
    if ($approvalMode -eq '1') {
        $approverType = Read-Host "🔮 Do you want the first stage to be approved by a 'Manager' or 'Single User'?"
        if ($approverType -eq 'Manager') {
            $firstStageApprovers += @{
                "@odata.type" = "#microsoft.graph.requestorManager"
                managerLevel = 1
            }
            $backupApprover = (Get-MgUser -Filter "AccountEnabled eq true" | Select-Object DisplayName, Id | Out-ConsoleGridView -Title "Select the backup user for first stage" -PassThru).Id
            $firstStageApprovers += @{
                "@odata.type" = "#microsoft.graph.singleUser"
                userId = $backupApprover
                isBackup = $true
            }
        } elseif ($approverType -eq 'Single User') {
            $firstStageApprovers += @{
                "@odata.type" = "#microsoft.graph.singleUser"
                userId = (Get-MgUser -Filter "AccountEnabled eq true" | Select-Object DisplayName, Id | Out-ConsoleGridView -Title "Select the first stage approver" -PassThru).Id
            }
        } else {
            throw "Invalid approver type selected. Exiting script."
        }
    } elseif ($approvalMode -eq '2') {
        # First stage
        $firstStageApprovers += @{
            "@odata.type" = "#microsoft.graph.requestorManager"
            managerLevel = 1
        }
        $backupApprover = (Get-MgUser -Filter "AccountEnabled eq true" | Select-Object DisplayName, Id | Out-ConsoleGridView -Title "Select the backup user for first stage" -PassThru).Id
        $firstStageApprovers += @{
            "@odata.type" = "#microsoft.graph.singleUser"
            userId = $backupApprover
            isBackup = $true
        }
        
        # Second stage
        $secondStageApprovers += @{
            "@odata.type" = "#microsoft.graph.singleUser"
            userId = (Get-MgUser -Filter "AccountEnabled eq true" | Select-Object DisplayName, Id | Out-ConsoleGridView -Title "Select the second stage approver" -PassThru).Id
        }
    } else {
        throw "Invalid verification process selected. Exiting script."
    }

    $enableAccessReview = Read-Host "🔮 Do you want to enable access reviews? (Enter 'Yes' or 'No')"
    $accessReviewSettings = @{}
    if ($enableAccessReview -eq 'Yes') {
        $reviewerType = Read-Host "🔮 Should the manager be the reviewer? (Enter 'Yes' or 'No')"
        $accessReviewSettings = @{
            isEnabled = $true
            recurrenceType = "quarterly"
            reviewerType = if ($reviewerType -eq 'Yes') { "Manager" } else { "Self" }
            startDateTime = (Get-Date).AddDays(1).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            durationInDays = 25
            reviewers = @(
                @{
                    "@odata.type" = "#microsoft.graph.singleUser"
                    userId = (Get-MgUser -Filter "AccountEnabled eq true" | Select-Object DisplayName, Id | Out-ConsoleGridView -Title "Select the backup user for access review" -PassThru).Id
                    isBackup = $true
                }
            )
            isAccessRecommendationEnabled = $true
            isApprovalJustificationRequired = $true
            accessReviewTimeoutBehavior = "keepAccess"
        }
    }

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
                    primaryApprovers = $firstStageApprovers
                },
                @{
                    approvalStageTimeOutInDays = 14
                    isApproverJustificationRequired = $true
                    isEscalationEnabled = $false
                    primaryApprovers = $secondStageApprovers
                }
            )
        }
        accessReviewSettings = $accessReviewSettings
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


```

The Grand Finale: Bringing It All Together
Now that we've mastered our spells, let's combine them into one grand script to automate our entire process. This script creates the catalog, adds roles, creates access packages, and applies policies.

```powershell
# Main script section
Write-Host "🔮 Starting the magical process..."
$catalogName = "Entra Admins"
$catalog = Get-OrCreateCatalog -CatalogName $catalogName

# Get all Directory roles
Write-Host "📜 Gathering all Directory roles..."
$directoryRoles = Get-MgDirectoryRole -All | Where-Object { $null -ne $_.RoleTemplateId }

# Add each role to the catalog
foreach ($role in $directoryRoles) {
    Write-Host "✨ Adding role $($role.DisplayName) to catalog..."
    Add-EntraRoleToCatalog -CatalogId $catalog.Id -Role $role
}

# Create access packages and add role scopes
foreach ($role in $directoryRoles) {
    $roleName = $role.DisplayName
    Write-Host "🔮 Processing access package for role: $roleName"

    try {
        $accessPackage = Get-OrCreateAccessPackage -RoleName $roleName -CatalogId $catalog.Id -RoleId $role.RoleTemplateId

        # Add role scope to the access package
        Add-RoleScopeToAccessPackage -AccessPackageId $accessPackage.Id -Role $role -CatalogId $catalog.Id

        # Add policy to the access package
        Add-PolicyToAccessPackage -AccessPackageId $accessPackage.Id -RoleName $roleName
    }
    catch {
        Write-Host "❌ Failed to process access package for $roleName: $_" -ForegroundColor Red
    }
}

Write-Host "🏁 Process completed. Access packages have been created or updated for all Directory roles in the '$catalogName' catalog."

# Disconnect from Microsoft Graph
Write-Host "🔌 Disconnecting from Microsoft Graph..."
Disconnect-MgGraph

```

And there you have it, dear wizards! Our spellbook of PowerShell scripts to automate Access Package creation is complete. May your scripts run smoothly, and your coffee cups never run dry. Until next time, keep conjuring those magical scripts! ☕🧙‍♂️

Feel free to adjust the tone and add any additional personal touches to make it your own. Happy blogging!
