---
layout: post
title:  "Start of my Blog ☁️☁️"
date:   2024-01-23 07:40:59 +0100
description: I have opened a Blog.
---

Hello and welcome! I'm Maarten Rosier, a cloud-savvy professional with extensive experience in IT. Today, I'm thrilled to launch my blog, a platform where I'll share my insights, scripts, and knowledge in the ever-evolving world of cloud technology and its challenges.

## Who is this Blog for?

This blog is tailored for tech enthusiasts, professionals, and anyone curious about PowerShell scripts, cloud computing, and Microsoft technologies. Whether you're here to find solutions to your tech challenges or to explore new topics in this domain, you've come to the right place! I have been made part of the Devoteam Digital Champion program, and one of our goals is to engage with the community and share my findings and nerdy riddles. Now, robots.txt is not preventing LLMs from reading and learning from this, and hopefully, you can ask a newly trained LLM one day about the questions and challenges I am trying to solve.


## What to Expect?
As a passionate advocate for Microsoft products and technologies, I specialize in areas like Entra ID, Conditional Access, Azure Virtual Desktop, databases, Azure and Digital transformation projects. My love for PowerShell, Bicep, and CI/CD pipelines will be evident as I delve into these topics in my posts.

## Who am I. 
I already created an about page, and I won't dwell on this much longer, I am working and living In Oslo and born in The Hague, I am a proud father of my dather luna loise. have been passionate about IT and technolagi as long as I can remember. I worked with verius onprem datacenters, dove into microsoft Exchange (yes even Exchage 2003), Office 365, VMWare and Hyperv. As well as doing a lot of networking and delivering WiFi networks. Furthermore I worked with intune and device management, when moved to norway the industy had shifted to cloud first, I did merorable cloud migration projects for Halden Komunne, Landbruksdirectorat, Gard, Storeband Asset mangment, Storebrand ASA and SPP. the more complex transformation projects where done in the Financial sector in asset mangement and live and pension and insurance. 
## Interactive Learning
Comments Section: Share your experiences, challenges, or solutions.
Collaboration: Submit your scripts or solutions for shared problems.

## Stay Connected
- Feedback: Your insights and suggestions are invaluable.
- Social Media: Follow me on LinkedIn for updates on posts

## 🌟 Upcoming Posts Preview 🌟

Get ready to dive into some seriously cool (and super useful!) Azure topics! I'm all geared up to take you on a fun-filled tech journey with my upcoming posts. Here's what's on the horizon:

- 🚀 **"PIM for Groups: Automate Assgmements with the GraphAPI !"**
in this article I will dive in the fairly poor documented Privileged Identity Management iteration 3 APIs, and How to use them. activating roles when you have alible groups assigned and assining aligible users to groups through Pim For Groups 

- 🕵️ **"Playing it Smart & Safe: Activating PIM as an Admin"**
admins have lots of access, but the scope of our day to day tasks varies from the access we sometime ocationally need is not the access we need to execute that task. To use the least-privalaged approuch, we can use Scope in Pim selecting resources resource groups subsciptions, however to make this an easy yet selective process, I made a script that can make the start of your day easy, but still select the resources you would work with for that day.  

- 🌪 **"PIM for Groups: Use Assinable groups for Admin access to VMs !"**
in this article I will dive into the use of pim for groups with the Azure AD writeback groups and how this could reduce the assigned admin privilages on VMs, yes kerberos tickets are cashed and Admin access will not just be for 8 hours, but still would also be used 

Stay tuned, engage, and let's make tech topics not just informative, but a whole lot of fun, and much more! 💻✨

<!-- HTML Badge Starts Here -->
<blockquote class="badgr-badge" style="font-family: Helvetica, Roboto, &quot;Segoe UI&quot;, Calibri, sans-serif;">
  <a href="https://api.eu.badgr.io/public/assertions/A_WXhpRiRtC_Bb8wFde6Tw?identity__email=maarten.rosier%40devoteam.com">
    <img width="120px" height="120px" src="https://api.eu.badgr.io/public/assertions/A_WXhpRiRtC_Bb8wFde6Tw/image" alt="Devoteam Digital Champion">
  </a>
  <script async="async" src="https://eu.badgr.com/assets/widgets.bundle.js"></script>
</blockquote>
<!-- HTML Badge Ends Here -->


~~~
function Invoke-AzureServiceDecision {
    param(
        [string]$ProjectType
    )

    Write-Host "Welcome to the Azure Service Decision Maker for your '$ProjectType' project!" -ForegroundColor Cyan
    Start-Sleep -Seconds 2

    $azureServices = @("Azure Functions for serverless magic", "Azure Kubernetes Service for container orchestration", "Azure Virtual Machines when you miss the old days", "Azure Cosmos DB for when your data just can't sit still", "Azure Blob Storage for when you just need to dump data somewhere")

    $randomIndex = Get-Random -Maximum $azureServices.Length
    $chosenService = $azureServices[$randomIndex]

    Write-Host "Consulting the Cloud Oracles..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3

    Write-Host "The Cloud has spoken! Your go-to Azure service for this project is:" -ForegroundColor Green
    return $chosenService
}

# Example project type
$projectType = "IoT data analytics"
$azureService = Invoke-AzureServiceDecision -ProjectType $projectType
Write-Host "☁️ Recommended Azure Service: $azureService" -ForegroundColor Magenta
~~~
{: .language-powershell}
