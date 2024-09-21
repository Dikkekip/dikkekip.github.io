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
