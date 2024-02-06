---
layout: post
title:  "🚀 PIM for Groups: Automate Assignments with the GraphAPI!"
date:   2024-01-24 07:40:59 +0100
comments: true
description: "Discover the magic of automating PIM for groups with PowerShell and GraphAPI in Azure."
categories: [Azure, PowerShell, Cloud Computing, DevOps, PIM, GraphAPI]
tags: [Azure PIM, PowerShell Scripting, GraphAPI, Cloud Security, Access Management, Azure Automation, IT Security, Cloud Administration, Microsoft Azure, DevOps Practices]
image:
  path: /assets/img/pim-for-groups/thumbnail.png
  src: /assets/img/pim-for-groups/thumbnail.png
toc: true
---

Hey tech enthusiasts! 👨‍💻🚀 Today, we're venturing into the mystical realm of Privileged Identity Management (PIM) iteration 3 APIs. Ever felt like deciphering PIM APIs is like unraveling ancient runes? Join the club! Today's quest involves the nuances of activating roles for groups eligible under PIM...

1. **Privileged Identity Management APIs Overview**: [This article](https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-apis#iteration-3-current--pim-for-microsoft-entra-roles-groups-in-microsoft-graph-api-and-for-azure-resources-in-arm-api) on Microsoft Learn provides a overview of PIM APIs. It is unfortunatly not great and I hope that this article does a better job at getting you started.

> For those who prefer to run the script without delving into the blog, the full script is available [here](https://github.com/Dikkekip/dikkekip.github.io/blob/main/scripts/2024-01-24-pim-for-groups-1/Enable-GroupsforPim.ps1).
{: .prompt-tip }

1. **Why Use PIM for Groups?**: Let's decode the "why" behind the wizardry of PIM for Groups. Imagine you're the guardian of a mystical realm (your organization's IT environment). In this realm, power (access rights) must be bestowed carefully. PIM for Groups is like having a magical keyring that gives you control over who holds these powers and for how long.

   - **Just-In-Time Access**: Think of it as a time-locked vault. You can grant access to certain resources, but only for a specific duration. This way, users have the privileges they need, exactly when they need them, reducing the risk of 'power' lingering in the wrong hands.

   - **Role-Based Assignments**: It's like assigning roles in a play. Each actor (user) gets a part (role) that's essential for the scene (task) but only for the duration of their performance (specific time or project). This ensures that users don't retain privileges beyond their current needs.

   - **Minimize Security Risks**: By controlling access more granularly, you're essentially setting up magical wards against security breaches. No more permanent, unchecked access means less chance of your defenses being breached by dark forces (unauthorized users).

   - **Streamline Management**: Managing a large group of wizards (users) can be chaotic. PIM for Groups brings order to this chaos by automating the process of assigning and revoking access. It's like having an administrative crystal ball, giving you a clear view of who has access to what and when.

   - **Compliance and Auditing**: In the world of IT, you must often answer to higher powers (compliance regulations). PIM for Groups helps you maintain a detailed log of who accessed what and when, which is like keeping a detailed spell book for auditing purposes.

In essence, PIM for Groups empowers you to manage your realm with precision and agility, ensuring that the right powers are in the right hands at the right time. It's not just about keeping your kingdom safe; it's about ruling it wisely. 🚀🔮

3. **Scripting with PowerShell & GraphAPI**: Time to get our hands dirty with some PowerShell scripting and GraphAPI sorcery! We'll automate the assignment of eligible members to groups using these tools, weaving our code as cleanly as a well-crafted spell.

4. **Step-by-Step Guide**: Prepare your wizard's robe and wand (or just a comfy chair and your computer), as we embark on a magical journey through the world of PIM for Groups automation. Here's your detailed map through the mystical forest of Azure and PowerShell scripting:

📚 A Wizard's Guide to Azure Group Enchantment via PowerShell
Congratulations, brave wizard of the cloud! You're about to embark on a mystical quest to manage Azure groups with PowerShell and Privileged Identity Management (PIM). This arcane journey involves tapping into the power of Graph API, even as we await its latest incantations for group management. Let's start conjuring!

🪄 The Spell Preparation: Importing Essential Modules
Before casting our spells, we need to prepare our magical ingredients. In the wizarding world of PowerShell, this means ensuring the necessary modules are installed and ready for use.


```powershell
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


```
🧙‍♂️ Wizard's Tip:
Always check for the existence of a module before trying to install it. This prevents unnecessary incantations and keeps your magic (and scripts) efficient!

🌌 Navigating the Azure Cosmos: Next Steps
With our modules at the ready, we are prepared to dive deeper into the Azure cosmos. Our next steps will involve authenticating with Azure, conjuring groups, and binding them with the power of PIM. Each step, akin to a magical incantation, must be executed with precision and understanding.


#### 2. 🌟 Advanced Wizardry: Unveiling the Secrets of Microsoft Graph Connection
Great! You're progressing splendidly on your mystical quest through the Azure cosmos. Now, it's time to establish a connection with the Microsoft Graph — akin to tapping into the very lifeblood of Azure's intelligence network. Here's how you'll weave this intricate part of the spell.

🌀 Connecting to the Oracle of Graph
The Microsoft Graph is like the Oracle of Delphi for Azure wizards. By establishing a connection, we gain insights and control over the Azure realm's inner workings.


```powershell

# Import the Microsoft.Graph.Identity.Governance module
Import-Module Microsoft.Graph.Identity.Governance

# Establishing a connection to Microsoft Graph
# Think of this as tuning your crystal ball to the right magical frequency
Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read.All", "PrivilegedAccess.ReadWrite.AzureADGroup"

# Summoning all groups from the depths of Azure
# Like casting a net into the sea of the cloud to see what mysteries we can uncover
Get-MgGroup

```

🧙‍♂️ Wizard's Insight:
Choosing the correct scopes is crucial! It's like picking the right herbs for a potion. Here, we're using Group.ReadWrite.All, User.Read.All, and PrivilegedAccess.ReadWrite.AzureADGroup to ensure we have the necessary permissions for our operations.

🔮 What Lies Ahead
Now that we're connected and have summoned our groups, we're ready to delve into more complex rituals. We'll be exploring how to filter these groups, apply PIM policies, and much more. Each step is a rune in the grand spell we're casting to master Azure Group management.

Stay vigilant, brave wizard! The path of a cloud sorcerer is fraught with complexities, but fear not, for you have the might of PowerShell and the wisdom of the Microsoft Graph on your side! 🌩️🔮


#### 3. 🪄 The Art of Group Conjuration in Azure: A Wizard's Guide
Ah, the noble art of creating Azure groups using PowerShell! This step is akin to shaping the very fabric of our cloud kingdom. Let's weave this part of our grand spell with care and precision.

🪄 The Incantation for Group Creation
Now, we shall embark on the mystical process of group creation. Remember, naming conventions in the realm of Azure are more than mere words; they are the identifiers of your dominion's structure and purpose.

Naming standards may vary But I use the following format:
{prefix}-{system}-{type}-{region}-{LzName}-{role}

For this demo, I will create the following 2 groups:
- `d-avd-sec-weu-sandbox-lz-dikkekip-AdminAccess`
- `d-demo-sec-weu-sandbox-lz-dikkekip-AdminAccess`

With this part of the script, we will create the groups and add the user we create the groups with as owner so that we can manage Pim for groups.
<script async id="asciicast-A4waLEk7q8qF3tppRRzcXjIyh" src="https://asciinema.org/a/A4waLEk7q8qF3tppRRzcXjIyh.js" data-speed="1" data-theme="solarized-dark" data-autoplay="1" data-loop="1"></script>


```powershell

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
```

🧙‍♂️ Voilà, esteemed cloud wizard! With mere lines of PowerShell incantation, you've called groups into being within our vast Azure kingdom. Remember, wielding the wand of scripting comes with considerable responsibility — but let's not forget the sprinkles of joy and intrigue it brings!

🔑 Why anoint ourselves as the group's sovereign? In the Entra ID realm, owning a group transcends mere titular honor. It bestows upon you the master key to this digital dominion. As the owner, you're empowered to designate users as eligible members, akin to granting access to the inner sanctums of your castle. Without this key, the ability to effectively govern the denizens (users) of your Entra ID territory remains an elusive dream.

#### 4. 🌐 Activating PIM's Mystical Shield for Groups

The next crucial incantation in our spellbook involves invoking Privileged Identity Management (PIM) for our newly spawned or chosen groups. This potent sorcery bestows upon you the capability to manage group memberships with the wisdom of just-in-time access and eligibility criteria. It's like weaving a protective enchantment around your groups, ensuring that only those with the right credentials and timing can enter your Azure fortress. Embrace this power wisely, for it's a cornerstone in the architecture of secure and efficient Azure management.

🧙‍♂️ Wizard's Insight:
Enabling PIM for groups is not just about control; it's about smart control. It allows you to manage who has access, when they have it, and under what conditions. This is crucial in maintaining the sanctity and security of your Azure ecosystem. With great power comes the need for equally great foresight and discretion. 🌌🔮🛡️

#### ⚡ The Time-Honored Spell: Onboarding Groups to PIM

In the ever-evolving world of Azure, sometimes we must rely on the wisdom of the ancients. For onboarding groups into Privileged Identity Management (PIM), the new CMDLets are like elusive unicorns, yet to be discovered in our forests. So, we turn to the classic methods, as detailed in the [Microsoft Documentation](https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/groups-discover-groups). It's akin to using an old, trusted map when the new GPS hasn't been updated for the latest roads.

<script async id="asciicast-fMHXCMCK4rMzCiPXWV7RplDQL" src="https://asciinema.org/a/fMHXCMCK4rMzCiPXWV7RplDQL.js"data-speed="1" data-theme="solarized-dark" data-autoplay="1" data-loop="1"></script>

```powershell

Write-Host "🔮 Starting the enchantment to enable Privileged Identity Management (PIM) for groups" -ForegroundColor Cyan

$context = Get-MgContext

if ($null -eq $context) {
    Write-Host "Graph connection not detected. Requesting user to log in."
    Connect-MgGraph -Scopes "User.Read.All", "PrivilegedAccess.ReadWrite.AzureADGroup"
    Write-Host "🧙‍♂️ Context acquired. Current wizard in control: $($context.Account)" -ForegroundColor Yellow

}
else {
    Write-Host "🧙‍♂️ Already connected to Graph as $($context.Account.Id)" -ForegroundColor Yellow
}

# Deciding which groups to enable PIM for
if (!$groupsCreated) {
    Write-Host "🔍 No newly created groups detected. Retrieving all available groups for PIM activation." -ForegroundColor Yellow
    $groups = Get-MgGroup -All

    # Using a magical grid view to select groups
    $groupsToEnable = $groups | Select-Object DisplayName, Id | Out-ConsoleGridView -Title "Select groups to activate in PIM" -OutputMode Multiple
}
else {
    Write-Host "✨ Newly conjured groups detected. Preparing to enable PIM for these groups." -ForegroundColor Green
    $groupsToEnable = $groupsCreated
}

# Displaying the groups chosen for PIM enablement
# Inquiring the wizard (you) about their intention to create new groups
$enableGroups = Read-Host "enable groups in Privileged Identity Management ? (y/n)"
if ($enableGroups -eq "y") {
    # Ensure the user is connected to Azure
    Write-Host "Fetching the current Azure context..."
    $context = Get-AzContext
    if ($null -eq $context) {
        Write-Host "❗ Azure connection not detected. Requesting user to log in." -ForegroundColor Red
        Connect-AzAccount
    }
    else {
        Write-Host "🔗 Already connected to Azure as $($context.Account.Id)" -ForegroundColor Green
    }

    # Acquiring the token to communicate with the PIM API
    Write-Host "🔑 Acquiring the token to communicate with the Privileged Identity Management (PIM) API..." -ForegroundColor Cyan
    $accessTokenPim = (Get-AzAccessToken -ResourceUrl 'https://api.azrbac.mspim.azure.com').Token
    $headers = @{
        "Authorization" = "Bearer $accessTokenPim"
        "Content-Type"  = "application/json"
    }

    Write-Host "📋 Preparing to enable Privileged Identity Management for the following groups:" -ForegroundColor Cyan
    foreach ($group in $groupsToEnable) {
        Write-Host "🔎 Analyzing group: $($group.DisplayName) with ID: $($group.Id)" -ForegroundColor Magenta
    

        # Checking the current status of the group in PIM
        $findGroupInPim = Get-MgIdentityGovernancePrivilegedAccessGroupEligibilitySchedule -Filter "groupId eq '$($group.Id)'"

        if (!$findGroupInPim) {
            Write-Host "⚡ Group $($group.DisplayName) is not yet part of PIM. Preparing to onboard." -ForegroundColor Yellow
           
            write-host "🔮 Starting the enchantment to enable Privileged Identity Management (PIM) for groups" -ForegroundColor Cyan
            # The URL to the PIM API for group registration
            $url = "https://api.azrbac.mspim.azure.com/api/v2/privilegedAccess/aadGroups/resources/register" 
    
            # Onboarding the group to PIM
            Write-Host "🧙‍♂️ Onboarding group '$($group.DisplayName)' (ID: $($group.Id)) to PIM." -ForegroundColor Cyan
            Invoke-RestMethod -Uri $url -Headers $headers -Method Post -Body "{`"externalId`":`"$($group.id)`"}"
            Write-Host "✅ Group '$($group.DisplayName)' successfully onboarded to PIM." -ForegroundColor Green
        }
        else {
            Write-Host "🚫 Group $($group.DisplayName) is already part of PIM. No action needed." -ForegroundColor Gray
        }
    }
    
}
else {
    Write-Host "🔮 The wizard has decided not to enable PIM for the selected groups. Ending the enchantment." -ForegroundColor Cyan
}

