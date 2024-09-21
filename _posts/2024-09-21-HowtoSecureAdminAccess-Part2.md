## How to Secure Admin Access - Part 2: Automating Persona-Based Conditional Access Policies 🛡️✨

Welcome back, fellow IT wizards 🧙‍♂️🧙‍♀️, to our magical journey of securing admin access! This time, we're diving into **Persona-Based Conditional Access Policies**, which are essentially enchanted wards 🧙‍♂️🔮 tailored to different roles. Instead of casting a generic **Protego Totalum** 🛡️ over everyone, we're going to fine-tune our spells (ahem, policies) based on role, access requirements, and risk levels. 

For example, your mighty Global Administrator (think **Dumbledore of Entra ID**) needs stricter security enchantments than an average user just accessing coffee orders ☕📋.

### Why Persona-Based Policies Matter ⚖️

Not everyone in your organization needs the power of a **Nimbus 2000** 🏆. Some users, like HR employees handling sensitive data 🗂️, need extra protection, but it's nothing compared to what your **Global Administrators** need. That's where persona-based policies come in. Like casting a **Lumos** 💡 that’s bright enough to guide you but doesn’t blind anyone, these policies balance security and usability. 🌍

With these, you can require extra steps (think of MFA as a **magic incantation 🧩**) for high-risk users, while others breeze through securely. 🔐

### Persona Breakdown 🧙‍♂️📜

In this realm of Conditional Access, users fit into different personas, each getting a specific set of security spells tailored to their role:

