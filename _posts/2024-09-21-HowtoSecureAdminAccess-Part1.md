---
layout: post
title:  "How to Secure Admin Access! - Part 1"
date:   2024-09-21 10:00:00 +0530
comments: true
description: "Securing Admin Access in Microsoft Entra ID: Phishing-Resistant Authentication, Token Protection, and More!"
categories: [Entra ID, Cloud Security, Access Management, Azure Automation, IT Security, Cloud Administration, Microsoft Azure, DevOps Practices]
tags: [Entra ID, Cloud Security, Access Management, Azure Automation, IT Security, Cloud Administration, Microsoft Azure]
image:
  path: /assets/img/1725962735025.gif
  src: /assets/img/1725962735025.gif
toc: true
---


## Fortify Your Castle: How to Secure Admin Access with Phishing-Resistant Authentication and Token Protection

Hello, fellow tech enthusiasts! 🎉 As we celebrate our **Microsoft Identity and Access Management Specialization renewal** at Devoteam, I thought it would be the perfect time to dive into a topic that's been buzzing in the IT corridors lately: **Securing Admin Access** in **Microsoft Entra ID**.

Imagine you're the ruler of a vast kingdom (your organization), and you've built towering walls (firewalls), installed drawbridges (VPNs), and hired the best guards (antivirus software). But somehow, pesky invaders (cyber attackers) still find a way in! How? Well, it's time we talk about **phishing-resistant authentication**, **token theft**, and how to truly **fortify your castle**.

So grab a cup of your favorite brew ☕, and let's embark on this security adventure together!


### The Evolving Threat Landscape: Why Phishing-Resistant Authentication Isn’t Enough

First off, let's address the elephant in the room. Phishing attacks have become more sophisticated, and traditional passwords are as outdated as a medieval catapult in modern warfare.

Enter **Passkeys**, **FIDO2 keys**, and **Windows Hello for Business (WHfB)**—our shiny new armor. These **phishing-resistant** methods are fantastic. They eliminate passwords and ensure only the intended user can authenticate. For Global Admins or Security Admins, these are *must-haves*. After all, we wouldn't want the keys to the kingdom falling into the wrong hands, would we?

But here's where the plot thickens: **Token Theft**.

Even with these robust methods, attackers have found sneaky ways to bypass defenses. It's like having a moat filled with crocodiles but forgetting about the secret tunnel underneath. Attackers use malware and advanced tactics like **Adversary-in-the-Middle (AiTM)** attacks to steal authentication tokens, granting them the same access as legitimate users.

> **Real-World Scenario**: Microsoft's incident response team uncovered cases where attackers installed malware on admin devices, stealing tokens and gaining unauthorized access—all without triggering traditional security alarms.

### Entra ID OAuth Tokens: A Brief Overview

**Entra ID OAuth tokens** are crucial for handling authentication and authorization in cloud environments. These tokens come in different types:

1. **ID Tokens**: Used for authentication, proving the user’s identity. Valid for 1 hour.
2. **Access Tokens**: Used for authorization, granting access to resources. Also valid for 1 hour.
3. **Refresh Tokens**: Used to obtain new access tokens without re-authentication, valid for up to 90 days.

Among these, **Primary Refresh Tokens (PRT)** and **Family of Refresh Tokens (FRT)** are particularly powerful. PRTs are essential for Single Sign-On (SSO) and provide persistent access across resources, while FRTs allow access across multiple applications. This makes them valuable targets for attackers in token-based attacks. Stolen tokens can be used to bypass security controls like Conditional Access.

Ensuring robust **token management** and security through **phishing-resistant MFA** and **Conditional Access policies** is critical to protecting your organization's resources from unauthorized access. For more details, you can refer to the full breakdown [here](https://www.xintra.org/blog/tokens-in-entra-id-guide/).	

---
# Continuous Access Evaluation: Your Real-Time Defense Shield 🛡️

Continuous Access Evaluation (CAE) enhances security by enabling real-time token validation, allowing tokens to be revoked immediately when critical changes occur—such as a password reset, account compromise, or network location shift. This dynamic validation makes it harder for attackers to misuse stolen tokens.

## What Is CAE?

Unlike the standard one-hour token expiration, CAE ensures tokens are re-evaluated when necessary. It creates a continuous conversation between Microsoft Entra ID and services like Exchange Online, Teams, and SharePoint Online, enabling immediate action on security risks.

## Benefits of CAE

- **Real-time response**: Tokens are dynamically updated in response to events like password changes or location changes, revoking access when conditions change.
- **Network enforcement**: Integrates with Conditional Access policies to block tokens used from untrusted networks, reducing the risk of token replay attacks.

## Where CAE Works—and Where It Doesn’t

While CAE supports Exchange Online, Teams, and SharePoint Online, **it cannot currently be used for Tier-0 admin access**. This is because the Azure Portal and Microsoft 365 endpoints do not support CAE-enabled clients, leaving a gap for these high-privilege accounts. 

Admin accounts typically don’t rely on email or communication services, and once authenticated, the session token is still valid for up to an hour. This leaves potential vulnerability post-authentication, as CAE is unable to trigger a real-time re-evaluation of the token for admin access scenarios.

However, there is a potential future where CAE could become a valuable defense for Tier-0 admin access. If CAE support is extended to the Azure Portal and Microsoft 365 endpoints, it would allow for stricter token control. **Combining CAE with tools like the Global Connect client and trusted location Conditional Access policies** would provide tight control over token issuance, greatly reducing the risk of token replay attacks. But for now, we have to rely on other security measures.

### Current Solutions for Securing Admin Accounts

To secure Tier-0 resources and admin accounts today, CAE must be used in combination with:
- **Privileged Access Workstations (PAWs)**: Dedicated workstations for admin tasks, isolated from regular day-to-day operations.
- **Conditional Access policies**: Enforce trusted locations and strict network conditions.
- **Phishing-resistant MFA**: Adds an extra layer of protection by ensuring only authorized users can access admin accounts.

These measures ensure that even if a token is stolen, other layers of defense remain in place to protect critical resources.

## The Future of CAE

CAE is a valuable layer in modern security strategies, and as it expands to cover more services, it will play an even more critical role in protecting environments. The future could bring support for Tier-0 admin accounts, which would be a game-changer for securing high-value tokens in real time. Until then, CAE remains a key component of overall security but should be supplemented by other advanced measures for high-value accounts.

For more information, visit [CAE strict enforcement](https://learn.microsoft.com/en-us/entra/identity/conditional-access/concept-continuous-access-evaluation-strict-enforcement).

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

- **High-Risk Roles**: Require stronger authentication methods.
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

6. **Leverage Entra ID Authentication Strengths**:

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


4. **Compliant Network Checks**:

   - Use the Global Secure Access Client.
   - Limit access to trusted networks.

5. **Privileged Access Workstations (PAWs)**:

   - Isolate admin tasks on secure devices.
   - Minimize token theft risks.

7. **Persona-Based Authentication**:

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
  - [Persona-Based Conditional](https://learn.microsoft.com/en-us/azure/architecture/guide/security/conditional-access-architecture)

---

### What's Next? The Adventure Continues...

Stay tuned for future posts where we'll delve deeper into implementing these strategies and share more insights on keeping your digital kingdom secure.

So, polish your armor and ready your shields—the quest for ultimate security continues!

---

Until next time—stay nerdy, stay secure, and may your tokens always be protected! 👨‍💻🔐

---

**P.S.** Have any tales of your own security adventures? Share them in the comments below! Let's learn and grow together.

---