```

![GroupsOnboarded](/assets/img/pim-for-groups/GroupsOnboarded.png "GroupsOnboarded")

#### 5. Assigning Users to Groups
Finally, the script assigns users to the groups for PIM. This process ensures that the right people have the right access at the right time, enhancing security and efficiency.


<script async id="asciicast-fMHXCMCK4rMzCiPXWV7RplDQL" src="https://asciinema.org/a/fMHXCMCK4rMzCiPXWV7RplDQL.js" data-speed="1" data-theme="solarized-dark" data-autoplay="1" data-loop="1"></script>


```powershell

# Displaying the groups chosen for PIM enablement
Write-Host "===================================================================================================="
Write-Host "🔮 [$($context.Account)] Final phase initiated: Assigning users to groups in Privileged Identity Management." -ForegroundColor Cyan

# Initiating the process of assigning users to the selected groups
Write-Host "🚀 [$($context.Account)] Commencing the user assignment to groups." -ForegroundColor Magenta

$context = Get-MgContext

if ($null -eq $context) {
    Write-Host "Graph connection not detected. Requesting user to log in."
    Connect-MgGraph -Scopes "User.Read.All", "PrivilegedAccess.ReadWrite.AzureADGroup"
    Write-Host "🧙‍♂️ Context acquired. Current wizard in control: $($context.Account)" -ForegroundColor Yellow

}
else {
    Write-Host "🧙‍♂️ Already connected to Graph as $($context.Account.Id)" -ForegroundColor Yellow
}

