# SilenceTheLAN Design Document

**Date:** 2025-12-27
**Status:** Approved

## Overview

SilenceTheLAN is an iOS app for parents to quickly enable/disable pre-configured "downtime" ACL rules on a locally deployed UniFi network. The app provides instant, gorgeous UI for toggling internet access for family members without navigating the full UniFi web interface.

## User Experience

### Core Interaction

- **Dashboard-first:** App opens directly to the main dashboard
- **Dual-mode usage:** Quick single-tap toggles AND overview of all rules
- **Gorgeous dark theme:** Premium visual design using deep blacks with vibrant accent colors

### Dashboard

- Simple vertical list of toggle cards (evolve to grouped-by-person later)
- Each card shows:
  - Rule name (extracted: "Downtime-Rishi" → "Rishi")
  - Current state via color: green glow (active) / red glow (blocked)
  - Large toggle switch

### Toggle Interaction

1. User taps toggle → immediate visual flip + haptic pulse
2. Subtle loading shimmer while API call executes
3. Success: state confirmed, brief success haptic
4. Failure: auto-revert to previous state, error haptic, toast message

### Offline Behavior

- "Offline" pill badge at top of screen
- Cards show last known state (dimmed)
- Toggles visually disabled
- Pull-to-refresh to retry connection

## Setup Flow

### 1. Welcome Screen
- App name + tagline: "Control your kids' internet with a tap"
- Single "Get Started" button

### 2. Network Discovery (Automatic)
- Detect iPhone's current IP, probe common gateway IPs
- Test HTTPS on port 443
- Found: "Found UniFi at 192.168.1.1" + Continue
- Not found: Manual entry fallback

### 3. API Key Entry
- Secure text field
- Collapsible "How to get an API key" instructions
- "Verify" button tests with real API call

### 4. Site ID Discovery
- Attempt to fetch available sites from API
- Single site: auto-select
- Multiple sites: picker list
- Failure: manual UUID entry

### 5. Rule Selection
- Fetch ACL rules, filter to "downtime*" (case-insensitive)
- Checkboxes with "Select All" option
- Save → transition to Dashboard

## Architecture

### MVVM Structure

```
Views (SwiftUI)
    ↓ binds to
ViewModels (ObservableObject)
    ↓ calls
Services (async/await)
    ↓ uses
Models (SwiftData + Codable)
```

### Key Components

| Component | Responsibility |
|-----------|---------------|
| UniFiAPIService | HTTP calls, SSL trust, error mapping |
| KeychainService | Secure API key storage |
| NetworkMonitor | WiFi/connectivity detection, offline mode |
| ACLRuleStore | SwiftData container for cached rules + config |

### Data Flow: Toggle

```
User taps toggle
    → ViewModel updates local state (optimistic)
    → Haptic fires
    → ViewModel calls UniFiAPIService.toggleRule()
        → GET current rule (fetch latest state)
        → PUT with enabled flipped
    → Success: confirm state, save to SwiftData cache
    → Failure: revert local state, show error toast
```

### Offline Detection

- `NWPathMonitor` watches network changes
- On WiFi change: attempt to reach UniFi controller
- Reachable: enable toggles, refresh state
- Unreachable: show "Offline" badge, disable toggles, show cached state

### Caching Strategy

- SwiftData stores last-known state of all selected rules
- App launch: show cached immediately, then refresh from API
- Cache updates on every successful API response

## Error Handling

| Error | User Experience |
|-------|-----------------|
| 401 Unauthorized | Toast + prompt to re-enter API key |
| 400 Bad Request | Toast: "Update failed" + auto-revert |
| 404 Not Found | Rule deleted; remove from app, notify user |
| Network timeout | Toast + auto-revert |
| SSL error | Setup: explain cert; after: treat as offline |

### Edge Cases

1. **Rule renamed in UniFi** - Update local cache on refresh
2. **Rule deleted in UniFi** - Remove from selection, notify user
3. **New matching rules** - User must manually add via Settings
4. **API key revoked** - Persistent "Re-authenticate" banner
5. **Rapid toggles** - Debounce; ignore while request in-flight

### Retry Strategy

- No automatic retry on user actions
- App launch: retry once after 2s delay
- Offline: no retries, wait for network change

## Visual Design

- **Theme:** Dark mode only (deep blacks #000)
- **Accents:** Vibrant green (#00FF88) for active, warm red (#FF4444) for blocked
- **Style:** Minimal chrome, focus on toggle cards
- **Implementation:** Use frontend-design skill for premium aesthetic

## Implementation Phases

### Phase 1: MVP (Current)
- Onboarding with auto-discovery
- API Key + Site ID configuration
- Rule selection (filter "downtime*")
- Dashboard with toggle cards
- Optimistic toggle + haptic + auto-revert
- Offline detection + cached state
- Settings screen
- Dark theme UI

### Phase 2: Polish
- Pull-to-refresh animation
- App icon + launch screen
- Better error toasts
- State change animations

### Phase 3: Quick Access
- iOS Home Screen Widgets
- Siri Shortcuts integration
- App Intents

### Phase 4: Advanced
- Grouped by person view
- Scheduled rules
- Multiple controller support

## Out of Scope (YAGNI)

- Rule creation/editing (use UniFi web UI)
- User authentication/multi-user
- Cloud sync
- Push notifications
- iPad optimization
