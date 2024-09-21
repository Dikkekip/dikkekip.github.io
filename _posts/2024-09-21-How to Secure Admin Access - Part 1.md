---
layout: post
title:  "🚀 How to Secure Admin Access! - Part 1"
date:   2024-09-24 07:40:59 +0100
comments: true
description: "**Securing Admin Access** in **Microsoft Entra ID*"
categories: [Entra ID, Cloud Security, Access Management, Azure Automation, IT Security, Cloud Administration, Microsoft Azure, DevOps Practices]
tags: [Entra ID, Cloud Security, Access Management, Azure Automation, IT Security, Cloud Administration, Microsoft Azure, DevOps Practices]
image:
  path: assets/img/1725962735025.gif
  src: assets/img/1725962735025.gif
toc: true
---


## Fortify Your Castle: How to Secure Admin Access with Phishing-Resistant Authentication and Token Protection

Hello, fellow tech enthusiasts! 🎉 As we celebrate our **Microsoft Identity and Access Management Specialization renewal** at Devoteam, I thought it would be the perfect time to dive into a topic that's been buzzing in the IT corridors lately: **Securing Admin Access** in **Microsoft Entra ID**.

Imagine you're the ruler of a vast kingdom (your organization), and you've built towering walls (firewalls), installed drawbridges (VPNs), and hired the best guards (antivirus software). But somehow, pesky invaders (cyber attackers) still find a way in! How? Well, it's time we talk about **phishing-resistant authentication**, **token theft**, and how to truly **fortify your castle**.

So grab a cup of your favorite brew ☕, and let's embark on this security adventure together!

---

### The Evolving Threat Landscape: Why Phishing-Resistant Authentication Isn’t Enough

First off, let's address the elephant in the room. Phishing attacks have become more sophisticated, and traditional passwords are as outdated as a medieval catapult in modern warfare.

Enter **Passkeys**, **FIDO2 keys**, and **Windows Hello for Business (WHfB)**—our shiny new armor. These **phishing-resistant** methods are fantastic. They eliminate passwords and ensure only the intended user can authenticate. For Global Admins or Security Admins, these are *must-haves*. After all, we wouldn't want the keys to the kingdom falling into the wrong hands, would we?

But here's where the plot thickens: **Token Theft**.

Even with these robust methods, attackers have found sneaky ways to bypass defenses. It's like having a moat filled with crocodiles but forgetting about the secret tunnel underneath. Attackers use malware and advanced tactics like **Adversary-in-the-Middle (AiTM)** attacks to steal authentication tokens, granting them the same access as legitimate users.

> **Real-World Scenario**: Microsoft's incident response team uncovered cases where attackers installed malware on admin devices, stealing tokens and gaining unauthorized access—all without triggering traditional security alarms.

---

### Continuous Access Evaluation: Your Real-Time Defense Shield 🛡️

So, how do we fend off these cunning invaders? Meet **Continuous Access Evaluation (CAE)**—our vigilant watchtower that never sleeps.

**CAE** provides near real-time token validation and policy enforcement. If it detects something fishy—like a token being used from an unexpected location—it can **immediately revoke that token**, shutting down any potential attacks faster than you can say "password123."

**Services Supported by CAE**:

- **Exchange Online**
- **SharePoint Online**
- **Microsoft Teams**

This means your communication channels are guarded by CAE's ever-watchful eye.

> **Note**: While CAE is powerful, it doesn't cover all services yet. So, we need to layer our defenses.

---

### Strengthening Your Defenses: Compliant Devices and Windows Hello for Business

Imagine if every guard entering your castle had to pass a rigorous health check. That's what **compliant device policies** do—they ensure only devices meeting your security standards can access your resources.

**Windows Hello for Business (WHfB)** is like giving each guard a unique, unforgeable badge:

- **Passwordless Authentication**: Say goodbye to passwords!
- **Multi-Factor Authentication**: Combines device possession with biometrics or PIN.
- **Hardware-Based Security**: Credentials are stored securely on the device.

By combining WHfB with compliant device policies, we ensure that only **trusted knights on trusted steeds** enter our realm. This also protects against **Adversary-in-the-Middle (AiTM)** attacks, as credentials cannot be intercepted or replayed.

---

### Compliant Network Checks: Keeping the Drawbridge Up 🏰

Now, let's talk about controlling access points. **Compliant Network Checks** ensure that only devices connected via a **trusted network** can access your resources.

Enter the **Global Secure Access Client**—our modern-day portcullis:

- **Simplified Management**: No need to juggle IP addresses.
- **Enhanced Security**: Only devices on your secure network gain access.
- **Flexibility**: Ideal for remote work scenarios.

By deploying this client, you add another layer of security. Even if a token is stolen, without access to your compliant network, attackers are left out in the cold.

