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
        # and (user.extension_808e2b5224d948a1ba246e894f535ce7_phisingResistantEnabled -match `"False`")
    },
    @{
        DisplayName = "ca-persona-admins-PhishingResistant-Exclusions"
        Description = "Dynamic group for administrators that need to setup phishing-resistant authentication methods"
        MailNickname = "ca-persona-admins-PhishingResistant-Exclusions"
        SecurityEnabled = $true
        MailEnabled = $false
        GroupTypes = @("DynamicMembership")
        MembershipRule = "(user.userType -eq `"Member`") and (user.userPrincipalName -match `"admin`") and (user.department -match `"Cloud Admin`")"
        MembershipRuleProcessingState = "On"
        # (user.extension_808e2b5224d948a1ba246e894f535ce7_phisingResistantEnabled -match `"False`")
    }
)


foreach ($group in $groups) {
    New-AADGroup @group
}