- **ca-persona-admins**: High-privilege admins, needing **phishing-resistant MFA** 🛡️ (you don’t want your castle walls breached by a simple charm 🧙‍♂️).
- **ca-persona-global**: Global protection 🏰—applied universally to everyone. This is your foundation spell!
- **ca-persona-externals**: External contractors 🧳 get limited access, bounded by specific application policies 🔐.
- **ca-persona-guests**: Guests 🎓 (visiting from another realm) have light security, with restricted access to resources.
- **ca-persona-internals**: Regular employees 🧑‍💼 who need moderate protection (MFA) while accessing their day-to-day applications.
- **ca-persona-guestadmins**: Guests granted temporary **admin powers 🏆** (think students borrowing a professor's wand), requiring **Protego Maxima** 🛡️🛡️.
- **ca-persona-developers**: Developers 🧑‍💻 playing with sensitive environments 🔮, needing strict device compliance and MFA.
- **ca-persona-serviceaccounts**: Service accounts 🤖, often automated, require special protections like **managed identities** and token policies. (You don’t want these going rogue, like a Niffler chasing shiny tokens ✨🦡.)

### The Magical Framework from Claus Jespersen 🧙‍♂️💻

Claus Jespersen and his brilliant team have provided an excellent guide for implementing these persona-based policies. They crafted the **Conditional Access Framework**, built on **Zero Trust principles**, and it’s an absolute game-changer 🔐. This framework uses a clear naming convention for different personas, helping you manage policies and avoid potential conflicts. 

Claus's work includes an invaluable **[Excel Workbook](https://github.com/microsoft/ConditionalAccessforZeroTrustResources/raw/main/ConditionalAccessSamplePolicies/Microsoft%20Conditional%20Access%20for%20Zero%20trust%20persona%20based%20policies.xlsx)**, which provides a template for persona-based Conditional Access policies. Alongside this, the **[PDF guide](https://github.com/microsoft/ConditionalAccessforZeroTrustResources/blob/main/ConditionalAccessGovernanceAndPrinciplesforZeroTrust%20October%202023.pdf)** explains the governance and principles in great detail.

**Huge kudos to Claus** for making it easy to implement this in the real world! 🎉🔮

### Automating Persona Creation with PowerShell 🪄💻

Managing security spells (oops, I mean policies) can be time-consuming. Here’s where a bit of automation magic via PowerShell ⚡💻 can save the day. Below is a spell (aka script 🧑‍💻) that automates the creation of security groups for your personas.

#### PowerShell Script for Creating Security Groups ⚙️
scripts\2024-07-29-SecuringAdminAccess\Create-groups.ps1
Group Creation Script: [Create-groups.ps1](https://raw.githubusercontent.com/Dikkekip/dikkekip.github.io/main/scripts/2024-07-29-SecuringAdminAccess/Create-groups.ps1)

![Screenshot](assets/img/SecuringAdminAccess/Screenshot%202024-09-21%20142118.png)

```powershell
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

$groups = @(
    @{
        DisplayName = "ca-persona-corpserviceaccounts-exclusions"
        Description = "Exclusion group for corporate service accounts in Conditional Access policies. Used to exempt specific service accounts from certain security controls while maintaining overall security posture."
        MailNickname = "ca-persona-corpserviceaccounts-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-internals-appprotection-exclusions"
        Description = "Exclusion group for internal users exempt from application protection policies. Allows for flexibility in app protection enforcement for specific internal scenarios."
        MailNickname = "ca-persona-internals-appprotection-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-admins-compliance-exclusions"
        Description = "Exclusion group for administrators exempt from certain compliance-related Conditional Access policies. Enables administrative flexibility while maintaining overall compliance standards."
        MailNickname = "ca-persona-admins-compliance-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-guests-baseprotection-exclusions"
        Description = "Exclusion group for guest users exempt from base protection policies. Allows for tailored security controls for specific guest user scenarios."
        MailNickname = "ca-persona-guests-baseprotection-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-externals-identityprotection-exclusions"
        Description = "Exclusion group for external users exempt from identity protection policies. Enables customized identity security measures for specific external collaborators."
        MailNickname = "ca-persona-externals-identityprotection-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-azureserviceaccounts-exclusions"
        Description = "Exclusion group for Azure service accounts exempt from certain Conditional Access policies. Ensures uninterrupted service operations while maintaining security."
        MailNickname = "ca-persona-azureserviceaccounts-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-guests-compliance-exclusions"
        Description = "Exclusion group for guest users exempt from compliance-related Conditional Access policies. Allows for necessary exceptions in guest user compliance requirements."
        MailNickname = "ca-persona-guests-compliance-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-azureserviceaccounts"
        Description = "Group for Azure service accounts subject to specific Conditional Access policies. Ensures appropriate security measures for automated Azure services and processes."
        MailNickname = "ca-persona-azureserviceaccounts"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-developers-dataprotection-exclusions"
        Description = "Exclusion group for developers exempt from certain data protection policies. Allows for development flexibility while maintaining overall data security standards."
        MailNickname = "ca-persona-developers-dataprotection-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-developers-attacksurfacereduction-exclusions"
        Description = "Exclusion group for developers exempt from specific attack surface reduction policies. Enables necessary development activities while managing security risks."
        MailNickname = "ca-persona-developers-attacksurfacereduction-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-workloadidentities-exclusions"
        Description = "Exclusion group for workload identities exempt from certain Conditional Access policies. Allows for tailored security controls for specific automated processes and services."
        MailNickname = "ca-persona-workloadidentities-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-admins-baseprotection-exclusions"
        Description = "Exclusion group for administrators exempt from base protection policies. Enables administrative flexibility while maintaining core security standards."
        MailNickname = "ca-persona-admins-baseprotection-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-microsoft365serviceaccounts"
        Description = "Group for Microsoft 365 service accounts subject to specific Conditional Access policies. Ensures appropriate security measures for M365 automated services and processes."
        MailNickname = "ca-persona-microsoft365serviceaccounts"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-externals"
        Description = "Group for external users subject to specific Conditional Access policies. Ensures appropriate security measures for external collaborators and partners."
        MailNickname = "ca-persona-externals"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-guestadmins-baseprotection-exclusions"
        Description = "Exclusion group for guest administrators exempt from base protection policies. Allows for necessary administrative actions by trusted external partners."
        MailNickname = "ca-persona-guestadmins-baseprotection-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-externals-appprotection-exclusions"
        Description = "Exclusion group for external users exempt from application protection policies. Allows for flexibility in app protection enforcement for specific external collaboration scenarios."
        MailNickname = "ca-persona-externals-appprotection-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-internals-baseprotection-exclusions"
        Description = "Exclusion group for internal users exempt from base protection policies. Enables flexibility for specific internal user scenarios while maintaining overall security."
        MailNickname = "ca-persona-internals-baseprotection-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-internals-identityprotection-exclusions"
        Description = "Exclusion group for internal users exempt from identity protection policies. Allows for customized identity security measures in specific internal scenarios."
        MailNickname = "ca-persona-internals-identityprotection-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-internals-dataprotection-exclusions"
        Description = "Exclusion group for internal users exempt from certain data protection policies. Enables flexibility in data handling for specific internal processes while maintaining overall data security."
        MailNickname = "ca-persona-internals-dataprotection-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-global-attacksurfacereduction-exclusions"
        Description = "Global exclusion group for users exempt from attack surface reduction policies. Allows for necessary exceptions across the organization while managing overall security posture."
        MailNickname = "ca-persona-global-attacksurfacereduction-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-guests-identityprotection-exclusions"
        Description = "Exclusion group for guest users exempt from identity protection policies. Enables customized identity security measures for specific guest user scenarios."
        MailNickname = "ca-persona-guests-identityprotection-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-internals"
        Description = "Group for internal users subject to specific Conditional Access policies. Ensures appropriate security measures for employees and internal stakeholders."
        MailNickname = "ca-persona-internals"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-guestadmins"
        Description = "Group for guest administrators subject to specific Conditional Access policies. Ensures appropriate security measures for external partners with administrative privileges."
        MailNickname = "ca-persona-guestadmins"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-guestadmins-compliance-exclusions"
        Description = "Exclusion group for guest administrators exempt from compliance-related Conditional Access policies. Allows for necessary administrative actions by trusted external partners while maintaining overall compliance."
        MailNickname = "ca-persona-guestadmins-compliance-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-admins-dataprotection-exclusions"
        Description = "Exclusion group for administrators exempt from certain data protection policies. Enables administrative flexibility in data handling while maintaining overall data security standards."
        MailNickname = "ca-persona-admins-dataprotection-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-guests-attacksurfacereduction-exclusions"
        Description = "Exclusion group for guest users exempt from attack surface reduction policies. Allows for necessary exceptions in guest user scenarios while managing security risks."
        MailNickname = "ca-persona-guests-attacksurfacereduction-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-guestadmins-identityprotection-exclusions"
        Description = "Exclusion group for guest administrators exempt from identity protection policies. Enables customized identity security measures for specific external administrative scenarios."
        MailNickname = "ca-persona-guestadmins-identityprotection-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-admins-identityprotection-exclusions"
        Description = "Exclusion group for administrators exempt from identity protection policies. Allows for customized identity security measures in specific administrative scenarios."
        MailNickname = "ca-persona-admins-identityprotection-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-guests"
        Description = "Group for guest users subject to specific Conditional Access policies. Ensures appropriate security measures for external users with limited access."
        MailNickname = "ca-persona-guests"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-admins-attacksurfacereduction-exclusions"
        Description = "Exclusion group for administrators exempt from attack surface reduction policies. Enables necessary administrative activities while managing overall security risks."
        MailNickname = "ca-persona-admins-attacksurfacereduction-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-developers-baseprotection-exclusions"
        Description = "Exclusion group for developers exempt from base protection policies. Allows for development flexibility while maintaining core security standards."
        MailNickname = "ca-persona-developers-baseprotection-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-breakglassaccounts"
        Description = "Group for break glass accounts with special Conditional Access considerations. Ensures emergency access to critical systems while maintaining security and auditability."
        MailNickname = "ca-breakglassaccounts"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-admins"
        Description = "Group for administrators subject to specific Conditional Access policies. Ensures appropriate security measures for users with elevated privileges across the organization."
        MailNickname = "ca-persona-admins"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-developers-appprotection-exclusions"
        Description = "Exclusion group for developers exempt from application protection policies. Allows for development flexibility in app testing and deployment scenarios."
        MailNickname = "ca-persona-developers-appprotection-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-corpserviceaccounts"
        Description = "Group for corporate service accounts subject to specific Conditional Access policies. Ensures appropriate security measures for automated internal processes and services."
        MailNickname = "ca-persona-corpserviceaccounts"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-onpremisesserviceaccounts"
        Description = "Group for on-premises service accounts subject to specific Conditional Access policies. Ensures appropriate security measures for automated processes in hybrid environments."
        MailNickname = "ca-persona-onpremisesserviceaccounts"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-developers-identityprotection-exclusions"
        Description = "Exclusion group for developers exempt from identity protection policies. Enables customized identity security measures for specific development and testing scenarios."
        MailNickname = "ca-persona-developers-identityprotection-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-externals-baseprotection-exclusions"
        Description = "Exclusion group for external users exempt from base protection policies. Allows for tailored security controls in specific external collaboration scenarios."
        MailNickname = "ca-persona-externals-baseprotection-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-global-baseprotection-exclusions"
        Description = "Global exclusion group for users exempt from base protection policies. Allows for necessary exceptions across the organization while maintaining overall security posture."
        MailNickname = "ca-persona-global-baseprotection-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-workloadidentities"
        Description = "Group for workload identities subject to specific Conditional Access policies. Ensures appropriate security measures for automated processes and services across the organization."
        MailNickname = "ca-persona-workloadidentities"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-externals-dataprotection-exclusions"
        Description = "Exclusion group for external users exempt from data protection policies. Enables flexibility in data handling for specific external collaboration scenarios while maintaining overall data security."
        MailNickname = "ca-persona-externals-dataprotection-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-guests-dataprotection-exclusions"
        Description = "Exclusion group for guest users exempt from data protection policies. Allows for necessary exceptions in guest user data handling while maintaining overall data security standards."
        MailNickname = "ca-persona-guests-dataprotection-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-guestusersasdynamicgroup"
        Description = "Dynamic group for guest users, automatically populated based on user type. Used for applying consistent Conditional Access policies to all guest accounts."
        MailNickname = "ca-persona-guestusersasdynamicgroup"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @("DynamicMembership")
        MembershipRule = "(user.objectId -ne null) -and (user.userType -eq `"Guest`")"
        MembershipRuleProcessingState = "On"
    },
    @{
        DisplayName = "ca-persona-internals-attacksurfacereduction-exclusions"
        Description = "Exclusion group for internal users exempt from attack surface reduction policies. Enables necessary exceptions for specific internal processes while managing overall security risks."
        MailNickname = "ca-persona-internals-attacksurfacereduction-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-global"
        Description = "Global group for all users subject to general Conditional Access policies. Ensures a baseline of security measures across the entire organization."
        MailNickname = "ca-persona-global"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-guestadmins-attacksurfacereduction-exclusions"
        Description = "Exclusion group for guest administrators exempt from attack surface reduction policies. Allows for necessary administrative actions by trusted external partners while managing security risks."
        MailNickname = "ca-persona-guestadmins-attacksurfacereduction-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-admins-appprotection-exclusions"
        Description = "Exclusion group for administrators exempt from application protection policies. Enables administrative flexibility in app management and testing scenarios."
        MailNickname = "ca-persona-admins-appprotection-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-externals-attacksurfacereduction-exclusions"
        Description = "Exclusion group for external users exempt from attack surface reduction policies. Allows for necessary exceptions in external collaboration scenarios while managing security risks."
        MailNickname = "ca-persona-externals-attacksurfacereduction-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-developers"
        Description = "Group for developers subject to specific Conditional Access policies. Ensures appropriate security measures for users involved in software development and testing activities."
        MailNickname = "ca-persona-developers"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "PLT-Licence-EntraSuite"
        Description = "Licensing group for Microsoft Entra Suite. Members of this group are automatically assigned the Entra Suite license, providing access to advanced identity and access management features."
        MailNickname = "PLT-Licence-EntraSuite"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "PLT-Licence-GitHub"
        Description = "Licensing group for GitHub. Members of this group are automatically assigned the appropriate GitHub license, enabling access to version control and collaboration tools."
        MailNickname = "PLT-LicenceGitHub"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    }
    @{
        DisplayName = "ca-persona-corpserviceaccounts-exclusions"
        Description = "Exclusion group for corporate service accounts in Conditional Access policies"
        MailNickname = "ca-persona-corpserviceaccounts-exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },
    @{
        DisplayName = "ca-persona-developers"
        Description = "Conditional Access group for developers, used to apply specific access policies and controls"
        MailNickname = "ca-persona-developers"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @()
    },   
    @{
        DisplayName = "ca-persona-Admins-PhishingResistant-Enabled"
        Description = "Dynamic group for administrators required to use phishing-resistant authentication methods"
        MailNickname = "ca-persona-Admins-PhishingResistant-Enabled"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @("DynamicMembership")
        MembershipRule = "(user.userType -eq `"Member`") and (user.userPrincipalName -match `"admin`") and (user.department -match `"Cloud Admin`")"
        MembershipRuleProcessingState = "On"
    }
)