For a step-by-step guide, check out [Enable Compliant Network Check with Conditional Access](https://learn.microsoft.com/entra/global-secure-access/how-to-compliant-network#compliant-network-check-enforcement).

---

### Privileged Access Workstations (PAWs): Your Secure Command Center 🖥️

Think of **Privileged Access Workstations (PAWs)** as your secure war room—accessible only to the highest-ranking officials.

**Why PAWs?**

- **Dedicated Devices**: Used exclusively for administrative tasks.
- **Hardened Security**: Enhanced settings and limited software.
- **Isolated Network Access**: Reduces exposure to threats.

By isolating admin activities, you minimize risks. It's like discussing battle plans in a soundproof room rather than a crowded tavern.

---

### Persona-Based Authentication: Custom Armor for Every Role 🛡️

Not all your subjects need the same level of protection. A blacksmith doesn't need the king's guard detail, right?

**Persona-Based Authentication** allows you to tailor authentication methods and policies to different user roles based on their risk profiles.

#### What is Persona-Based Authentication?

It's a strategy where you define personas—groups of users with similar roles or security requirements—and assign appropriate authentication methods and policies to each.

**Example Personas at Devoteam**:

1. **Admins**:

   - **Authentication Methods**:
     - Phishing-resistant MFA (FIDO2 keys, WHfB).
     - Passwordless authentication.
   - **Policies**:
     - Require compliant devices.
     - Enforce compliant network checks.
     - Apply strict session controls (e.g., sign-in frequency).
     - Limit access to sensitive applications.

2. **Externals**:

   - **Authentication Methods**:
     - MFA using Authenticator app or phone call.
   - **Policies**:
     - Limit access to specific applications.
     - Enforce time-bound access.
     - Require device compliance if possible.
     - Monitor for unusual activities.

3. **Developers**:

   - **Authentication Methods**:
     - MFA required.
     - Passwordless preferred.
   - **Policies**:
     - Enforce device compliance.
     - Require access from specific network locations.
     - Implement Conditional Access App Control for data exfiltration prevention.

By customizing authentication methods and policies per persona, you strike the right balance between security and usability.

#### Benefits of Persona-Based Authentication

- **Enhanced Security**: High-risk roles get stronger authentication methods.
- **Improved User Experience**: Users don't face unnecessary hurdles.
- **Regulatory Compliance**: Meet specific compliance requirements for certain roles.
- **Adaptability**: Quickly adjust policies as roles and threats evolve.

#### Implementing Persona-Based Authentication

1. **Identify Personas**: Group users based on roles, responsibilities, and security needs.

2. **Define Authentication Methods**:

   - **High-Risk Roles**: Use phishing-resistant methods like FIDO2 or WHfB.
   - **Standard Users**: Use MFA methods like Authenticator app or SMS (though SMS is less secure).

3. **Configure Conditional Access Policies**:

   - Assign policies to each persona.
   - Set conditions and controls appropriate for each group.

4. **Communicate and Train**:

   - Inform users about new authentication methods.
   - Provide training resources and support.

5. **Monitor and Adjust**:

   - Regularly review authentication logs.
   - Adjust policies based on emerging threats or organizational changes.

6. **Leverage Azure AD Authentication Strengths**:

   - Use authentication strengths in Conditional Access to specify required authentication methods for accessing resources.

---

### Bringing It All Together: Your Security Blueprint 📜

Let's recap our master plan to secure the realm:

1. **Phishing-Resistant Authentication**:

   - Deploy FIDO2 keys, Passkeys, or WHfB.
   - Shield against credential theft and AiTM attacks.

2. **Compliant Device Policies**:

   - Ensure devices meet security standards.
   - Reduce malware risks.

3. **Continuous Access Evaluation (CAE)**:

   - Activate CAE for supported services.
   - Enable real-time threat response.

4. **Compliant Network Checks**:

   - Use the Global Secure Access Client.
   - Limit access to trusted networks.

5. **Privileged Access Workstations (PAWs)**:

   - Isolate admin tasks on secure devices.
   - Minimize token theft risks.

6. **Persona-Based Authentication**:

   - Tailor authentication methods and policies to user roles.
   - Balance security with usability.

By layering these defenses, you're not just building a wall—you're creating an impenetrable fortress.

---

### Final Thoughts: Stay One Step Ahead 🚀

Cybersecurity isn't a destination; it's a journey. Threats evolve, but so do our defenses. By staying informed and proactive, you ensure your castle remains unbreached.

Remember, in the words of a wise strategist: *"The best offense is a good defense."* So let's keep our shields up and our wits sharper!

> **⚠️ Pro Tip**: Always keep a **break-glass account** handy! I've been there—locked out of my tenant while setting up MFA. *Spoiler alert: it wasn't fun.* 🙃

---

### Additional Resources 📚

- **Continuous Access Evaluation**:

  - [Understanding CAE](https://learn.microsoft.com/azure/active-directory/conditional-access/concept-continuous-access-evaluation)
  - [Implementing CAE](https://learn.microsoft.com/azure/active-directory/conditional-access/howto-continuous-access-evaluation)

- **Compliant Network Check**:

  - [Enable Compliant Network Check with Conditional Access](https://learn.microsoft.com/entra/global-secure-access/how-to-compliant-network#compliant-network-check-enforcement)

- **Windows Hello for Business**:

  - [Deployment Guide](https://learn.microsoft.com/windows/security/identity-protection/hello-for-business/hello-deployment-guide)

- **Privileged Access Workstations**:

  - [PAW Overview](https://learn.microsoft.com/security/compass/privileged-access-workstations)

- **Persona-Based Authentication**:

  - [Conditional Access Authentication Strengths](https://learn.microsoft.com/azure/active-directory/authentication/concept-authentication-strengths)
  - [Plan a Conditional Access Deployment](https://learn.microsoft.com/azure/active-directory/conditional-access/plan-conditional-access)

---

### What's Next? The Adventure Continues...

Stay tuned for future posts where we'll delve deeper into implementing these strategies and share more insights on keeping your digital kingdom secure.

So, polish your armor and ready your shields—the quest for ultimate security continues!

---

Until next time—stay nerdy, stay secure, and may your tokens always be protected! 👨‍💻🔐

---

**P.S.** Have any tales of your own security adventures? Share them in the comments below! Let's learn and grow together.

---