# Deciding which groups to enable PIM for
write-host "🔍 No newly created groups detected. Retrieving all available groups for PIM activation." -ForegroundColor Yellow
# Determining the groups for user assignment
if (!$groupsToEnable) {
    Write-Host "🤔 [$($context.Account)] No groups specified for enabling. Retrieving all groups for user assignment selection." -ForegroundColor Yellow
    $groupsToConfigure = Get-MgGroup -All | Select-Object DisplayName, Id | Out-ConsoleGridView -Title "Select groups for user assignment" -OutputMode Multiple
}
else {
    Write-Host "✨ [$($context.Account)] Preparing to assign users to the recently enabled groups." -ForegroundColor Green
    $groupsToConfigure = $groupsToEnable
}

# Selecting the users to assign to the groups
Write-Host "👥 Selecting users to assign to the groups." -ForegroundColor Cyan
$usersToAssign = Get-MgUser -Filter "AccountEnabled eq true" | Select-Object DisplayName, Id | Out-ConsoleGridView -Title "Select users for assignment" -OutputMode Multiple

foreach ($group in $groupsToConfigure) {
    foreach ($user in $usersToAssign) {
        # Checking if the user is already assigned to the group
        Write-Host "🔍 Checking if user '$($user.DisplayName)' is already assigned to group '$($group.DisplayName)'." -ForegroundColor Blue
        $isAssigned = Get-MgIdentityGovernancePrivilegedAccessGroupEligibilityScheduleRequest -Filter "groupId eq '$($group.Id)' and principalId eq '$($user.Id)'"
        
        if (!$isAssigned) {
            Write-Host "👩‍🏫 [$($context.Account)] Assigning user '$($user.DisplayName)' to group '$($group.DisplayName)'." -ForegroundColor Cyan
            # Setting the assignment start and end times
            $startTime = Get-Date
            $endTime = $startTime.AddMonths(12).AddDays(-1)

            # Preparing parameters for the assignment
            $params = @{
                accessId      = "member"
                principalId   = "$($user.Id)"
                groupId       = "$($group.Id)"
                action        = "AdminAssign"
                scheduleInfo  = @{
                    startDateTime = $startTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                    expiration    = @{
                        type        = "AfterDateTime"
                        endDateTime = $endTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                    }
                }
                justification = "Entra ID - PIM Group Assignment - $($group.DisplayName) - $($user.DisplayName)"
            }

            # Executing the assignment
            New-MgIdentityGovernancePrivilegedAccessGroupEligibilityScheduleRequest -BodyParameter $params
            Write-Host "✅ User '$($user.DisplayName)' successfully assigned to group '$($group.DisplayName)'." -ForegroundColor Green
        }
        else {
            Write-Host "🔄 [$($context.Account)] User '$($user.DisplayName)' is already a member of group '$($group.DisplayName)'. No action required." -ForegroundColor Gray
        }
    }
}


