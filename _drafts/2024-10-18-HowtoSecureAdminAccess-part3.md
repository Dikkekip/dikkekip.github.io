---
layout: post
title:  "How to Secure Admin Access! - Part 3"
date:   2024-10-18 10:00:00 +0200
description: "Onboarding and Offboarding Admins with Azure Automation"
categories: [Entra ID, Cloud Security, Access Management, Azure Automation, IT Security, Cloud Administration, Microsoft Azure, DevOps Practices]
tags: [Entra ID, Cloud Security, Access Management, Azure Automation, IT Security, Cloud Administration, Microsoft Azure]
image:
  path: /assets/img/SecuringAdminAccess/phishing-resistance-journey.png
  src: /assets/img/SecuringAdminAccess/phishing-resistance-journey.png
---

## How to Secure Admin Access - Part 3: Onboarding phising Resistant policies with Automation 🛡️✨
Hello again, fellow IT wizards 🧙‍♂️🧙‍♀️, to our magical journey of securing admin access!
First of all, Great news! 

Passkeys are now Generally available in Entra ID! 🎉🎉🎉
This is amazing news for all of us who are looking to boost our security and efficiency. 🚀🔐

 In **Part 1**, we ventured into the realms of **Admin Access** and set the foundations for a secure kingdom. In **Part 2**, we dived into **Persona-Based Conditional Access Policies**—essentially enchanted wards 🧙‍♂️🔮 tailored to different roles within your organization. This time, we're going to automate the onboarding and offboarding of admin phising resistant MFA with **Powershell and Azure Automation account**.


Why is this a game-changer? 🤔
🔒 Security: No more worrying about weak or reused passwords. Passkeys are tied to your device, making them much harder to compromise.
⏱️ Speed: Say goodbye to mistyped passwords, forgotten credentials, or scrambling to find where you saved them. With passkeys, you’re in with just a tap or a glance!
🌟 Success rate: 98% successful sign-in rate when using passkeys


Now be resistant against AiTM attacks and phishing with passkeys! 🛡️✨

98% successful sign-in rate when using passkeys
3x Higher sign in success rate than passwords

