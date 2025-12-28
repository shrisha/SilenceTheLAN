# SilenceTheLAN

A SwiftUI iOS app for parents to quickly manage internet access for their kids on UniFi networks.

## Overview

SilenceTheLAN gives parents instant control over pre-configured "Downtime" firewall rules on their UniFi router. Instead of navigating the full UniFi web interface, toggle internet access for specific family members with a single tap.

**Key Features:**
- **One-tap control** - Block or allow internet instantly
- **Pause/Resume** - Temporarily allow access during scheduled block times
- **Block Now** - Immediately block access outside scheduled times
- **Real-time status** - See who's blocked and who's allowed at a glance
- **Schedule awareness** - Shows normal schedule times even when overridden
- **Dark mode UI** - Beautiful, modern interface with glassmorphism effects

## How It Works

SilenceTheLAN manages UniFi firewall policies that have names starting with "Downtime" and action set to "BLOCK". The app doesn't create rules - you configure them in UniFi, and the app provides quick toggle access.

### Toggle Behavior

The app intelligently handles toggling based on the rule's current state, schedule, and time of day:

#### ALLOW Action (Currently Blocking → Allow Traffic)

| Current State | Has Original Schedule? | Action Taken | Result |
|--------------|------------------------|--------------|--------|
| Blocking via ALWAYS mode | Yes | Restore schedule | Returns to scheduled behavior; if currently inside schedule window, also pauses |
| Blocking via ALWAYS mode | No | Pause rule | Traffic allowed until manually unpaused |
| Blocking via schedule (in window) | N/A | Pause rule | Traffic allowed until manually unpaused |

#### BLOCK Action (Currently Allowed → Block Traffic)

| Current State | Time vs Schedule | Has Original Schedule? | Action Taken | Result |
|--------------|------------------|------------------------|--------------|--------|
| Paused | Inside original window | Yes (mode=ALWAYS) | Restore schedule + unpause | Schedule blocks traffic |
| Paused | Inside window | Yes (mode=scheduled) | Unpause | Schedule blocks traffic |
| Paused | Outside window | Yes | Set ALWAYS + unpause | Blocks immediately |
| Paused | N/A | No | Set ALWAYS + unpause | Blocks immediately |
| Allowed (outside schedule) | N/A | Yes | Set ALWAYS (preserve schedule) | Blocks immediately; schedule saved for later |
| Allowed (outside schedule) | N/A | No | Set ALWAYS | Blocks immediately |

#### Key Concepts

- **Pause**: Disables the rule temporarily (traffic flows)
- **ALWAYS mode**: Rule blocks 24/7 regardless of schedule
- **Original schedule**: Preserved when switching to ALWAYS, restored when allowing traffic
- **Schedule window**: The time range when the rule would normally block (e.g., 11 PM - 7 AM)

## Requirements

- **iOS 17.0+** (uses SwiftData)
- **UniFi Dream Machine** (UDM, UDM Pro, UDM SE) or **UniFi Cloud Gateway** (UCG Max, UCG Ultra)
- **Local network access** - iPhone must be on the same network as the UniFi controller
- **Local UniFi account** - Cloud/SSO accounts with 2FA are not supported

## Setting Up Firewall Policies in UniFi

Before using SilenceTheLAN, you need to create firewall policies in your UniFi Console. The app discovers and manages these policies - it doesn't create them.

### Concept

UniFi firewall policies let you block traffic based on source devices, destinations, and schedules. SilenceTheLAN looks for policies with:
- **Name** starting with `Downtime` (case-insensitive)
- **Action** set to `Block`

The app then provides quick toggle access to pause/unpause these rules or override schedules.

### Naming Convention

The app parses rule names to group them by person and activity:

```
Downtime-{PersonName}
Downtime-{PersonName}-{Activity}
```

| Rule Name | Person | Activity | Display |
|-----------|--------|----------|---------|
| `Downtime-Rishi` | Rishi | Internet | Shows as "Internet" under "Rishi" |
| `Downtime-Rishi-Games` | Rishi | Games | Shows as "Games" under "Rishi" |
| `Downtime-Rohan-YouTube` | Rohan | YouTube | Shows as "YouTube" under "Rohan" |
| `Downtime-Kids` | Kids | Internet | Shows as "Internet" under "Kids" |

Rules for the same person are grouped together in the app, making it easy to manage multiple restrictions per family member.

### Creating a Policy

1. In UniFi Console, go to **Settings > Security > Firewall Rules**
2. Click **Create New Rule** and configure:

| Field | Recommended Setting | Notes |
|-------|---------------------|-------|
| **Name** | `Downtime-{Person}` or `Downtime-{Person}-{Activity}` | Must start with "Downtime" |
| **Action** | `Block` | Required for the app to manage it |
| **Schedule** | Your normal blocking hours (e.g., 11 PM - 7 AM) | App preserves this when overriding |
| **Source** | Specific devices or device groups | Select the devices to control |
| **Destination** | `Any` or specific domains/IPs | What to block |