```

## There You Have It: The Power of Eligible Assignments 🧙‍♂️

And with that, we've successfully navigated the arcane waters of Azure PIM, empowering my user account with the Eligible assignments of the new groups. It's a digital alchemy of sorts, where each step brings us closer to mastering the art of cloud identity management.


![GroupsEligibility](/assets/img/pim-for-groups/GroupsEligibility.png "GroupsEligibility")

### 🧙‍♂️ The Magic of Group Membership Activation

Now, as visible in the Azure portal, I can activate my membership to these groups. This simple yet powerful act is akin to unlocking a hidden door within the realm of Azure, granting me access to the groups' resources and capabilities.

### 🔮 Next Article: Unveiling the Potential of Activated Access

But wait, there's more! In the next article, we'll delve deeper into the practical applications of this setup. Imagine being able to dynamically manage access and privileges within your cloud environment — that's exactly where we're headed:

- **Exploring the Activated Group Membership**: We'll take a hands-on look at how activated membership in these groups can be leveraged in real-world scenarios.
- **Unlocking New Capabilities**: With our groups now at our command, we'll explore how this can translate into enhanced control over resources, including demo VMs in Azure.
- **A Sneak Peek into Advanced Automations**: Get ready to witness how these group memberships can be utilized for even more sophisticated tasks and automations in Azure.

# 🌌 Stay Tuned for the Next Spellbinding Chapter

So, keep your wands at the ready and your minds open to the endless possibilities that Azure and PowerShell have to offer. Our journey into the depths of cloud computing is far from over. In fact, it’s just getting more exciting!

Make sure to follow along and join me in the next installment of our Azure saga, where we continue to unravel the mysteries and harness the powers of the cloud.

*Until next time, happy cloud conjuring!*

*Cheers, Maarten* 🍻💻✨

#### 📚 A Note on Documentation

In the realm of Azure PIM automation with PowerShell, documentation plays the role of a magical grimoire, guiding fellow wizards through the labyrinth of cloud identity management. Here's a condensed essence of our journey and some pointers to keep in mind:

1. **API Limitations and Workarounds**: As we delved into the task, it was clear that the Graph API currently doesn't support certain operations directly. We resorted to using the older Privileged Identity Management iteration 2 API, a path less trodden but well-documented [here](https://learn.microsoft.com/en-us/graph/api/resources/privilegedidentitymanagement-root?view=graph-rest-beta). It's crucial to keep abreast of updates, as Microsoft's wizards are known for enhancing their APIs with new capabilities over time.

2. **Onboarding Groups and Users**: The core of our script involved onboarding groups to PIM and then adding users as eligible members. This crucial step ensures that the right people have access to the right resources at the right time, enhancing both security and efficiency. The nuances of this process are detailed in the official Microsoft documentation [here](https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/groups-discover-groups).

3. **Flexibility and Customization**: Our script's charm lies in its flexibility, allowing you to define group names and descriptions that resonate with your narrative in the Entra ID saga. This level of customization ensures that the script can be tailored to various organizational needs and scenarios.

4. **Further Reading and Resources**: For those who wish to dive deeper into the technicalities or prefer to run the script without delving into the blog, the full script is available [here](https://github.com/Dikkekip/dikkekip.github.io/blob/main/assets/scripts/Enable-GroupsforPim.ps1). Additionally, a treasure trove of information on API usage and examples can be found in Microsoft's documentation [here](https://learn.microsoft.com/en-us/graph/api/privilegedaccessgroup-post-assignmentschedulerequests?view=graph-rest-1.0&tabs=powershell).
