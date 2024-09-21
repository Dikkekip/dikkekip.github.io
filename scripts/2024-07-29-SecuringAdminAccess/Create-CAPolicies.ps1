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