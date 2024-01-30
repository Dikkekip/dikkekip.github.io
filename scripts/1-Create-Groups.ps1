# Ensuring the presence of the Microsoft.Graph module
if (-not (Get-Module -Name Microsoft.Graph -ListAvailable)) {
    Install-Module -Name Microsoft.Graph -Scope CurrentUser -Force
    Write-Host "🔮 Microsoft.Graph module installed successfully!" -ForegroundColor Cyan
}
else {
    Write-Host "✅ Microsoft.Graph module is already installed." -ForegroundColor Green
}

# Ensuring the presence of the Az.Accounts module
if (-not (Get-Module -Name Az.Accounts -ListAvailable)) {
    Install-Module -Name Az.Accounts -Scope CurrentUser -Force
    Write-Host "🔮 Az.Accounts module installed successfully!" -ForegroundColor Cyan
}
else {
    Write-Host "✅ Az.Accounts module is already installed." -ForegroundColor Green
}

# Ensuring the presence of the Az.Accounts module
if (-not (Get-Module -Name Microsoft.PowerShell.ConsoleGuiTools -ListAvailable)) {
    Install-Module -Name Microsoft.PowerShell.ConsoleGuiTools -Scope CurrentUser -Force
    Write-Host "🔮 Microsoft.PowerShell.ConsoleGuiTools module installed successfully!" -ForegroundColor Cyan
}
else {
    Write-Host "✅ Microsoft.PowerShell.ConsoleGuiTools module is already installed." -ForegroundColor Green
}


# Import the Microsoft.Graph.Identity.Governance module
Import-Module Microsoft.Graph.Identity.Governance
Write-Host "📚 Imported Microsoft.Graph.Identity.Governance module." -ForegroundColor Magenta

# Establishing a connection to Microsoft Graph
$context = Get-MgContext

if ($null -eq $context) {
    Write-Host "Graph connection not detected. Requesting user to log in."
    Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read.All", "PrivilegedAccess.ReadWrite.AzureADGroup"
    Write-Host "🧙‍♂️ Context acquired. Current wizard in control: $($context.Account)" -ForegroundColor Yellow
    Write-Host "🔗 Connected to Microsoft Graph with the necessary scopes." -ForegroundColor Blue
}
else {
    Write-Host "🧙‍♂️ Already connected to Graph as $($context.Account.Id)" -ForegroundColor Yellow
}

# Summoning all groups from the depths of Azure
# Like casting a net into the sea of the cloud to see what mysteries we can uncover
$groups = Get-MgGroup
Write-Host "🌌 Summoned all groups from the depths of Azure." -ForegroundColor DarkCyan

# Preparing the environment for our Azure ritual
# Time to connect to Microsoft Graph with the right spells... I mean, scopes!
# Preparing the environment for our Azure ritual
$context = Get-MgContext

if ($null -eq $context) {
    Write-Host "Graph connection not detected. Requesting user to log in."
    Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read.All", "PrivilegedAccess.ReadWrite.AzureADGroup"
    Write-Host "🧙‍♂️ Context acquired. Current wizard in control: $($context.Account)" -ForegroundColor Yellow

}
else {
    Write-Host "🧙‍♂️ Already connected to Graph as $($context.Account.Id)" -ForegroundColor Yellow
}


# Inquiring the wizard (you) about their intention to create new groups
$CreateGroups = Read-Host "Do you wish to conjure new groups into existence? (y/n)"
if ($CreateGroups -eq "y") {
    Write-Host "🪄 Ah, a brave decision! Let's define the names and destinies of these new groups." -ForegroundColor Yellow
    $groupsToCreate = Read-Host "Enter your group names and descriptions in the format 'name:description', separated by commas"
    $groupArray = $groupsToCreate -split "," | ForEach-Object {
        $split = $_ -split ":", 2  # Splitting the input to extract name and description
        if ($split.Length -eq 2) {
            Write-Host "🌟 Preparing to conjure group named $($split[0].Trim()) with a purpose of $($split[1].Trim())" -ForegroundColor Cyan
            [PSCustomObject]@{ name = $split[0].Trim(); description = $split[1].Trim() }
        }
        else {
            Write-Host "⚠️ Beware! Invalid format detected for '$_'. A group name and description are required." -ForegroundColor Red
        }
    }
    Write-Host "📝 The list of groups to be conjured has been prepared." -ForegroundColor Yellow
}

$groupsCreated = @()

foreach ($entry in $groupArray) {
    # Consulting the Azure oracles to see if the group already exists
    Write-Host "🔍 Consulting the Azure oracles for the existence of $($entry.name)..." -ForegroundColor Cyan
    $group = Get-MgGroup -Filter "DisplayName eq '$($entry.name)'"
    if ($group) {
        Write-Host "👁️ The group $($entry.name) already exists in the realm of Azure." -ForegroundColor Green
        # Updating the group's description if needed
        if ($entry.description -and $group.description -ne $entry.description) {
            Write-Host "📝 Updating the lore (description) of $($entry.name) to match our records." -ForegroundColor Cyan
            Update-MgGroup -GroupId $group.Id -Description $entry.description
        }
        else {
            Write-Host "🔄 No updates required for $($entry.name). Its lore remains unchanged." -ForegroundColor Gray
        }
        $groupsCreated += $group
    }
    else {
        # The spell to create a new group
        Write-Host "🌟 The group $($entry.name) is not yet part of our realm. Let's bring it to life!" -ForegroundColor Yellow
        $GroupBody = @{
            DisplayName         = $entry.name
            Description         = $entry.description
            MailEnabled         = $false
            MailNickname        = $entry.name
            SecurityEnabled     = $true
            "Owners@odata.bind" = @("https://graph.microsoft.com/v1.0/users/$($context.Account)")
        }
        $newGroup = New-MgGroup -BodyParameter $GroupBody
        Write-Host "✨ Group $($entry.name) has been successfully conjured!" -ForegroundColor Green
        $groupsCreated += $newGroup
    }
}

# Revealing our group crafting achievements
Write-Host "🔮 Behold the groups that have been created or updated in this session:" -ForegroundColor Yellow
foreach ($group in $groupsCreated) {
    Write-Host "📜 Group Name: $($group.DisplayName), ID: $($group.Id)" -ForegroundColor Green
}
