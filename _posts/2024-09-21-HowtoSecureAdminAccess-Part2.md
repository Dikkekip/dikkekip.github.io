---
layout: post
title:  "How to Secure Admin Access! - Part 2"
date:   2024-09-21 10:00:00 +0530
comments: true
description: "Securing Admin Access in Microsoft Entra ID: Phishing-Resistant Authentication, Token Protection, and More!"
categories: [Entra ID, Cloud Security, Access Management, Azure Automation, IT Security, Cloud Administration, Microsoft Azure, DevOps Practices]
tags: [Entra ID, Cloud Security, Access Management, Azure Automation, IT Security, Cloud Administration, Microsoft Azure]
image:
  path: /assets/img/1725962735025.gif
  src: /assets/img/1725962735025.gif
toc: true
---

## How to Secure Admin Access - Part 2: Automating Persona-Based Conditional Access Policies 🛡️✨

Welcome back, fellow IT wizards 🧙‍♂️🧙‍♀️, to our magical journey of securing admin access! In Part 1, we ventured into the realms of **Admin Access** and set the foundations for a secure kingdom. This time, we're diving into **Persona-Based Conditional Access Policies**—essentially enchanted wards 🧙‍♂️🔮 tailored to different roles within your organization. Instead of casting a generic **Protego Totalum** 🛡️ over everyone, we're going to fine-tune our spells (ahem, policies) based on role, access requirements, and risk levels.

For example, your mighty **Global Administrator** (think **Dumbledore of Entra ID**) needs stricter security enchantments than an average user just accessing coffee orders ☕📋.

### Why Persona-Based Policies Matter ⚖️

Not everyone in your organization needs the power of a **Nimbus 2000** 🧹. Some users, like HR employees handling sensitive data 🗂️, need extra protection, but it's nothing compared to what your **Global Administrators** need. That's where persona-based policies come in. Like casting a **Lumos** 💡 that’s bright enough to guide you but doesn’t blind anyone, these policies balance security and usability.

With these, you can require extra steps (think of MFA as a **magic incantation** 🧩) for high-risk users, while others breeze through securely. 🔐

### Persona Breakdown 🧙‍♂️📜

In this realm of Conditional Access, users fit into different personas, each getting a specific set of security spells tailored to their role:

- **ca-persona-admins**: High-privilege admins needing **phishing-resistant MFA** 🛡️ (you don’t want your castle walls breached by a simple charm 🧙‍♂️).
- **ca-persona-global**: Global protection 🏰—applied universally to everyone. This is your foundation spell!
- **ca-persona-externals**: External contractors 🧳 with limited access, bounded by specific application policies 🔐.
- **ca-persona-guests**: Guests 🎓 (visiting from another realm) with light security and restricted resource access.
- **ca-persona-internals**: Regular employees 🧑‍💼 needing moderate protection (MFA) for day-to-day applications.
- **ca-persona-guestadmins**: Guests granted temporary **admin powers** 🏆 (think students borrowing a professor's wand), requiring **Protego Maxima** 🛡️🛡️.
- **ca-persona-developers**: Developers 🧑‍💻 working with sensitive environments 🔮, needing strict device compliance and MFA.
- **ca-persona-serviceaccounts**: Service accounts 🤖 requiring special protections like **managed identities** and token policies. (You don’t want these going rogue, like a Niffler chasing shiny tokens ✨🦡.)

### The Magical Framework from Claus Jespersen 🧙‍♂️💻

Claus Jespersen and his brilliant team have provided an excellent guide for implementing these persona-based policies. They crafted the **Conditional Access Framework**, built on **Zero Trust principles**, and it’s an absolute game-changer 🔐. This framework uses a clear naming convention for different personas, helping you manage policies and avoid potential conflicts.

Claus's work includes an invaluable **[Excel Workbook](https://github.com/microsoft/ConditionalAccessforZeroTrustResources/raw/main/ConditionalAccessSamplePolicies/Microsoft%20Conditional%20Access%20for%20Zero%20trust%20persona%20based%20policies.xlsx)**, which provides a template for persona-based Conditional Access policies. Alongside this, the **[PDF guide](https://github.com/microsoft/ConditionalAccessforZeroTrustResources/blob/main/ConditionalAccessGovernanceAndPrinciplesforZeroTrust%20October%202023.pdf)** explains the governance and principles in great detail.

**Huge kudos to Claus** for making it easy to implement this in the real world! 🎉🔮

### Automating Persona Creation with PowerShell 🪄💻

Managing security spells (oops, I mean policies) can be time-consuming. Here’s where a bit of automation magic via PowerShell ⚡💻 can save the day. Below is a spell (aka script 🧑‍💻) that automates the creation of security groups for your personas.

#### PowerShell Script for Creating Security Groups ⚙️

You can find the script here: [Create-groups.ps1](https://raw.githubusercontent.com/Dikkekip/dikkekip.github.io/main/scripts/2024-07-29-SecuringAdminAccess/Create-groups.ps1)

![Screenshot](assets/img/SecuringAdminAccess/Screenshot%202024-09-21%20142118.png)

<!-- markdownlint-capture -->
<!-- markdownlint-disable -->
> **Note**: Due to the script's length, please refer to the script at the provided link.
{: .prompt-info }
<!-- markdownlint-restore -->

```powershell
# PowerShell script content
# Due to length, please refer to the script at the provided link.

function Get-ValidMailNickname {
    param (
        [string]$DisplayName
    )
    # Remove any non-alphanumeric characters and replace spaces with underscores
    $mailNickname = $DisplayName -replace '[^\w\-]', '' -replace '\s', '_'
    
    # Truncate to 64 characters if longer
    if ($mailNickname.Length -gt 64) {
        $mailNickname = $mailNickname.Substring(0, 64)
    }
    
    return $mailNickname.ToLower()
}


function New-AADGroup {
    param (
        [string]$DisplayName,
        [string]$Description,
        [bool]$SecurityEnabled,
        [bool]$MailEnabled,
        [string[]]$GroupTypes,
        [string]$MembershipRule,
        [string]$MembershipRuleProcessingState
    )

    $validMailNickname = Get-ValidMailNickname -DisplayName $DisplayName

    # Check if the group already exists
    $existingGroup = Get-MgGroup -Filter "DisplayName eq '$DisplayName'"
    
    if ($existingGroup) {
        Write-Host "Group '$DisplayName' already exists. Skipping creation." -ForegroundColor Yellow
        return
    }

    $params = @{
        DisplayName = $DisplayName
        Description = $Description
        MailNickname = $validMailNickname
        SecurityEnabled = $SecurityEnabled
        MailEnabled = $MailEnabled
        GroupTypes = $GroupTypes
    }

    if ($MembershipRule) {
        $params.MembershipRule = $MembershipRule
        $params.MembershipRuleProcessingState = $MembershipRuleProcessingState
    }

    try {
        $newGroup = New-MgGroup -BodyParameter $params
        Write-Host "Group '$DisplayName' created successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "Error creating group '$DisplayName': $_" -ForegroundColor Red
    }
}

# Connect to Microsoft Graph if not already connected
if (-not (Get-MgContext)) {
    try {
        Connect-MgGraph -Scopes "Group.ReadWrite.All" -ErrorAction Stop
        Write-Host "Connected to Microsoft Graph successfully." -ForegroundColor Green
        Log-Message "Connected to Microsoft Graph successfully."
    }
    catch {
        Write-Host "Failed to connect to Microsoft Graph. Error: $_" -ForegroundColor Red
        Log-Message "Failed to connect to Microsoft Graph. Error: $_"
        exit
    }
}

# Define the groups to create
# left out because of length



foreach ($group in $groups) {
    New-AADGroup @group
}
```

This PowerShell script helps you create persona-based security groups for **admins**, **service accounts**, and **guests** from distant lands 🌍. Customize group types and membership rules to fit your unique wizarding (or organizational) needs 🏰✨.

### Creating Admin and Break Glass Accounts 🧙‍♂️🔐

Admins are like the **Masters of the Elder Wand** 🪄 in your organization—so they need extra layers of protection. Similarly, **Break Glass accounts** are your **emergency exit spells** 🧩, only used in dire situations when admin accounts might fail. The PowerShell script below ensures both types of accounts are secured with the proper magical safeguards 🛡️.

The script automates the creation of Admin accounts and Break Glass accounts, setting them up with strong passwords (no Alohomora here!) and assigning them appropriate roles and permissions, including **Global Administrator role eligibility** through Privileged Identity Management (PIM).

#### Admin Users Creation Script ⚙️

For full details and to get the script, you can download it here: [Create-Users.ps1](https://raw.githubusercontent.com/Dikkekip/dikkekip.github.io/main/scripts/2024-07-29-SecuringAdminAccess/Create-Users.ps1)

![Screenshot](assets/img/SecuringAdminAccess/Create-Users.png)

#### Key Features of the Script:

- **Complex Password Generation**: No basic "Expelliarmus" spells here. The script conjures complex passwords 🔐 using a mix of uppercase, lowercase, numbers, and special characters.
- **Admin Account Creation**: Adds new admins, checks for existing accounts, and assigns them to the appropriate Conditional Access groups like **ca-persona-admins** 🛡️.
- **Break Glass Accounts**: Creates or verifies up to two Break Glass accounts (BG1 and BG2), with secure passwords and limited access, acting as your last-resort safety net. Think of it as your magical emergency plan 💼🛑.
- **Global Admin Eligibility**: Automatically assigns **Global Administrator** role eligibility via PIM—because we want our admins to wield their power responsibly 🏆.

#### The **Break Glass** Effect 💼🛡️

If your main admin accounts are locked out, Break Glass accounts are your fallback. This script ensures their **Global Admin** role is always accessible, even when regular systems falter. They’re like magical safeguards with minimal everyday usage, but they’ll save you when things get chaotic! 🛡️✨


#### Admin users creation script ⚙️

<!-- markdownlint-capture -->
<!-- markdownlint-disable -->
> **Note**: Due to the script's length, please refer to the script at the provided link.
{: .prompt-info }
<!-- markdownlint-restore -->

```powershell
# Function to generate a random string for Break Glass accounts
function New-RandomString {
    $characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'.ToCharArray()
    -join (1..8 | ForEach-Object { $characters | Get-Random })
}

# Function to check if a user exists
function Get-ExistingUser {
    param (
        [Parameter(Mandatory=$true)]
        [string]$UserPrincipalName
    )

    try {
        $user = Get-MgUser -Filter "userPrincipalName eq '$UserPrincipalName'" -ErrorAction Stop
        return $user
    }
    catch {
        return $null
    }
}

# Function to reset a user's password
function Reset-UserPassword {
    param (
        [Parameter(Mandatory=$true)]
        [string]$UserId
    )

    $password = New-ComplexPassword

    $passwordProfile = @{
        Password = $password
        ForceChangePasswordNextSignIn = $true
    }

    try {
        Update-MgUser -UserId $UserId -PasswordProfile $passwordProfile -ErrorAction Stop
        Write-Host "Password has been reset successfully." -ForegroundColor Green
        Write-Host "Temporary password: $password" -ForegroundColor Yellow
        Write-Host "Please ensure the user changes this password upon next login." -ForegroundColor Yellow
        Log-Message "Password reset for UserId: $UserId."
    }
    catch {
        Write-Host "Error resetting password: $_" -ForegroundColor Red
        Log-Message "Error resetting password for UserId: $UserId. Error: $_"
    }
}

# Function to create a new admin account or handle existing one
function New-AdminAccount {
    while ($true) {
        $userId = Read-Host "Enter the 3 or 4 letter user ID for the admin account"
        if ($userId -match '^[A-Za-z]{3,4}$') {
            break
        }
        else {
            Write-Host "Invalid User ID. Please enter exactly 3 or 4 letters." -ForegroundColor Yellow
        }
    }
    $mgAdminUser = Get-MgContext | Select-Object -ExpandProperty Account
    $tenantDomain = $mgAdminUser -split '@' | Select-Object -Last 1
    $userPrincipalName = "admin-$userId@$tenantDomain"

    # Check if UPN already exists
    $existingUser = Get-ExistingUser -UserPrincipalName $userPrincipalName
    if ($existingUser) {
        Write-Host "A user with UPN $userPrincipalName already exists." -ForegroundColor Yellow
        Log-Message "User with UPN $userPrincipalName already exists."
        $choice = Read-Host "Do you want to reset the existing user's password? (Y/N)"
        if ($choice -eq "Y") {
            Reset-UserPassword -UserId $existingUser.ID
            $personaGroup = get-MgGroup -filter "displayName eq 'ca-persona-admins'" 
            New-MgGroupMember -GroupId $personaGroup.id -DirectoryObjectId $newUser.id -ErrorAction SilentlyContinue
        }
        else {
            $personaGroup = get-MgGroup -filter "displayName eq 'ca-persona-admins'" 
            New-MgGroupMember -GroupId $personaGroup.id -DirectoryObjectId $newUser.id -ErrorAction SilentlyContinue
            Write-Host "Skipping password reset. Please choose a different User ID." -ForegroundColor Red
            Log-Message "Skipped password reset for existing user with UPN $userPrincipalName."
        }
        return $existingUser
    }
    
    $inputName = Read-Host "Enter the name for the admin account"
    $displayName = "Cloud Admin | $inputName"
    
    $password = New-ComplexPassword

    $passwordProfile = @{
        Password = $password
        ForceChangePasswordNextSignIn = $true
    }

    $params = @{
        AccountEnabled = $true
        DisplayName = $displayName
        MailNickname = "admin-$userId"
        UserPrincipalName = $userPrincipalName
        PasswordProfile = $passwordProfile
        Department = "Cloud Admins"
    }

    try {
        $newUser = New-MgUser -BodyParameter $params -ErrorAction Stop
        $personaGroup = get-MgGroup -filter "displayName eq 'ca-persona-admins'" 
        New-MgGroupMember -GroupId $personaGroup.id -DirectoryObjectId $newUser.id
        Write-Host "Admin account created: $userPrincipalName" -ForegroundColor Green
        Write-Host "Display Name: $displayName" -ForegroundColor Green
        Write-Host "Temporary password: $password" -ForegroundColor Yellow
        Write-Host "Please ensure to change this password upon first login." -ForegroundColor Yellow
        Log-Message "Admin account created: $userPrincipalName."
        return $newUser
    }
    catch {
        Write-Host "Error creating admin account: $_" -ForegroundColor Red
        Log-Message "Error creating admin account: $_"
    }
}

# Function to check if user already has Global Admin role eligibility
function UserHasGlobalAdminEligibility {
    param (
        [Parameter(Mandatory=$true)]
        [string]$UserId,
        [string]$RoleDefinitionId
    )

    try {
        # Retrieve eligibility schedule requests for the user and role
        $eligibilityRequests = Get-MgRoleManagementDirectoryRoleEligibilityScheduleRequest -Filter "principalId eq '$UserId' and roleDefinitionId eq '$RoleDefinitionId'" -ErrorAction Stop
        if ($eligibilityRequests.Count -gt 0) {
            return $true
        }
        return $false
    }
    catch {
        Write-Host "Error retrieving eligibility schedule requests: $_" -ForegroundColor Red
        Log-Message "Error retrieving eligibility schedule requests for UserId: $UserId. Error: $_"
        return $false
    }
}
# Function to assign Global Administrator role eligibility using PIM
function Assign-GlobalAdminRoleEligibility {
    param (
        [Parameter(Mandatory=$true)]
        [string]$UserId
    )

    # Retrieve the RoleDefinitionId for Global Administrator dynamically
    try {
        # Fetch all role definitions matching "Global Administrator"
        $roleDefinition = Get-MgRoleManagementDirectoryRoleDefinition -Filter "displayName eq 'Global Administrator'" -ErrorAction Stop
        
        if ($roleDefinition.Count -eq 0) {
            Write-Host "Global Administrator role definition not found." -ForegroundColor Red
            Log-Message "Global Administrator role definition not found."
            return
        }

        # Use the first role definition ID found for 'Global Administrator'
        $globalAdminRoleDefinitionId = $roleDefinition.Id
        Write-Host "Global Administrator RoleDefinitionId: $globalAdminRoleDefinitionId" -ForegroundColor Green
        Log-Message "Global Administrator RoleDefinitionId retrieved: $globalAdminRoleDefinitionId."
    }
    catch {
        Write-Host "Error retrieving Global Administrator RoleDefinitionId: $_" -ForegroundColor Red
        Log-Message "Error retrieving Global Administrator RoleDefinitionId. Error: $_"
        return
    }

    # Assign role eligibility via PIM
    Add-GlobalAdminRoleEligibility -UserId $UserId -RoleDefinitionId $globalAdminRoleDefinitionId
}

# Function to add role eligibility with more detailed logging and error handling
function Add-GlobalAdminRoleEligibility {
    param (
        [Parameter(Mandatory=$true)]
        [string]$UserId,
        [string]$RoleDefinitionId
    )

    # Define schedule info
    $currentDateTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $expirationDateTime = (Get-Date).AddYears(1).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

    $params = @{
        Action = "adminAssign"
        Justification = "Assign Global Administrator eligibility to restricted user"
        RoleDefinitionId = $RoleDefinitionId
        DirectoryScopeId = "/"
        PrincipalId = $UserId
        ScheduleInfo = @{
            StartDateTime = $currentDateTime
            Expiration = @{
                Type = "AfterDateTime"
                EndDateTime = $expirationDateTime
            }
        }
    }

    try {
        # Check if the user already has eligibility
        $hasEligibility = UserHasGlobalAdminEligibility -UserId $UserId -RoleDefinitionId $RoleDefinitionId
        if ($hasEligibility) {
            Write-Host "User already has eligibility for the Global Administrator role. Skipping assignment." -ForegroundColor Yellow
            Log-Message "User with UserId: $UserId already has eligibility for Global Administrator role."
            return
        }

        # Create the eligibility schedule request
        New-MgRoleManagementDirectoryRoleEligibilityScheduleRequest -BodyParameter $params -ErrorAction Stop
        Write-Host "Global Administrator role eligibility assigned to user with ID $UserId." -ForegroundColor Green
        Log-Message "Global Administrator role eligibility assigned to user ID: $UserId."
    }
    catch {
        Write-Host "Error assigning Global Administrator role eligibility: $_" -ForegroundColor Red
        Log-Message "Error assigning Global Administrator role eligibility to user ID: $UserId. Error: $_"
    }
}


# Function to create or ensure two Break Glass accounts and assign role eligibility
function New-BreakGlassAccount {
    # Define the maximum number of BG accounts
    $maxBGAccounts = 2

    # Define the Department attribute for BG accounts
    $bgDepartment = "Break Glass Accounts"

    try {
        # Retrieve existing BG accounts
        $existingBGUsers = Get-MgUser -Filter "department eq '$bgDepartment'" -Select "id, displayName, userPrincipalName" -ErrorAction Stop

        $currentBGCount = $existingBGUsers.Count

        if ($currentBGCount -ge $maxBGAccounts) {
            Write-Host "There are already $currentBGCount Break Glass accounts. No additional accounts will be created." -ForegroundColor Yellow
            Log-Message "There are already $currentBGCount Break Glass accounts. No additional accounts will be created."

            # Assign role eligibility to existing BG accounts if not already assigned
            foreach ($bgUser in $existingBGUsers) {
                Assign-GlobalAdminRoleEligibility -UserId ([string]$bgUser.Id)
                $personaGroup = get-MgGroup -filter "displayName eq 'ca-breakglassaccounts'" 
                New-MgGroupMember -GroupId $personaGroup.id -DirectoryObjectId $bgUser.Id -ErrorAction SilentlyContinue
            }

            return
        }

        $mgAdminUser = Get-MgContext | Select-Object -ExpandProperty Account
        $tenantDomain = $mgAdminUser -split '@' | Select-Object -Last 1
        $bgToCreate = $maxBGAccounts - $currentBGCount

        for ($i = 1; $i -le $bgToCreate; $i++) {
            $bgAccountName = "bg$i"
            $randomString = New-RandomString
            $userPrincipalName = "$bgAccountName-$randomString@$tenantDomain"

            # Check if BG account with this UPN already exists
            $existingUser = Get-ExistingUser -UserPrincipalName $userPrincipalName
            if ($existingUser) {
                Write-Host "A Break Glass account with UPN $userPrincipalName already exists. Skipping creation of BG${i}." -ForegroundColor Yellow
                Log-Message "A Break Glass account with UPN $userPrincipalName already exists. Skipping creation of BG${i}."

                # Assign role eligibility if not already assigned
                Assign-GlobalAdminRoleEligibility -UserId ([string]$existingUser.Id)

                continue
            }

            # MailNickname is set as BG1, BG2, etc.
            $mailNickname = $bgAccountName

            $password = New-ComplexPassword

            $passwordProfile = @{
                Password = $password
                ForceChangePasswordNextSignIn = $false
            }

            $params = @{
                AccountEnabled = $true
                DisplayName = "Break Glass Account $i"
                MailNickname = $mailNickname
                UserPrincipalName = $userPrincipalName
                PasswordProfile = $passwordProfile
                Department = $bgDepartment
            }

            try {
                $newBGUser = New-MgUser -BodyParameter $params -ErrorAction Stop
                $personaGroup = get-MgGroup -filter "displayName eq 'ca-breakglassaccounts'" 
                New-MgGroupMember -GroupId $personaGroup.id -DirectoryObjectId $newBGUser.id
                Write-Host "Break Glass account created: $userPrincipalName" -ForegroundColor Green
                Write-Host "Password: $password" -ForegroundColor Yellow
                Write-Host "Please store this password securely." -ForegroundColor Yellow
                Log-Message "Break Glass account created: $userPrincipalName."

                # Assign Global Admin role eligibility via PIM
                Wait-Job -Name "CreateBGAccounts" -Timeout 5
                Write-Host "Assigning Global Administrator role eligibility to Break Glass account BG${i}..." -ForegroundColor Cyan
                Assign-GlobalAdminRoleEligibility -UserId ([string]$newBGUser.Id)
            }
            catch {
                Write-Host "Error creating Break Glass account BG${i}: $_" -ForegroundColor Red
                Log-Message "Error creating Break Glass account BG${i}: $_"
            }
        }

        # After creation, assign role eligibility to existing BG accounts if any
        foreach ($bgUser in $existingBGUsers) {
            Assign-GlobalAdminRoleEligibility -UserId ([string]$bgUser.Id)
        }
    }
    catch {
        Write-Host "Error retrieving existing Break Glass accounts: $_" -ForegroundColor Red
        Log-Message "Error retrieving existing Break Glass accounts: $_"
    }
}

# Main script logic
$choice = Read-Host "Create (A)dmin account or (B)reak Glass accounts? (A/B)"

if ($choice -eq "A") {
    $newUser = New-AdminAccount
    if ($newUser) {
        $isGlobalAdmin = Read-Host "Should this user be eligible for the Global Administrator role via PIM? (Y/N)"
        if ($isGlobalAdmin -eq "Y") {
            Assign-GlobalAdminRoleEligibility -UserId ([string]$newUser.Id)
        }
    }
}
elseif ($choice -eq "B") {
    New-BreakGlassAccount
}
else {
    Write-Host "Invalid choice. Please run the script again and choose A or B." -ForegroundColor Red
    Log-Message "Invalid choice entered: $choice"
}

```


### Automating Conditional Access Policies (No Marauder’s Map Needed) 🗺️

Now that your security groups are conjured and the Admin and Break Glass accounts are safely created, it’s time to automate those Conditional Access policies 🎯. But alas, we face some challenges! While we want admins to use **Phishing Resistant Tokens** (our most powerful protection spells 🪄), we also need a way for them to register their **FIDO2 keys** (because Passkeys are no ordinary charms 🔑).

The first hurdle: our **MFA campaign** doesn’t support asking for Passkeys/FIDO keys right away. So, we need a workaround to let admins use MFA or **Tap to Sign In** temporarily while they register their FIDO2 keys.

#### How to Solve This Conundrum 🧩

Instead of excluding these admins from our **Phishing Resistant** policy forever (that’s like leaving Hogwarts unprotected 🏰), we’ll create an **alternative authentication strength** for initial MFA. This allows first-time use with a manageable authentication method, and then users can register their FIDO2 keys or Passkeys via the authenticator app. Learn more about this in **Microsoft's guide on [Authentication Strength](https://learn.microsoft.com/en-gb/entra/identity/authentication/concept-authentication-strengths)**.

![Screenshot](assets/img/SecuringAdminAccess/authenticationStrengths.png)

#### Pro Tip:

> **⚠️ Always keep a break-glass account handy!** Configuring Conditional Access with code can be dangerous. Thankfully, this script creates policies without enabling them immediately. Consider it your safety net (or **Protego charm** 🛡️) before you apply the real protection! 🙃

### Key Conditional Access Policies for Admin Protection 🛡️

By leveraging **phishing-resistant** authentication (like FIDO2), **MFA**, and **session policies**, you establish secure, targeted access control for various apps and platforms. Some of the key policy types you’ll want to automate include:

- **Base Protection**: A general layer of security for all personas.
- **Identity Protection**: Risk-based sign-in protection.
- **Data and App Protection**: Enforce security on mobile platforms.
- **Attack Surface Reduction**: Prevent risky or unknown devices and platforms from accessing resources.

This structured approach ensures robust security across multiple layers, allowing your admins to work securely while gradually shifting them to the most secure authentication methods.

### Automating Conditional Access Policies with PowerShell 🧙‍♂️🔮

This spell automatically creates and applies the right Conditional Access policies based on each persona 🎯. By automating the process, your admins, employees, and guests can safely navigate your secure environment without manually casting every protection spell. 🛡️🔒

#### Conditional Access Creation Script ⚙️

For full details and to get the script, you can download it here: [Create-CAPolicies.ps1](https://raw.githubusercontent.com/Dikkekip/dikkekip.github.io/main/scripts/2024-07-29-SecuringAdminAccess/Create-CAPolicies.ps1)

![Screenshot](assets/img/SecuringAdminAccess/Create-Ca.png)
<!-- markdownlint-capture -->
<!-- markdownlint-disable -->
> **Note**: Due to the script's length, please refer to the script at the provided link.
{: .prompt-info }
<!-- markdownlint-restore -->

```powershell
# PowerShell script content
# Due to length, please refer to the script at the provided link.

# Define required modules
$requiredModules = @("microsoft.graph.authentication", "microsoft.graph.identity.signins", "microsoft.graph.groups")

# function to create a conditional access policy
function new-conditionalaccesspolicy {
    param (
        [hashtable]$policyparams
    )

    new-mgidentityconditionalaccesspolicy -bodyparameter $policyparams
}

$groups = Get-MgGroup -All | select displayname, id
function Get-GroupIdByName {
    param (
        [string]$groupName,
        [array]$groups
    )
    $group = $groups | Where-Object { $_.displayname -eq $groupName }
    return $group.id
}
# Define the policy parameters
# left out because of length


# Update IncludeUsers and ExcludeGroups with group IDs
foreach ($policy in $policies) {
    if ($policy.Conditions.Users.IncludeGroups) {
        $policy.Conditions.Users.IncludeGroups = $policy.Conditions.Users.IncludeGroups | ForEach-Object { Get-GroupIdByName -groupName $_ -groups $groups }
    }
    if ($policy.Conditions.Users.ExcludeGroups) {
        $policy.Conditions.Users.ExcludeGroups = $policy.Conditions.Users.ExcludeGroups | ForEach-Object { Get-GroupIdByName -groupName $_ -groups $groups }
    }
}

# Log file path
$logFilePath = ".\failed_policies.log"

# Retrieve existing policies
$existingPolicies = Get-MgIdentityConditionalAccessPolicy -All

# Apply the policies
foreach ($policy in $policies) {
    $existingPolicy = $existingPolicies | Where-Object { $_.DisplayName -eq $policy.DisplayName }
    
    if ($existingPolicy) {
        Write-Host "Policy $($policy.DisplayName) already exists. Checking settings..."
        # Compare settings (simplified comparison, adjust as needed)
        if ($existingPolicy.Conditions -ne $policy.Conditions -or $existingPolicy.State -ne $policy.State) {
            Write-Host "Policy $($policy.DisplayName) settings differ. Updating policy..."
            try {
                Update-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $existingPolicy.Id -BodyParameter $policy
            } catch {
                Write-Host "Failed to update policy $($policy.DisplayName)"
                Add-Content -Path $logFilePath -Value "Failed to update policy $($policy.DisplayName): $_"
            }
        } else {
            Write-Host "Policy $($policy.DisplayName) settings are identical. No update needed."
        }
    } else {
        Write-Host "Creating policy $($policy.DisplayName)"
        try {
            New-MgIdentityConditionalAccessPolicy -BodyParameter $policy
        } catch {
            Write-Host "Failed to create policy $($policy.DisplayName)"
            Add-Content -Path $logFilePath -Value "Failed to create policy $($policy.DisplayName): $_"
        }
    }
}
# disconnect from microsoft graph
disconnect-mggraph

```

### Conclusion: Mastering the Security Spellbook 📜✨

By leveraging **persona-based Conditional Access policies**, you ensure both a secure and user-friendly experience for your organization. And thanks to Claus Jespersen's framework 🧙‍♂️🔮, implementing these strategies has never been easier. Automating policies and groups with PowerShell ensures your defenses are consistently strong 🛡️, scaling effortlessly as your organization grows.

Stay tuned for more chapters in this security spellbook, where we’ll continue to dive into the magic of security automation. Until then, may your spells be strong, your MFA tokens unbreakable, and your admins wise! 🔮✨

**Accio Security!** 🧙‍♀️⚡

---

Feel free to reach out if you have any questions or need further guidance on implementing these magical security measures. Until next time, keep your wands at the ready and your systems secure! 🪄🔐