foreach ($group in $groups) {
    New-AADGroup @group
}
```

This PowerShell script helps you create persona-based security groups for **admins**, **service accounts**, and **guests** from distant lands 🌍. Customize group types and membership rules to fit your unique wizarding (or organizational) needs 🏰✨.
Sure! Here's a wizarding-style update for the **Creating Admin and Break Glass Accounts** section:

### Creating Admin and Break Glass Accounts 🧙‍♂️🔐

Admins are like the **Masters of the Elder Wand** 🪄 in your organization—so they need extra layers of protection. Similarly, Break Glass accounts are your **emergency exit spells** 🧩, only used in dire situations when admin accounts might fail. The PowerShell script below ensures both types of accounts are secured with the proper magical safeguards 🛡️.

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

- If your main admin accounts are locked out, Break Glass accounts are your fallback. This script ensures their **Global Admin** role is always accessible, even when regular systems falter. They’re like magical safeguards with minimal everyday usage, but they’ll save you when things get chaotic! 🛡️✨

#### **Admin Accounts** 🏰🔐

```powershell	
# Define required modules
$requiredModules = @("Microsoft.Graph.Users", "Microsoft.Graph.Identity.Governance", "Microsoft.Graph.Groups")

# Define a log file path
$logFile = "$PSScriptRoot\UserProvisioning.log"

# Function to log messages
function Log-Message {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $logFile -Append
}

# Function to install and import modules
function Import-RequiredModules {
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$Modules
    )

    foreach ($module in $Modules) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            Write-Host "Module $module not found. Installing..." -ForegroundColor Yellow
            Log-Message "Module $module not found. Installing..."
            try {
                Install-Module -Name $module -Scope CurrentUser -Force -ErrorAction Stop
                Write-Host "Module $module installed successfully." -ForegroundColor Green
                Log-Message "Module $module installed successfully."
            }
            catch {
                Write-Host "Failed to install module $module. Error: $_" -ForegroundColor Red
                Log-Message "Failed to install module $module. Error: $_"
                exit
            }
        }
        try {
            Import-Module $module -ErrorAction Stop
            Write-Host "Module $module imported successfully." -ForegroundColor Green
            Log-Message "Module $module imported successfully."
        }
        catch {
            Write-Host "Failed to import module $module. Error: $_" -ForegroundColor Red
            Log-Message "Failed to import module $module. Error: $_"
            exit
        }
    }
}

# Import required modules
Import-RequiredModules -Modules $requiredModules

# Connect to Microsoft Graph if not already connected
if (-not (Get-MgContext)) {
    try {
        Connect-MgGraph -Scopes "User.ReadWrite.All", "RoleManagement.ReadWrite.Directory", "Group.ReadWrite.All" -ErrorAction Stop
        Write-Host "Connected to Microsoft Graph successfully." -ForegroundColor Green
        Log-Message "Connected to Microsoft Graph successfully."
    }
    catch {
        Write-Host "Failed to connect to Microsoft Graph. Error: $_" -ForegroundColor Red
        Log-Message "Failed to connect to Microsoft Graph. Error: $_"
        exit
    }
}

