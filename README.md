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

| Current State | Tap Action | Result |
|---------------|------------|--------|
| Blocking (in schedule window) | Pause | Allows traffic temporarily |
| Blocking (manual override) | Pause | Allows traffic temporarily |
| Paused | Unpause | Resumes scheduled behavior |
| Allowed (outside schedule) | Block Now | Blocks immediately |

When you pause a rule, the original schedule is preserved. Unpausing restores normal scheduled behavior.

## Requirements

- **iOS 17.0+** (uses SwiftData)
- **UniFi Dream Machine** (UDM, UDM Pro, UDM SE) or **UniFi Cloud Gateway** (UCG Max, UCG Ultra)
- **Local network access** - iPhone must be on the same network as the UniFi controller
- **Local UniFi account** - Cloud/SSO accounts with 2FA are not supported

## Setup

### 1. Create Firewall Rules in UniFi

In your UniFi Console, create firewall policies for each person/device you want to control:

1. Go to **Settings > Security > Firewall Rules**
2. Create a new rule with:
   - **Name**: Must start with `Downtime` (e.g., `Downtime-Kids`, `Downtime-Gaming`)
   - **Action**: `Block`
   - **Schedule**: Set your normal blocking schedule (e.g., 11 PM - 7 AM)
   - **Source**: Select the devices to block
   - **Destination**: Usually "Any" or specific domains

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
