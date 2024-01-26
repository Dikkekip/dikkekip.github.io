---
layout: post
title:  "🚀 PIM for Groups: Automate Assgmements with the GraphAPI!"
date:   2024-01-24 07:40:59 +0100
description: How to Assign pim for groups eligible members.
---


Hey tech enthusiasts! 👨‍💻🚀 Today, I'm diving into the enigmatic world of Privileged Identity Management (PIM) iteration 3 APIs. If you've ever felt like navigating PIM APIs is akin to decoding ancient runes, you're not alone! We'll explore the intricacies of activating roles when you have eligible groups assigned and how to assign eligible users to groups through PIM for Groups.

1. **Privileged Identity Management APIs Overview**: This article on [Microsoft Learn](https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/pim-apis#iteration-3-current--pim-for-microsoft-entra-roles-groups-in-microsoft-graph-api-and-for-azure-resources-in-arm-api) provides a comprehensive overview of PIM APIs, including PIM for Microsoft Entra roles, PIM for Azure resources, and PIM for Groups. It details the functionalities of the APIs across different iterations and provides links to specific API references.

2. **Why Use PIM for Groups?**: Before we dive into the how-to, let's talk about the why. PIM for Groups is like having a backstage pass to your Entra ID environment. It allows you to manage just-in-time and eligible assignments for groups. This means you can assign specific roles to users for a limited time, reducing the risk of excess permissions lingering like unwanted guests at a party.

3. **Scripting with PowerShell & GraphAPI**: Now, let's get our hands dirty with some PowerShell scripting mixed with GraphAPI magic! The idea is to automate the assignment of eligible members to groups using PowerShell and GraphAPI. We'll script our way through the process, making sure we adhere to best practices and keep our code as clean as a whistle.

4. **Step-by-Step Guide**: I'll walk you through the steps required to set up your environment, authenticate with Azure, and create a script that automates PIM assignments for groups. This guide will be detailed enough for beginners but also packed with tips and tricks for the seasoned pros.

5. **Common Pitfalls and How to Avoid Them**: Along the way, we'll encounter some common pitfalls, like incorrect API permissions or syntax errors in our PowerShell script. I'll show you how to sidestep these issues and keep your automation engine running smoothly.

6. **Conclusion and Next Steps**: By the end of this article, you'll be a PIM for Groups maestro, ready to orchestrate your Entra ID environment with finesse. I'll also share some ideas for further automating your cloud environment and how to continue your journey as a Cloud and DevOps engineer.

So, grab your favorite beverage, and let's get started on this exhilarating journey through the realms of PIM for Groups! 🚀💻

## The PIM for Groups Saga Begins 🧙‍♂️

For this article, I've geared up my trusty CDX demo environment and conjured a new Entra ID tenant. We're starting from scratch, but with a twist of Cloud DevOps magic!

### The Technical Grimoire 📜
Embarking on this journey, we're not just any wizards; we're PowerShell wizards! The documentation for PIM and GraphAPI can sometimes feel like a mysterious treasure map, where X doesn't always mark the spot. Fear not! I'm here to navigate these treacherous waters with you.

First things first, let's login to the Graph APIs. It's like opening the portal to our cloud kingdom. Ready your wands (or keyboards)!

Lets get started and login to the Graph APIs
```powershell
# Check if the Microsoft.Graph module is installed
if (-not (Get-Module -Name Microsoft.Graph -ListAvailable)) {
    # Not installed? No problem! Let's install the MgGraph module.
    Install-Module -Name Microsoft.Graph -Scope CurrentUser -Force
}

# Import the Microsoft.Graph module like a boss
Import-Module Microsoft.Graph

# Time to connect to Microsoft Graph with the right spells... I mean, scopes!
Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read.All"

# Let's summon all groups - you never know what lurks in there!
Get-MgGroup

```

Now that I'm authenticated using the PowerShell for Graph API modules, it's time to roll up our sleeves and dive into the mystical world of group creation. Microsoft has already provisioned a subset of groups for us, but hey, we're not ones to settle for the basics!

Groups:
![Introduction](./assets/img/pim-for-groups/PreProvisoionedgroups.png)

Now lets create some groups, naming standards may vary But I use the following
{ prefix }-{ system }-{ type }-{ region }-{ LzName }-{role}

For this demo I will create the following 3 groups
> d-avd-sec-weu-sandbox-lz-dikkekip-AdminAccess
> d-jira-sec-weu-sandbox-lz-dikkekip-AdminAccess
> d-demo-sec-weu-sandbox-lz-dikkekip-AdminAcess

With this part of the script we will create the groups and add the user we create the groups with as admin.

```Powershell
$context = Get-MgContext
$userPrincipalName = $context.Account 

# Now you, dear reader, can define your own group names and descriptions!
$groupsToCreate = Read-Host "Enter your group names and descriptions in the format 'name:description', separated by commas"
$groupArray = $groupsToCreate -split "," | ForEach-Object { 
    $split = $_ -split ":"
    @{ name = $split[0].Trim(); description = $split[1].Trim() }
}

foreach ($entry in $groupArray) {
    # Check if the groups already exist in your magical Entra ID realm
    $group = Get-MgGroup -Filter "DisplayName eq '$($entry.name)'"
    if ($group) {
        # If the group exists but the description is off, let's update it.
        if ($entry.description -and $group.description -ne $entry.description) {
            Write-Host "[$($user.UserPrincipalName)] Updating description for Group [$($entry.name)][$($group.Id)]"
            Update-MgGroup -GroupId $group.Id -Description $entry.description
        } else {
            Write-Host "[$($user.UserPrincipalName)] Group [$($entry.name)][$($group.Id)] already exists. Skipping."
        }
    } else {
        Write-Host "[$($user.UserPrincipalName)] Creating group [$($entry.name)]."
        # Time to create the group, with you as the owner. Why, you ask?
        $GroupBody = @{
            DisplayName         = $entry.name
            Description         = $entry.description
            MailEnabled         = $false
            MailNickname        = $entry.name
            SecurityEnabled     = $true
            "Owners@odata.bind" = @("https://graph.microsoft.com/v1.0/users/$userPrincipalName")
        }
        New-MgGroup -BodyParameter $GroupBody
    }
}
```

Bring groups into Privileged Identity Management
Discamer, I have to revert to the old api here, I can uforutnatly not find a methoth to do this with the Graph API :( if anyone can please let me know 
The old 
https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/groups-discover-groups



Why do we add ourselves as the owner? In the world of Entra ID, being the owner of a group isn't just a title; it's a key to the kingdom. You need to be the owner to assign users as eligible members. Think of it as having the master key to the castle – without it, you can't really manage the inhabitants (users) of your Entra ID estate.

This script gives you the flexibility to define your own group names and descriptions. It's like giving you the pen to write your own story in the Entra ID saga.

---

*Remember, this is not just about making things work; it's about making them work with style and efficiency. As we say in the Cloud DevOps world, "The best code is the one that brings a smile to your face!" 😄👨‍💻*

---

Stay tuned for more nerdy adventures in cloud computing, and don't forget to share your thoughts and experiences in the comments below!

*Cheers, Maarten* 🍻💼