# Function to generate a complex password
function New-ComplexPassword {
    $uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".ToCharArray()
    $lowercase = "abcdefghijklmnopqrstuvwxyz".ToCharArray()
    $number = "0123456789".ToCharArray()
    $special = "!@#$%^&*()_+-=[]{}|;:,.<>?".ToCharArray()

    $password = @(
        ($uppercase | Get-Random -Count 2) -join ''
        ($lowercase | Get-Random -Count 5) -join ''
        ($number | Get-Random -Count 2) -join ''
        ($special | Get-Random -Count 2) -join ''
    ) -join ''

    # Shuffle the password
    $passwordArray = $password.ToCharArray()
    $passwordArray = $passwordArray | Sort-Object {Get-Random}
    $password = -join $passwordArray

    return $password
}

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

<!-- markdownlint-capture -->
<!-- markdownlint-disable -->
#### Pro Tip:
> **⚠️ Always keep a break-glass account handy!** Configuring Conditional Access with code can be dangerous. Thankfully, this script creates policies without enabling them immediately. Consider it your safety net (or **Protego charm** 🛡️) before you apply the real protection! 🙃
{: .prompt-warning }
<!-- markdownlint-restore -->
---

### Conditional Access Policies Overview 🔐

Once your security groups are in place and the admins and Break Glass accounts are created, it’s time to automate the Conditional Access policies 🎯. These policies form a **Conditional Access framework** to manage security across different personas (e.g., **Admins**, **Internals**, **Externals**, etc.).

The challenge arises because we want all admins to use **Phishing Resistant Tokens**, but they still need a way to register their FIDO2 keys. Since the current **MFA registration campaigns** don’t allow asking for FIDO keys upfront, we need a temporary workaround. Here’s how we’ll tackle this conundrum:

1. **Create an alternative authentication strength** that allows admins to use **MFA** or **Tap to Sign In** for first-time use.
2. **Exclude** these admins temporarily from the Phishing Resistant policy.
3. **Allow them to register their FIDO2 key** or **Passkey** in the authenticator app.

Once this initial setup is complete, the policy can be re-applied to enforce phishing-resistant tokens without permanent exclusions.

### Key Conditional Access Policies for Admin Protection 🛡️

By leveraging **phishing-resistant** authentication (like FIDO2), **MFA**, and **session policies**, you establish secure, targeted access control for various apps and platforms. Some of the key policy types you’ll want to automate include:

- **Base Protection**: A general layer of security for all personas.
- **Identity Protection**: Risk-based sign-ins protection.
- **Data and App Protection**: Enforce security on mobile platforms.
- **Attack Surface Reduction**: Prevent risky or unknown devices and platforms from accessing resources.

This structured approach ensures robust security across multiple layers, allowing your admins to work securely while gradually shifting them to the most secure authentication methods.