Ready to boost your security and efficiency? Let’s embrace the future of authentication! 🔐💡
- [Joy's blog](https://techcommunity.microsoft.com/blog/identity/ignite-ai-and-sase-innovations-in-microsoft-entra/2747278)
- [Intro video on passkeys](https://www.youtube.com/watch?v=zxf75zF91dY)
- [How to configure passkeys](https://www.youtube.com/watch?v=jIZBP7tG5I8)
- [Updated docs](https://learn.microsoft.com/en-gb/entra/identity/authentication/how-to-enable-authenticator-passkey)

![MFA Options](/assets/img/SecuringAdminAccess/mfa-options.png)

### 🧙‍♂️ ScubaGear already recommends you to enforce it on all users 🔮

https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/aad.md#msaad31v1

#### MS.AAD.3.1v1
Phishing-resistant MFA SHALL be enforced for all users.

The phishing-resistant methods **Microsoft Entra ID certificate-based authentication (CBA)**, **FIDO2 Security Key** and **Windows Hello for Business** are the recommended authentication options since they offer forms of MFA with the least weaknesses.


<!--Policy: MS.AAD.3.1v1; Criticality: SHALL -->
- _Rationale:_ Weaker forms of MFA do not protect against sophisticated phishing attacks. By enforcing methods resistant to phishing, those risks are minimized.
- _Last modified:_ June 2023
- _MITRE ATT&CK TTP Mapping:_
  - [T1566: Phishing](https://attack.mitre.org/techniques/T1566/)
    - [T1566.001: Spearphishing Attachment](https://attack.mitre.org/techniques/T1566/001/)
    - [T1566.002: Spearphishing Link](https://attack.mitre.org/techniques/T1566/002/)

# but what about resource tenants?

As you can see the [Plan a phishing-resistant passwordless authentication Guide for Microsoft Docs](https://learn.microsoft.com/en-us/entra/identity/authentication/how-to-deploy-phishing-resistant-passwordless-authentication#onboarding-step-1-identity-verification) Ilustrates that we need to have compliant devices and Windows Hello for Business in place, in order to register our passkeys in the authenticatior app in order to inforce them with conditional access policies.
We cannot use the first time MFA wizzard to set up the passkey from the get go if the Phising Resistant Conditional Access policy is targeting the persona based groups containing all administrators.

Errors:
![alt text](/assets/img/SecuringAdminAccess/image-2.png)
![alt text](/assets/img/SecuringAdminAccess/image-3.png)
![alt text](/assets/img/SecuringAdminAccess/image-4.png)


# But there is a solution!, So lets automate the onboarding and offboarding of admin phising resistant MFA with powershell!

We are going to use some automation magic to onboard and offboard admins with phishing-resistant MFA. 🧙‍♂️✨
We will make Custom attributes for the users and then populate them with the correct values, and then create some dynamic groups based on the values of the attributes. these dynamic groups will then be used in the conditional access policies to target the users with the correct MFA settings. and then we will output a script that we can use in an automation account to update the users MFA information on a ragular bases.

### Step 1 
Lets set the correct baseline here and use all the tools we have at our disposal.

First we want to make sure our admin accounts are in a [Restricted management] Administrative units. This will make sure we can target these accounts with Entra ID roles and are not manageble by Entra ID roles on the tenant level. 


You can find the (very large) script here:
[Create-CaPasskeyBaseline - Github](https://github.com/Dikkekip/dikkekip.github.io/blob/main/scripts/2024-07-29-SecuringAdminAccess/Create-PhisingCheck.ps1){:target="_blank"}
[Create-CaPasskeyBaseline - RAW](https://raw.githubusercontent.com/Dikkekip/dikkekip.github.io/main/scripts/2024-07-29-SecuringAdminAccess/Create-PhisingCheck.ps1){:target="_blank"}

<!-- markdownlint-capture -->
<!-- markdownlint-disable -->
> **Note**: Due to the script's length, please refer to the script at the provided link.
{: .prompt-info }
<!-- markdownlint-restore --> Due to the script's length, please refer to the script at the provided link.

PS: let me know if you have some tips on making such a large script prettier and more readable. 

#### I will contitue with small snippets of the script for the rest of the blog post.

```powershell
# Call the function
Connect-ToMicrosoftGraph -Scopes $requiredScopes

Write-Host "[INFO] Starting to provision Administrative Units and assign roles..." -ForegroundColor Cyan
$administrativeUnit = Add-GetCreateAU -Name "$tenantName Platform Admins" -Description "Administrative Unit for $tenantName Platform Admins"

Add-MembersToAU -AUId $administrativeUnit.Id
```
![create AU](../assets/img/SecuringAdminAccess/AU.png)
## 📚 Now lets create Custom Attributes

In order for conditional access to be able do do anything with the users we need to create some custom attributes.
Conditional Access can only target Users and Groups and doesn't have the ability to know what MFA options the Admins have registered. 

as pointed out by [Stian Andresen Strysse](https://no.linkedin.com/in/stianstrysse) in his [blog](https://learningbydoing.cloud/blog/getting-started-with-custom-security-attributes-in-azuread/) Custom Security Attributed would be the best to use here, but Unfortunatly this doesn't support the ability to create Dynamic Entra ID groups based on the set values, so we have to revert to [custom extension attribute](https://learningbydoing.cloud/blog/getting-started-with-azuread-extension-attributes/). 

So now that we have astrablished that we need to create a custom extension attribute we can use to target the users with Conditional Access. 
First we need to create ourselves a Registerd Application in Entra ID Tenant and Add the attribute to the application, so that they will be avalible on the User Objects.



You can find the script here:
[Create-CaPasskeyBaseline - Github](https://github.com/Dikkekip/dikkekip.github.io/blob/main/scripts/2024-07-29-SecuringAdminAccess/Create-PhisingCheck.ps1){:target="_blank"}
[Create-CaPasskeyBaseline - RAW](https://raw.githubusercontent.com/Dikkekip/dikkekip.github.io/main/scripts/2024-07-29-SecuringAdminAccess/Create-PhisingCheck.ps1){:target="_blank"}


<!-- markdownlint-capture -->
<!-- markdownlint-disable -->
> **Note**: Due to the script's length, please refer to the script at the provided link.
{: .prompt-info }
<!-- markdownlint-restore --> Due to the script's length, please refer to the script at the provided link.

```powershell
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
Write-Host "[INFO] Custom extension properties created successfully." -ForegroundColor Green

# Get-MgApplicationExtensionProperty -ApplicationId $app | select Name,DataType
```

Now we can find the Three attributes created on the Application object in the Entra ID tenant.
[![Extension Attributes](/assets/img/SecuringAdminAccess/extension-attributes.png)](/assets/img/SecuringAdminAccess/extension-attributes.png)


## 📚 Now lets check the users set MFA values and then populate the attributes

Now that we have the attributes created we can start populating them with the correct values. but since we want to use the Least privilaged approuch. I wanted to actually create a custom role that only has the ability to read the MFA settings of the users. 
Unfortunatly there was no support for microsoft.directory/users/authenticationMethods/standard/privilegedRead in the custom roles, so we had to go with the standard Roles assigned to the AU.

For the creation of the AU and the role assignment we can use the following script:

```powershell
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
Write-Host "[INFO] Privileged Authentication Administrator role assigned to $adminUserName in $administrativeUnit." -ForegroundColor Green

```


We can still create a custom role that only has the ability to read the MFA settings of users that are no administrators, or marked as Privilaged users and I would have preffered to use this method but I was unable to get the role to work as expected for the Admin Accounts. here is the role creation script that I would have used if it worked as expected.: 

You can find the script here:
[Create-CaPasskeyBaseline - Github](https://github.com/Dikkekip/dikkekip.github.io/blob/main/scripts/2024-07-29-SecuringAdminAccess/Create-CAPasskey-PhisingCheck.ps1){:target="_blank"}
[Create-CaPasskeyBaseline - RAW](https://raw.githubusercontent.com/Dikkekip/dikkekip.github.io/main/scripts/2024-07-29-SecuringAdminAccess/Create-CAPasskey-PhisingCheck.ps1){:target="_blank"}


<!-- markdownlint-capture -->
<!-- markdownlint-disable -->
> **Note**: Due to the script's length, please refer to the script at the provided link.
{: .prompt-info }
<!-- markdownlint-restore --> Due to the script's length, please refer to the script at the provided link.

```powershell
# Define parameters
param(
    [string]$DisplayName = "Authentication Method Reader",
    [string]$Description = "Read-only access to user authentication methods",
    [string]$PrincipalUserUPN = "admin-dodo@M365x4.onmicrosoft.com",  # Replace with your user UPN
    [string]$PrincipalSPNId = "",       # Replace with your service principal ID
    [string]$AdminUnitDisplayName = "Cloud-and-Code Platform Admins"         # Replace with your administrative unit name
)

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "Directory.ReadWrite.All", "RoleManagement.ReadWrite.Directory", "AdministrativeUnit.ReadWrite.All"


# Main script execution
try {
    # Set of permissions to grant
    $allowedResourceActions = @(
        "microsoft.directory/users/authenticationMethods.email/standard/read",
        "microsoft.directory/users/authenticationMethods.fido2/standard/read",
        "microsoft.directory/users/authenticationMethods.microsoftAuthenticator/standard/read",
        "microsoft.directory/users/authenticationMethods.password/standard/read",
        "microsoft.directory/users/authenticationMethods.passwordlessMicrosoftAuthenticator/standard/read",
        "microsoft.directory/users/authenticationMethods.securityQuestion/standard/read",
        "microsoft.directory/users/authenticationMethods.sms/standard/read",
        "microsoft.directory/users/authenticationMethods.softwareOath/standard/read",
        "microsoft.directory/users/authenticationMethods.temporaryAccessPass/standard/read",
        "microsoft.directory/users/authenticationMethods.voice/standard/read",
        "microsoft.directory/users/authenticationMethods/standard/read"
        # Note: "microsoft.directory/users/authenticationMethods/standard/privilegedRead" cannot be assigned in custom roles
    )

    $rolePermissions = @(
        @{
            AllowedResourceActions = $allowedResourceActions
        }
    )

    # Generate a template ID
    $templateId = (New-Guid).Guid

    # Check if role already exists
    $existingRole = Get-RoleDefinition -RoleName $DisplayName

    if ($existingRole) {
        Write-Host "Role '$DisplayName' already exists."

        # Extract existing allowed actions
        $existingAllowedActions = @()
        foreach ($permission in $existingRole.RolePermissions) {
            $existingAllowedActions += $permission.AllowedResourceActions
        }

        # Compare permissions
        $permissionsChanged = $false

        if (@(Compare-Object -ReferenceObject $existingAllowedActions -DifferenceObject $allowedResourceActions -IncludeEqual | Where-Object { $_.SideIndicator -ne '==' }).Count -gt 0) {
            $permissionsChanged = $true
        }

        if ($permissionsChanged) {
            Write-Host "Permissions have changed. Updating role..."
            Update-CustomRole -RoleDefinitionId $existingRole.Id -RolePermissions $rolePermissions -Description $Description
            Write-Host "Role '$DisplayName' has been updated."
        } else {
            Write-Host "Permissions have not changed. No update required."
        }
    } else {
        Write-Host "Role '$DisplayName' does not exist. Creating new role..."
        $customRole = Create-CustomRole -DisplayName $DisplayName -Description $Description -RolePermissions $rolePermissions -TemplateId $templateId
        Write-Host "Role '$DisplayName' has been created."
        $existingRole = $customRole  # Assign for later use
    }

    # Get the role definition ID
    $roleDefinitionId = $existingRole.Id

    # Get the Administrative Unit
    $adminUnit = Get-MgDirectoryAdministrativeUnit -Filter "displayName eq '$AdminUnitDisplayName'"
    if (-not $adminUnit) {
        Write-Error "Administrative Unit '$AdminUnitDisplayName' not found."
        return
    }
    $directoryScopeId = "/administrativeUnits/$($adminUnit.Id)"

    # Get the user
    $user = Get-MgUser -Filter "userPrincipalName eq '$PrincipalUserUPN'"
    if (-not $user) {
        Write-Error "User '$PrincipalUserUPN' not found."
    } else {
        $principalUserId = $user.Id
        # Assign role to user
        Assign-Role -PrincipalId $principalUserId -RoleDefinitionId $roleDefinitionId -DirectoryScopeId $directoryScopeId
    }

    # Get the service principal
    $spn = Get-MgServicePrincipal -ServicePrincipalId $PrincipalSPNId
    if (-not $spn) {
        Write-Error "Service Principal with ID '$PrincipalSPNId' not found."
    } else {
        $principalSPNId = $spn.Id
        # Assign role to service principal
        Assign-Role -PrincipalId $principalSPNId -RoleDefinitionId $roleDefinitionId -DirectoryScopeId $directoryScopeId
    }
}
catch {
    Write-Error "An error occurred: $_"
}
finally {
    # Disconnect from Microsoft Graph
    Disconnect-MgGraph
}
```


## Updating the users attributes to include the MFA settings

First we will create some new Dynamic entra ID groups
![Dynamic Groups](/assets/img/SecuringAdminAccess/image-5.png)

```powershell

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


```

After creating the groups we will update the users attributes to include the MFA settings
![alt text](../assets/img/SecuringAdminAccess/MFA-Settings-Check.png)

```powershell

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
Update-IAMPhishingResistantStatus -Object $selectedGroups[0] -ObjectType "Group" -PhishingResistantEnabledAttr $enabledAttr -PhishingResistantLastCheckedAttr $lastCheckedAttr -PhishingResistantStatusAttr $statusAttr
```

Now it will check the settings of the users and update the attributes of the users to include the MFA settings.
[Fido Check](/assets/img/SecuringAdminAccess/extension-attributes.png)

we will then see that the Dynamic groups have been updated with the users.
[Dynamic Groups](/assets/img/SecuringAdminAccess/Dynamic-Groups.png)

Now that the users are updated in the dynamic group, we need to output a script that we can use in an automation account to update the users MFA information on a ragular bases. 

```powershell

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

        $hourlyCheckerScriptContent = @""
    }
}
# Output the script content
```
### Create the automation account
You can now find the script in the directory where you ran the script. 
This script we can import into an automation account and run it on a regular basis to update the users MFA settings. make sure that the system Assigned Identity of the automation account has the correct permissions to read the MFA settings of the users. 

by using the following script you can create the automation account with the corrcect modules installed

[Create-CAPasskey-AutomationAccount - Github](https://github.com/Dikkekip/dikkekip.github.io/blob/main/scripts/2024-07-29-SecuringAdminAccess/Create-CAPasskey-AutomationAccount.ps1){:target="_blank"}
[Create-CaPasskeyBaseline - RAW](https://raw.githubusercontent.com/Dikkekip/dikkekip.github.io/main/scripts/2024-07-29-SecuringAdminAccess/Create-CAPasskey-AutomationAccount.ps1){:target="_blank"}


<!-- markdownlint-capture -->
<!-- markdownlint-disable -->
> **Note**: Due to the script's length, please refer to the script at the provided link.
{: .prompt-info }
<!-- markdownlint-restore --> Due to the script's length, please refer to the script at the provided link.


```powershell
$userAuth = New-EligibeRoleActivationForAU -adminUnit $administrativeUnit -roleName "User Administrator" -UserObjectId "System Assigned Identity ID here"
$mfaAuth = New-EligibeRoleActivationForAU -adminUnit $administrativeUnit -roleName "Privileged Authentication Administrator" -UserObjectId "System Assigned Identity ID here"
```

## Last but not least, we need to create the Conditional Access Policies

Now we create a new Authentication strengh policy that will allow for TAP and Phising resistant MFA for the users in the dynamic groups. 

```powershell

# Step: Create Authentication Strength
$authStrengthParams = @{
    Name = "Phishing-resistant-firsttimeUse"
    Description = "Authentication strength for first-time use with phishing-resistant methods"
    AllowedCombinations = @("fido2", "windowsHelloForBusiness", "x509CertificateMultiFactor", "temporaryAccessPassOneTime")
}
$authStrength = New-AuthenticationStrength @authStrengthParams
Write-Host "Authentication Strength created: $($authStrength.DisplayName)"
```

Now we can create the Conditional Access Policies that will target the dynamic groups and the Authentication Strength policy we just created. 

```powershell


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
                "ca-Persona-Admins-BaseProtection-Exclusions",
                "ca-Persona-Microsoft365ServiceAccounts",
                "ca-Persona-AzureServiceAccounts",
                "ca-Persona-CorpServiceAccounts",
                "ca-Persona-admins-PhishingResistant-Exclusions"
            )
        }
    }
    GrantControls = @{
        operator               = "AND"
        builtInControls        = @()
        authenticationStrength = @{ id = "00000000-0000-0000-0000-000000000004" }
    }
}
New-ConditionalAccessPolicies -Params $caPolicy1Params

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
New-ConditionalAccessPolicies -Params $caPolicy2Params

```


Hope you enjoyed this deep dive into securing your admins with phishing-resistant MFA. Implementing these policies not only bolsters your security posture but also brings peace of mind. Stay safe and happy coding! 🔐🎉