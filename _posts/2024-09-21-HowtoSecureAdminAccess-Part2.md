---
layout: post
title:  "How to Secure Admin Access! - Part 2"
date:   2024-09-21 10:00:00 +0530
comments: true
description: "Automating Persona-Based Conditional Access Policies"
categories: [Entra ID, Cloud Security, Access Management, Azure Automation, IT Security, Cloud Administration, Microsoft Azure, DevOps Practices]
tags: [Entra ID, Cloud Security, Access Management, Azure Automation, IT Security, Cloud Administration, Microsoft Azure]
image:
  path: /assets/img/1725962735025.gif
  src: /assets/img/1725962735025.gif
toc: true
---
---

## How to Secure Admin Access - Part 2: Automating Persona-Based Conditional Access Policies 🛡️✨

Welcome back, fellow IT wizards 🧙‍♂️🧙‍♀️, to our magical journey of securing admin access! In **Part 1**, we ventured into the realms of **Admin Access** and set the foundations for a secure kingdom. This time, we're diving into **Persona-Based Conditional Access Policies**—essentially enchanted wards 🧙‍♂️🔮 tailored to different roles within your organization. Instead of casting a generic **Protego Totalum** 🛡️ over everyone, we're going to fine-tune our spells (ahem, policies) based on role, access requirements, and risk levels.

For example, your mighty **Global Administrator** (think **Dumbledore of Entra ID**) needs stricter security enchantments than an average user just accessing coffee orders ☕📋.

### Why Persona-Based Policies Matter ⚖️

Not everyone in your organization needs the power of a **Nimbus 2000** 🧹. Some users, like HR employees handling sensitive data 🗂️, require extra protection, but it's nothing compared to what your **Global Administrators** need. That's where persona-based policies come in. Like casting a **Lumos** 💡 that’s bright enough to guide you but doesn’t blind anyone, these policies balance security and usability.

With these, you can require extra steps (think of MFA as a **magic incantation** 🧩) for high-risk users, while others breeze through securely. 🔐

### Persona Breakdown 🧙‍♂️📜

In the realm of Conditional Access, users fit into different personas, each getting a specific set of security spells tailored to their role:

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
<!-- markdownlint-restore --> Due to the script's length, please refer to the script at the provided link.


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

    # Function content continues...
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
# Left out because of length

foreach ($group in $groups) {
    New-AADGroup @group
}
```

This PowerShell script helps you create persona-based security groups for **admins**, **service accounts**, and **guests** from distant lands 🌍. Customize group types and membership rules to fit your unique wizarding (or organizational) needs 🏰✨.

### Creating Admin and Break Glass Accounts 🧙‍♂️🔐

Admins are like the **Masters of the Elder Wand** 🪄 in your organization—so they need extra layers of protection. Similarly, **Break Glass accounts** are your **emergency exit spells** 🧩, only used in dire situations when admin accounts might fail. The PowerShell script below ensures both types of accounts are secured with the proper magical safeguards 🛡️.

The script automates the creation of Admin accounts and Break Glass accounts, setting them up with strong passwords (no **Alohomora** here!) and assigning them appropriate roles and permissions, including **Global Administrator role eligibility** through Privileged Identity Management (PIM).

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

<!-- markdownlint-capture -->
<!-- markdownlint-disable -->
> **Note**: Due to the script's length, please refer to the script at the provided link.
{: .prompt-info }
<!-- markdownlint-restore --> Due to the script's length, please refer to the script at the provided link.

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

    # Function content continues...
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

> **⚠️ Always keep a Break Glass account handy!** Configuring Conditional Access with code can be dangerous. Thankfully, this script creates policies without enabling them immediately. Consider it your safety net (or **Protego charm** 🛡️) before you apply the real protection! 🙃

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
<!-- markdownlint-restore --> Due to the script's length, please refer to the script at the provided link.

```powershell
# PowerShell script content
# Due to length, please refer to the script at the provided link.

# Define required modules
$requiredModules = @("microsoft.graph.authentication", "microsoft.graph.identity.signins", "microsoft.graph.groups")

# Function to create a conditional access policy
function New-ConditionalAccessPolicy {
    param (
        [hashtable]$policyparams
    )

    New-MgIdentityConditionalAccessPolicy -BodyParameter $policyparams
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
# Left out because of length

# Apply the policies
foreach ($policy in $policies) {
    # Function content continues...
}

# Disconnect from Microsoft Graph
Disconnect-MgGraph
```

### Conclusion: Mastering the Security Spellbook 📜✨

By leveraging **persona-based Conditional Access policies**, you ensure both a secure and user-friendly experience for your organization. And thanks to Claus Jespersen's framework 🧙‍♂️🔮, implementing these strategies has never been easier. Automating policies and groups with PowerShell ensures your defenses are consistently strong 🛡️, scaling effortlessly as your organization grows.

Stay tuned for more chapters in this security spellbook, where we’ll continue to dive into the magic of security automation. Until then, may your spells be strong, your MFA tokens unbreakable, and your admins wise! 🔮✨

**Accio Security!** 🧙‍♀️⚡

---

Feel free to reach out if you have any questions or need further guidance on implementing these magical security measures. Until next time, keep your wands at the ready and your systems secure! 🪄🔐

---