### Automating Conditional Access Policies with PowerShell 🧙‍♂️🔮
This spell automatically creates and applies the right Conditional Access policies based on each persona 🎯. By automating the process, your admins, employees, and guests can safely navigate your secure environment without manually casting every protection spell. 🛡️🔒
#### Conditional Access Creation Script ⚙️
For full details and to get the script, you can download it here: [Create-Users.ps1](https://raw.githubusercontent.com/Dikkekip/dikkekip.github.io/main/scripts/2024-07-29-SecuringAdminAccess/Create-CAPolicies.ps1)
![Screenshot](assets/img/SecuringAdminAccess/Create-Ca.png)

```powershell
# Define required modules
$requiredModules = @("microsoft.graph.authentication", "microsoft.graph.identity.signins", "microsoft.graph.groups")

# Define a log file path
$logFile = "$PSScriptRoot\UserProvisioning.log"

# Function to log messages
function Log-Message {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $logFile -Append
}

# Function to install and import modules
function Import-RequiredModules {
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$Modules
    )

    foreach ($module in $Modules) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            Write-Host "Module $module not found. Installing..." -ForegroundColor Yellow
            Log-Message "Module $module not found. Installing..."
            try {
                Install-Module -Name $module -Scope CurrentUser -Force -ErrorAction Stop
                Write-Host "Module $module installed successfully." -ForegroundColor Green
                Log-Message "Module $module installed successfully."
            }
            catch {
                Write-Host "Failed to install module $module. Error: $_" -ForegroundColor Red
                Log-Message "Failed to install module $module. Error: $_"
                exit
            }
        }
        try {
            Import-Module $module -ErrorAction Stop
            Write-Host "Module $module imported successfully." -ForegroundColor Green
            Log-Message "Module $module imported successfully."
        }
        catch {
            Write-Host "Failed to import module $module. Error: $_" -ForegroundColor Red
            Log-Message "Failed to import module $module. Error: $_"
            exit
        }
    }
}
# d4ebce55-015a-49b5-a083-c84d1797ae8c intune enrollment

# Import required modules
Import-RequiredModules -Modules $requiredModules

# Connect to Microsoft Graph if not already connected or if the required scopes are not present
$requiredScopes = @("Application.Read.All", "Policy.ReadWrite.ConditionalAccess")
$currentContext = Get-MgContext

if (-not $currentContext -or ($currentContext.Scopes -ne $null -and $requiredScopes | Where-Object { $_ -notin $currentContext.Scopes })) {
    try {
        Connect-MgGraph -Scopes $requiredScopes -ErrorAction Stop
        Write-Host "Connected to Microsoft Graph successfully with required scopes." -ForegroundColor Green
        Log-Message "Connected to Microsoft Graph successfully with required scopes."
    }
    catch {
        Write-Host "Failed to connect to Microsoft Graph. Error: $_" -ForegroundColor Red
        Log-Message "Failed to connect to Microsoft Graph. Error: $_"
        exit
    }
}

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


# create conditional access policies
$policies = @(
    @{
        DisplayName = "CA001-Global-BaseProtection-AllApps-AnyPlatform-BlockNonPersonas"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeUsers = @("All")
                ExcludeGroups = @(
                    "ca-Persona-AzureServiceAccounts",
                    "ca-Persona-GuestAdmins",
                    "ca-Persona-Guests",
                    "ca-Persona-CorpServiceAccounts",
                    "ca-Persona-Externals",
                    "ca-Persona-Admins",
                    "ca-BreakGlassAccounts",
                    "ca-Persona-Global-BaseProtection-Exclusions",
                    "ca-Persona-Microsoft365ServiceAccounts",
                    "ca-Persona-Internals"
                )
            }
            Platforms = @{
                IncludePlatforms = @("all")
            }
        }
        GrantControls = @{
            BuiltInControls = @("block")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA002-Global-AttackSurfaceReduction-VariousApps-AnyPlatform-Block"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("None")
            }
            Users = @{
                IncludeUsers = @("All")
            }
            Platforms = @{
                IncludePlatforms = @("all")
            }
        }
        GrantControls = @{
            BuiltInControls = @("mfa")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA100-Admins-BaseProtection-AllApps-AnyPlatform-MFAANDCompliant"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
                ExcludeApplications = @("0000000a-0000-0000-c000-000000000000")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Admins")
                ExcludeGroups = @(
                    "ca-BreakGlassAccounts",
                    "ca-Persona-Admins-BaseProtection-Exclusions",
                    "ca-Persona-Microsoft365ServiceAccounts",
                    "ca-Persona-AzureServiceAccounts",
                    "ca-Persona-CorpServiceAccounts"
                )
            }
        }
        GrantControls = @{
            BuiltInControls = @("mfa", "compliantDevice")
            Operator = "AND"
        }
    },
    @{
        DisplayName = "CA102-Admins-IdentityProtection-AllApps-AnyPlatform-MFAandPWDforMediumandHighUserRisk"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Admins")
                ExcludeGroups = @(
                    "ca-Persona-Microsoft365ServiceAccounts",
                    "ca-Persona-AzureServiceAccounts",
                    "ca-BreakGlassAccounts",
                    "ca-Persona-Admins-IdentityProtection-Exclusions",
                    "ca-Persona-CorpServiceAccounts"
                )
            }
            UserRiskLevels = @("high", "medium")
        }
        GrantControls = @{
            BuiltInControls = @("mfa", "passwordChange")
            Operator = "AND"
        }
    },
    @{
        DisplayName = "CA103-Admins-IdentityProtection-AllApps-AnyPlatform-MFAforMediumandHighSignInRisk"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Admins")
                ExcludeGroups = @(
                    "ca-BreakGlassAccounts",
                    "ca-Persona-Microsoft365ServiceAccounts",
                    "ca-Persona-AzureServiceAccounts",
                    "ca-Persona-Admins-IdentityProtection-Exclusions",
                    "ca-Persona-CorpServiceAccounts"
                )
            }
            SignInRiskLevels = @("high", "medium")
        }
        GrantControls = @{
            BuiltInControls = @("mfa")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA104-Admins-IdentityProtection-AllApps-AnyPlatform-BlockLegacyAuth"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("exchangeActiveSync", "other")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Admins")
                ExcludeGroups = @(
                    "ca-BreakGlassAccounts",
                    "ca-Persona-Admins-IdentityProtection-Exclusions"
                )
            }
            Platforms = @{
                IncludePlatforms = @("all")
            }
        }
        GrantControls = @{
            BuiltInControls = @("block")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA105-Admins-AppProtection-MicrosoftIntuneEnrollment-AnyPlatform-MFA"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("0000000a-0000-0000-c000-000000000000")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Admins")
                ExcludeGroups = @(
                    "ca-BreakGlassAccounts",
                    "ca-Persona-Microsoft365ServiceAccounts",
                    "ca-Persona-AzureServiceAccounts",
                    "ca-Persona-Admins-AppProtection-Exclusions",
                    "ca-Persona-CorpServiceAccounts"
                )
            }
            Platforms = @{
                IncludePlatforms = @("all")
            }
        }
        GrantControls = @{
            BuiltInControls = @("mfa")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA106-Admins-DataProtection-AllApps-iOSorAndroid-ClientAppandAPP"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("Office365")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Admins")
                ExcludeGroups = @(
                    "ca-BreakGlassAccounts",
                    "ca-Persona-Admins-DataProtection-Exclusions",
                    "ca-Persona-Microsoft365ServiceAccounts",
                    "ca-Persona-AzureServiceAccounts",
                    "ca-Persona-CorpServiceAccounts"
                )
            }
            Platforms = @{
                IncludePlatforms = @("android", "iOS")
            }
        }
        GrantControls = @{
            BuiltInControls = @("approvedApplication", "compliantApplication")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA107-Admins-DataProtection-AllApps-AnyPlatform-SessionPolicy"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Admins")
                ExcludeGroups = @(
                    "ca-BreakGlassAccounts",
                    "ca-Persona-Admins-DataProtection-Exclusions",
                    "ca-Persona-AzureServiceAccounts",
                    "ca-Persona-Microsoft365ServiceAccounts",
                    "ca-Persona-CorpServiceAccounts"
                )
            }
        }
        SessionControls = @{
            PersistentBrowser = @{
                IsEnabled = $true
                Mode = "never"
            }
            SignInFrequency = @{
                IsEnabled = $true
                Type = "hours"
                Value = 4
            }
        }
    },
    @{
        DisplayName = "CA108-Admins-AttackSurfaceReduction-AllApps-AnyPlatform-BlockUnknownPlatforms"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Admins")
                ExcludeGroups = @(
                    "ca-BreakGlassAccounts",
                    "ca-Persona-Microsoft365ServiceAccounts",
                    "ca-Persona-AzureServiceAccounts",
                    "ca-Persona-Admins-AttackSurfaceReduction-Exclusions",
                    "ca-Persona-CorpServiceAccounts"
                )
            }
            Platforms = @{
                IncludePlatforms = @("all")
                ExcludePlatforms = @("android", "iOS", "windows", "windowsPhone", "macOS", "linux")
            }
        }
        GrantControls = @{
            BuiltInControls = @("block")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA109-Admins-BaseProtection-AllApps-AnyPlatform-PhishingResistant"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
                ExcludeApplications = @("0000000a-0000-0000-c000-000000000000")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Admins")
                ExcludeGroups = @(
                    "ca-BreakGlassAccounts",
                    "ca-Persona-Admins-BaseProtection-Exclusions",
                    "ca-Persona-Microsoft365ServiceAccounts",
                    "ca-Persona-AzureServiceAccounts",
                    "ca-Persona-CorpServiceAccounts",
                    "ca-persona-admins-PhishingResistant-Exclusions"
                )
            }
        }
        GrantControls = @{
            operator = "AND"
            builtInControls = @()
            authenticationStrength = @{
                id = "00000000-0000-0000-0000-000000000004"
            }
        }
    },
    @{
        DisplayName = "CA110-Admins-BaseProtection-AllApps-AnyPlatform-TapFirstTimeUse"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
                ExcludeApplications = @("0000000a-0000-0000-c000-000000000000")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Admins")
                ExcludeGroups = @(
                    "ca-BreakGlassAccounts",
                    "ca-Persona-Admins-BaseProtection-Exclusions",
                    "ca-Persona-Microsoft365ServiceAccounts",
                    "ca-Persona-AzureServiceAccounts",
                    "ca-Persona-CorpServiceAccounts",
                    "ca-persona-Admins-PhishingResistant-Enabled"
                )
            }
        }
        GrantControls = @{
            operator = "AND"
            builtInControls = @()
            authenticationStrength = @{
                id = "00000000-0000-0000-0000-000000000004"
            }
        }
    },
    @{
        DisplayName = "CA200-Internals-BaseProtection-AllApps-AnyPlatform-CompliantorAADHJ"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
                ExcludeApplications = @("0000000a-0000-0000-c000-000000000000")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Internals")
                ExcludeGroups = @("ca-BreakGlassAccounts", "ca-Persona-Internals-BaseProtection-Exclusions")
            }
            Platforms = @{
                IncludePlatforms = @("all")
            }
        }
        GrantControls = @{
            BuiltInControls = @("compliantDevice", "domainJoinedDevice")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA202-Internals-IdentityProtection-AllApps-AnyPlatform-MFAandPWDforHighUserRisk"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Internals")
                ExcludeGroups = @("ca-BreakGlassAccounts", "ca-Persona-Internals-IdentityProtection-Exclusions")
            }
            UserRiskLevels = @("high")
        }
        GrantControls = @{
            BuiltInControls = @("mfa", "passwordChange")
            Operator = "AND"
        }
    },
    @{
        DisplayName = "CA203-Internals-IdentityProtection-AllApps-AnyPlatform-MFAforHighSignInRisk"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Internals")
                ExcludeGroups = @("ca-BreakGlassAccounts", "ca-Persona-Internals-IdentityProtection-Exclusions")
            }
            Platforms = @{
                IncludePlatforms = @("all")
            }
            SignInRiskLevels = @("high")
        }
        GrantControls = @{
            BuiltInControls = @("mfa")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA204-Internals-IdentityProtection-AllApps-AnyPlatform-BlockLegacyAuth"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("exchangeActiveSync", "other")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Internals")
                ExcludeGroups = @("ca-BreakGlassAccounts", "ca-Persona-Internals-IdentityProtection-Exclusions")
            }
            Platforms = @{
                IncludePlatforms = @("all")
            }
        }
        GrantControls = @{
            BuiltInControls = @("block")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA205-Internals-AppProtection-MicrosoftIntuneEnrollment-AnyPlatform-MFA"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("0000000a-0000-0000-c000-000000000000")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Internals")
                ExcludeGroups = @("ca-BreakGlassAccounts", "ca-Persona-Internals-AppProtection-Exclusions")
            }
            Platforms = @{
                IncludePlatforms = @("all")
            }
        }
        GrantControls = @{
            BuiltInControls = @("mfa")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA206-Internals-DataandAppProtection-AllApps-iOSorAndroid-ClientAppORAPP"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("Office365")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Internals")
                ExcludeGroups = @("ca-BreakGlassAccounts", "ca-Persona-Internals-AppProtection-Exclusions", "ca-Persona-Internals-DataProtection-Exclusions")
            }
            Platforms = @{
                IncludePlatforms = @("android", "iOS")
            }
        }
        GrantControls = @{
            BuiltInControls = @("approvedApplication", "compliantApplication")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA207-Internals-AttackSurfaceReduction-AllApps-AnyPlatform-BlockUnknownPlatforms"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Internals")
            }
            Platforms = @{
                IncludePlatforms = @("all")
                ExcludePlatforms = @("android", "iOS", "windows", "macOS", "linux")
            }
        }
        GrantControls = @{
            BuiltInControls = @("block")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA300-Externals-BaseProtection-AllApps-AnyPlatform-CompliantorAADHJ"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
                ExcludeApplications = @("0000000a-0000-0000-c000-000000000000")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Externals")
                ExcludeGroups = @("ca-BreakGlassAccounts", "ca-Persona-Externals-BaseProtection-Exclusions")
            }
            Platforms = @{
                IncludePlatforms = @("all")
            }
        }
        GrantControls = @{
            BuiltInControls = @("compliantDevice", "domainJoinedDevice")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA302-Externals-IdentityProtection-AllApps-AnyPlatform-MFAandPWDforHighUserRisk"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Externals")
                ExcludeGroups = @("ca-BreakGlassAccounts", "ca-Persona-Externals-IdentityProtection-Exclusions")
            }
            UserRiskLevels = @("high")
        }
        GrantControls = @{
            BuiltInControls = @("mfa", "passwordChange")
            Operator = "AND"
        }
    },
    @{
        DisplayName = "CA303-Externals-IdentityProtection-AllApps-AnyPlatform-MFAforHighSignInRisk"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Externals")
                ExcludeGroups = @("ca-BreakGlassAccounts", "ca-Persona-Externals-IdentityProtection-Exclusions")
            }
            Platforms = @{
                IncludePlatforms = @("all")
            }
            SignInRiskLevels = @("high")
        }
        GrantControls = @{
            BuiltInControls = @("mfa")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA304-Externals-IdentityProtection-AllApps-AnyPlatform-BlockLegacyAuth"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("exchangeActiveSync", "other")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Externals")
                ExcludeGroups = @("ca-BreakGlassAccounts", "ca-Persona-Externals-IdentityProtection-Exclusions")
            }
            Platforms = @{
                IncludePlatforms = @("all")
            }
        }
        GrantControls = @{
            BuiltInControls = @("block")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA305-Externals-AppProtection-MicrosoftIntuneEnrollment-MFA"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("0000000a-0000-0000-c000-000000000000")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Externals")
                ExcludeGroups = @("ca-BreakGlassAccounts", "ca-Persona-Externals-AppProtection-Exclusions")
            }
            Platforms = @{
                IncludePlatforms = @("all")
            }
        }
        GrantControls = @{
            BuiltInControls = @("mfa")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA306-Externals-DataandAppProtection-AllApps-iOSorAndroid-ClientAppORAPP"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("Office365")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Externals")
                ExcludeGroups = @("ca-BreakGlassAccounts", "ca-Persona-Externals-AppProtection-Exclusions", "ca-Persona-Externals-DataProtection-Exclusions")
            }
            Platforms = @{
                IncludePlatforms = @("android", "iOS")
            }
        }
        GrantControls = @{
            BuiltInControls = @("approvedApplication", "compliantApplication")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA307-Externals-AttackSurfaceReduction-AllApps-AnyPlatform-BlockUnknownPlatforms"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Externals")
                ExcludeGroups = @("ca-BreakGlassAccounts", "ca-Persona-Externals-AttackSurfaceReduction-Exclusions")
            }
            Platforms = @{
                IncludePlatforms = @("all")
                ExcludePlatforms = @("android", "iOS", "windows", "macOS", "linux")
            }
        }
        GrantControls = @{
            BuiltInControls = @("block")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA400-Guests-BaseProtection-AllApps-AnyPlatform-MFA"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Guests")
            }
        }
        GrantControls = @{
            BuiltInControls = @("mfa")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA402-Guests-IdentityProtection-AllApps-AnyPlatform-MFAforMediumandHighUserandSignInRisk"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Guests")
                ExcludeGroups = @("ca-BreakGlassAccounts", "ca-Persona-Guests-IdentityProtection-Exclusions")
            }
            Platforms = @{
                IncludePlatforms = @("all")
            }
            UserRiskLevels = @("high", "medium")
            SignInRiskLevels = @("high", "medium")
        }
        GrantControls = @{
            BuiltInControls = @("mfa")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA403-Guests-IdentityProtection-AllApps-AnyPlatform-BlockLegacyAuth"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("exchangeActiveSync", "other")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Guests")
                ExcludeGroups = @("ca-BreakGlassAccounts", "ca-Persona-Guests-IdentityProtection-Exclusions")
            }
            Platforms = @{
                IncludePlatforms = @("all")
            }
        }
        GrantControls = @{
            BuiltInControls = @("block")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA404-Guests-AttackSurfaceReduction-AllApps-AnyPlatform-BlockGuestAppAccess"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
                ExcludeApplications = @("2793995e-0a7d-40d7-bd35-6968ba142197", "Office365", "8c59ead7-d703-4a27-9e55-c96a0054c8d2")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Guests")
                ExcludeGroups = @("ca-BreakGlassAccounts", "ca-Persona-Guests-AttackSurfaceReduction-Exclusions")
            }
        }
        GrantControls = @{
            BuiltInControls = @("block")
            Operator = "OR"
        }
        SessionControls = @{
            CloudAppSecurity = @{
                IsEnabled = $true
                CloudAppSecurityType = "monitorOnly"
            }
        }
    },
    @{
        DisplayName = "CA405-Guests-ComplianceProtection-AllApps-AnyPlatform-RequireTOU"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Guests")
                ExcludeGroups = @("ca-Persona-Guests-Compliance-Exclusions", "ca-BreakGlassAccounts")
            }
        }
        GrantControls = @{
            BuiltInControls = @("mfa")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA500-GuestAdmins-BaseProtection-AllApps-AnyPlatform-PhishingResistant"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-GuestAdmins")
                ExcludeGroups = @("ca-BreakGlassAccounts", "ca-Persona-GuestAdmins")
            }
            Platforms = @{
                IncludePlatforms = @("all")
            }
        }
        GrantControls = @{
            operator = "AND"
            builtInControls = @()
            authenticationStrength = @{
                id = "00000000-0000-0000-0000-000000000004"
            }
        }
    },
    @{
        DisplayName = "CA502-GuestAdmins-IdentityProtection-AllApps-AnyPlatform-MFAforMediumandHighUserandSignInRisk"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-GuestAdmins")
                ExcludeGroups = @("ca-Persona-GuestAdmins-IdentityProtection-Exclusions", "ca-BreakGlassAccounts")
            }
            UserRiskLevels = @("high", "medium")
            SignInRiskLevels = @("high", "medium")
        }
        GrantControls = @{
            BuiltInControls = @("mfa")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA503-GuestAdmins-IdentityProtection-AllApps-AnyPlatform-BlockLegacyAuth"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("exchangeActiveSync", "other")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-GuestAdmins")
                ExcludeGroups = @("ca-BreakGlassAccounts", "ca-Persona-GuestAdmins-IdentityProtection-Exclusions")
            }
            Platforms = @{
                IncludePlatforms = @("all")
            }
        }
        GrantControls = @{
            BuiltInControls = @("block")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA504-GuestAdmins-AttackSurfaceReduction-AllApps-AnyPlatform-BlockNonO365Access"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
                ExcludeApplications = @("2793995e-0a7d-40d7-bd35-6968ba142197", "Office365")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-GuestAdmins")
            }
            Platforms = @{
                IncludePlatforms = @("all")
            }
        }
        SessionControls = @{
            CloudAppSecurity = @{
                IsEnabled = $true
                CloudAppSecurityType = "mcasConfigured"
            }
        }
    },
    @{
        DisplayName = "CA505-GuestAdmins-ComplianceProtection-AnyPlatform-RequireTOU"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-GuestAdmins")
                ExcludeGroups = @("ca-BreakGlassAccounts", "ca-Persona-Guests-Compliance-Exclusions")
            }
        }
        GrantControls = @{
            BuiltInControls = @("mfa")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA600-Microsoft365ServiceAccounts-BaseProtection-AllApps-AnyPlatform-BlockUntrustedLocations"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Microsoft365ServiceAccounts")
                ExcludeGroups = @("ca-BreakGlassAccounts")
            }
            Locations = @{
                IncludeLocations = @("All")
                ExcludeLocations = @("AllTrusted")
            }
        }
        GrantControls = @{
            BuiltInControls = @("block")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA601-Microsoft365ServiceAccounts-IdentityProtection-AllApps-AnyPlatform-BlockLegacyAuth"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("exchangeActiveSync", "other")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Microsoft365ServiceAccounts")
                ExcludeGroups = @("ca-BreakGlassAccounts")
            }
            Platforms = @{
                IncludePlatforms = @("all")
            }
        }
        GrantControls = @{
            BuiltInControls = @("block")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA604-Microsoft365ServiceAccounts-AttackSurfaceReduction-O365-AnyPlatform-BlockNonO365"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
                ExcludeApplications = @("Office365")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Microsoft365ServiceAccounts")
                ExcludeGroups = @("ca-BreakGlassAccounts")
            }
        }
        GrantControls = @{
            BuiltInControls = @("block")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA700-AzureServiceAccounts-BaseProtection-AllApps-AnyPlatform-BlockUntrustedLocations"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-AzureServiceAccounts")
                ExcludeGroups = @("ca-BreakGlassAccounts", "ca-Persona-AzureServiceAccounts-Exclusions")
            }
            Locations = @{
                IncludeLocations = @("All")
                ExcludeLocations = @("AllTrusted")
            }
            Platforms = @{
                IncludePlatforms = @("all")
            }
        }
        GrantControls = @{
            BuiltInControls = @("block")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA701-AzureServiceAccounts-IdentityProtection-AllApps-AnyPlatform-BlockLegacyAuth"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("exchangeActiveSync", "other")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-AzureServiceAccounts")
                ExcludeGroups = @("ca-BreakGlassAccounts", "ca-Persona-AzureServiceAccounts-Exclusions")
            }
            Platforms = @{
                IncludePlatforms = @("all")
            }
        }
        GrantControls = @{
            BuiltInControls = @("block")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA704-AzureServiceAccounts-AttackSurfaceReduction-AllApps-AnyPlatform-BlockNonAzure"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
                ExcludeApplications = @("797f4846-ba00-4fd7-ba43-dac1f8f63013")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-AzureServiceAccounts")
                ExcludeGroups = @("ca-BreakGlassAccounts", "ca-Persona-AzureServiceAccounts-Exclusions")
            }
            Platforms = @{
                IncludePlatforms = @("all")
            }
        }
        GrantControls = @{
            BuiltInControls = @("block")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA800-CorpServiceAccounts-BaseProtection-AllApps-AnyPlatform-BlockUntrustedLocations"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-CorpServiceAccounts")
                ExcludeGroups = @("ca-BreakGlassAccounts", "ca-Persona-CorpServiceAccounts-Exclusions")
            }
            Locations = @{
                IncludeLocations = @("All")
                ExcludeLocations = @("AllTrusted")
            }
            Platforms = @{
                IncludePlatforms = @("all")
            }
        }
        GrantControls = @{
            BuiltInControls = @("block")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA801-CorpServiceAccounts-IdentityProtection-AllApps-AnyPlatform-BlockLegacyAuth"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("exchangeActiveSync", "other")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-CorpServiceAccounts")
                ExcludeGroups = @("ca-BreakGlassAccounts", "ca-Persona-CorpServiceAccounts-Exclusions")
            }
        }
        GrantControls = @{
            BuiltInControls = @("block")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA802-CorpServiceAccounts-AttackSurfaceReduction-AllApps-AnyPlatform-BlockNonO365andAzure"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
                ExcludeApplications = @("797f4846-ba00-4fd7-ba43-dac1f8f63013", "Office365")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-CorpServiceAccounts")
                ExcludeGroups = @("ca-BreakGlassAccounts", "ca-Persona-CorpServiceAccounts-Exclusions")
            }
            Platforms = @{
                IncludePlatforms = @("all")
            }
        }
        GrantControls = @{
            BuiltInControls = @("block")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA900-WorkloadIdentities-BaseProtection-AllApps-AnyPlatform-BlockUntrustedLocations"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-WorkloadIdentities")
                ExcludeGroups = @("ca-Persona-WorkloadIdentities-Exclusions", "ca-BreakGlassAccounts")
            }
            Locations = @{
                IncludeLocations = @("All")
                ExcludeLocations = @("AllTrusted")
            }
        }
        GrantControls = @{
            BuiltInControls = @("block")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA1000-Developers-BaseProtection-AllApps-AnyPlatform-ForwardToDefenderforCloudApps"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
                ExcludeApplications = @("0000000a-0000-0000-c000-000000000000")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Developers")
                ExcludeGroups = @("ca-BreakGlassAccounts", "ca-Persona-Developers-BaseProtection-Exclusions")
            }
        }
        SessionControls = @{
            CloudAppSecurity = @{
                IsEnabled = $true
                CloudAppSecurityType = "mcasConfigured"
            }
        }
    },
    @{
        DisplayName = "CA1001-Developers-BaseProtection-AllApps-AnyPlatform-PhishingResistant"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Developers")
                ExcludeGroups = @("ca-BreakGlassAccounts", "ca-Persona-Developers-BaseProtection-Exclusions")
            }
        }
        GrantControls = @{
            operator = "AND"
            builtInControls = @()
            authenticationStrength = @{
                id = "00000000-0000-0000-0000-000000000004"
            }
        }
    },
    @{
        DisplayName = "CA1003-Developers-IdentityProtection-AllApps-AnyPlatform-MFAandPWDforHighUserRisk"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Developers")
                ExcludeGroups = @("ca-BreakGlassAccounts", "ca-Persona-Developers-IdentityProtection-Exclusions")
            }
            UserRiskLevels = @("high", "medium")
        }
        GrantControls = @{
            BuiltInControls = @("mfa", "passwordChange")
            Operator = "AND"
        }
    },
    @{
        DisplayName = "CA1004-Developers-IdentityProtection-AllApps-AnyPlatform-MFAforHighSignInRisk"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Developers")
                ExcludeGroups = @("ca-BreakGlassAccounts", "ca-Persona-Developers-IdentityProtection-Exclusions")
            }
            SignInRiskLevels = @("high", "medium")
        }
        GrantControls = @{
            BuiltInControls = @("mfa")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA1005-Developers-IdentityProtection-AllApps-AnyPlatform-BlockLegacyAuth"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("exchangeActiveSync", "other")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Developers")
                ExcludeGroups = @("ca-Persona-Developers-IdentityProtection-Exclusions", "ca-BreakGlassAccounts")
            }
            Platforms = @{
                IncludePlatforms = @("all")
            }
        }
        GrantControls = @{
            BuiltInControls = @("block")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA1006-Developers-AppProtection-MicrosoftIntuneEnrollment-AnyPlatform-MFA"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("0000000a-0000-0000-c000-000000000000")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Developers")
                ExcludeGroups = @("ca-BreakGlassAccounts", "ca-Persona-Developers-AppProtection-Exclusions")
            }
        }
        GrantControls = @{
            BuiltInControls = @("mfa")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA1007-Developers-DataandAppProtection-AllApps-iOSorAndroid-ClientAppORAPP"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("Office365")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Developers")
                ExcludeGroups = @("ca-BreakGlassAccounts", "ca-Persona-Developers-AppProtection-Exclusions", "ca-Persona-Developers-DataProtection-Exclusions")
            }
            Platforms = @{
                IncludePlatforms = @("android", "iOS")
            }
        }
        GrantControls = @{
            BuiltInControls = @("approvedApplication", "compliantApplication")
            Operator = "OR"
        }
    },
    @{
        DisplayName = "CA1008-Developers-AttackSurfaceReduction-AllApps-AnyPlatform-BlockUnknownPlatforms"
        State = "disabled"
        Conditions = @{
            ClientAppTypes = @("all")
            Applications = @{
                IncludeApplications = @("All")
            }
            Users = @{
                IncludeGroups = @("ca-Persona-Developers")
                ExcludeGroups = @("ca-BreakGlassAccounts", "ca-Persona-Developers-AttackSurfaceReduction-Exclusions")
            }
            Platforms = @{
                IncludePlatforms = @("all")
                ExcludePlatforms = @("android", "iOS", "windows", "macOS", "linux")
            }
        }
        GrantControls = @{
            BuiltInControls = @("block")
            Operator = "OR"
        }
    }
)


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