### Schedule Configuration

Set up schedules based on your family's routine:

| Schedule Type | Example | Use Case |
|---------------|---------|----------|
| **Nightly** | 10 PM - 7 AM | School night internet cutoff |
| **Extended** | 9 PM - 8 AM | Younger kids, earlier bedtime |
| **Always** | 24/7 | Block specific sites permanently (like gaming during weekdays) |
| **Custom** | Weekdays only | Different rules for school days vs weekends |

The app shows the schedule in each rule card and preserves it when you manually override.

### Best Practices

1. **One rule per person for general internet** - `Downtime-Rishi` blocks all internet for that person
2. **Separate rules for specific activities** - `Downtime-Rishi-Games` can have different schedules than general internet
3. **Use device groups in UniFi** - Create groups like "Rishi's Devices" to easily manage multiple devices
4. **Stagger schedules by age** - Younger kids get earlier cutoffs
5. **Keep rule names short** - They display better in the app

### Example Setup

For a family with two kids (Rishi and Rohan):

| Rule Name | Schedule | Source | Destination |
|-----------|----------|--------|-------------|
| `Downtime-Rishi` | 11 PM - 7 AM | Rishi's Devices | Any |
| `Downtime-Rishi-Games` | Always | Rishi's Devices | Gaming IPs/Domains |
| `Downtime-Rohan` | 10 PM - 7 AM | Rohan's Devices | Any |
| `Downtime-Rohan-YouTube` | 8 PM - 8 AM | Rohan's Devices | YouTube domains |
| `Downtime-Rohan-Games` | Weekdays 4 PM - 6 PM (allowed), else blocked | Rohan's Devices | Gaming IPs |

In the app, this shows as:
- **Rishi** (2 rules): Internet, Games
- **Rohan** (3 rules): Internet, YouTube, Games

## Setup

### 1. Create Firewall Policies

Follow the [Setting Up Firewall Policies](#setting-up-firewall-policies-in-unifi) section above to create your rules in UniFi.

### 2. Create a Local Account

SilenceTheLAN uses session-based authentication. You need a local UniFi account:

1. In UniFi Console, go to **Settings > Admins & Users**
2. Create a new admin with **Local Access Only**
3. Use a strong password (this stays on your local network)

### 3. Configure the App

1. Launch SilenceTheLAN
2. The app will auto-discover your UniFi controller, or enter the IP manually
3. Enter your local account credentials
4. Select which "Downtime" rules to manage
5. Start controlling!

## Tech Stack

- **SwiftUI** - Modern declarative UI
- **SwiftData** - Local persistence for rules and settings
- **Async/Await** - Clean asynchronous networking
- **UniFi v2 API** - Direct communication with UniFi controller

## Architecture

```
SilenceTheLAN/
├── App/
│   └── SilenceTheLANApp.swift
├── Models/
│   ├── AppConfiguration.swift    # SwiftData model for settings
│   └── ACLRule.swift             # SwiftData model for firewall rules
├── Services/
│   ├── UniFiAPIService.swift     # UniFi API client
│   ├── KeychainService.swift     # Secure credential storage
│   └── NetworkMonitor.swift      # Reachability checking
├── ViewModels/
│   ├── AppState.swift            # Main app state
│   └── SetupViewModel.swift      # Onboarding flow state
├── Views/
│   ├── Dashboard/                # Main control screen
│   ├── Onboarding/               # Setup flow screens
│   └── Settings/                 # Settings and rule management
└── Utilities/
    ├── Theme.swift               # Colors and styling
    └── ViewModifiers.swift       # Custom SwiftUI modifiers
```

## API Reference

SilenceTheLAN uses the UniFi Network Application v2 API:

- **Authentication**: `POST /api/auth/login` with session cookies
- **List Policies**: `GET /proxy/network/v2/api/site/{site}/firewall-policies`
- **Update Policy**: `PUT /proxy/network/v2/api/site/{site}/firewall-policies/{id}`
- **Batch Update**: `PUT /proxy/network/v2/api/site/{site}/firewall-policies/batch`

The batch endpoint is used for pause/unpause operations as it allows partial updates.

## Security

- Credentials stored in iOS Keychain (not in app storage)
- All communication over HTTPS (self-signed cert handling for local controllers)
- No cloud connectivity - everything stays on your local network
- No telemetry or analytics

## Limitations

- Only works on local network (no remote access)
- Requires local UniFi account (no SSO/cloud accounts)
- Only manages existing "Downtime-*" BLOCK rules
- Cannot create or delete firewall rules (by design)

## License

MIT License - See [LICENSE](LICENSE) for details.

## Acknowledgments

- Built with SwiftUI and SwiftData
- Inspired by the need for quick parental controls without opening the full UniFi app
- UniFi and UniFi Network Application are trademarks of Ubiquiti Inc.
