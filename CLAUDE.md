# SilenceTheLAN

A SwiftUI iOS app for parents to manage parental control firewall policies on a locally deployed UniFi network system.

## Project Overview

SilenceTheLAN allows parents to quickly enable/disable pre-configured "downtime" firewall rules on their UniFi router directly from their iPhone. Instead of navigating the full UniFi web interface, parents can toggle internet access for specific family members with a simple tap.

## Prerequisites

Before using this app, the user must have:

1. **Locally deployed UniFi system** - The iOS device must be on the same network as the UniFi controller (UDM Pro, UDM SE, UCG Max, etc.)
2. **API Key from UniFi** - Created in the UniFi web interface under `Settings > Integrations > Create New API Key`
3. **Pre-configured ACL rules** - Firewall ACL rules with names beginning with "downtime" (case-insensitive) that the app will control

## Technology Stack

- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI
- **Persistence:** SwiftData
- **Networking:** URLSession with async/await
- **Minimum iOS:** 17.0 (for SwiftData)
- **Architecture:** MVVM

## UniFi API Reference

### Base URL Structure

For UDM Pro / UDM SE / UCG Max (UniFi OS devices) using the **Integration API** (v1):
```
https://{controller_ip}/proxy/network/integration/v1/sites/{siteId}/
```

Example: `https://192.168.1.1/proxy/network/integration/v1/sites/{siteId}/acl-rules`

The `{siteId}` is a UUID that identifies the site.

### Obtaining the Site ID

The siteId can be obtained in several ways:

1. **From UniFi Console URL** - When logged into UniFi, the URL contains the site ID
2. **Sites API** - `GET /proxy/network/integration/v1/sites` (if available)
3. **Manual Configuration** - User can find it in their UniFi settings

**TODO:** Investigate the Sites API endpoint to auto-discover the siteId during setup.

### Authentication

The app uses API Key authentication via the `X-API-Key` header:

```http
X-API-Key: {your_api_key}
```

All requests must also include:
```http
Content-Type: application/json
Accept: application/json
```

**Important:** The UniFi controller uses a self-signed SSL certificate. The app must handle SSL certificate trust for local network connections.

### Key Endpoints

#### List ACL Rules
```http
GET /proxy/network/integration/v1/sites/{siteId}/acl-rules
```

**Query Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `offset` | int32 | 0 | Pagination offset (>= 0) |
| `limit` | int32 | 25 | Results per page (0-200) |
| `filter` | string | - | Filter expression |

**Response (200 OK):**
```json
{
  "offset": 0,
  "limit": 25,
  "count": 10,
  "totalCount": 1000,
  "data": [
    { /* ACL Rule objects */ }
  ]
}
```

#### Get Single ACL Rule
```http
GET /proxy/network/integration/v1/sites/{siteId}/acl-rules/{aclRuleId}
```

**Path Parameters:**
- `siteId` (required): string <uuid>
- `aclRuleId` (required): string <uuid>

#### Update ACL Rule (Enable/Disable)
```http
PUT /proxy/network/integration/v1/sites/{siteId}/acl-rules/{aclRuleId}
```

**IMPORTANT:** This endpoint requires ALL required fields, not just the fields you want to change. You must send the complete object.

**Required Request Body Fields:**
| Field | Type | Description |
|-------|------|-------------|
| `type` | string | "IPV4" (required) |
| `enabled` | boolean | Enable/disable the rule (required) |
| `name` | string | ACL rule name (required) |
| `action` | string | "ALLOW" or "BLOCK" (required) |
| `index` | int32 | Rule priority, lower = higher priority (required, >= 0) |

**Optional Request Body Fields:**
| Field | Type | Description |
|-------|------|-------------|
| `description` | string | ACL rule description |
| `enforcingDeviceFilter` | object | Switch device IDs to enforce rule (null = all switches) |
| `sourceFilter` | object | Traffic source filter |
| `destinationFilter` | object | Traffic destination filter |
| `protocolFilter` | string[] | ["TCP"], ["UDP"], or ["TCP", "UDP"] (null = all protocols) |

**Example Request to Toggle a Rule:**
```json
{
  "type": "IPV4",
  "enabled": false,
  "name": "My Downtime Rule",
  "action": "BLOCK",
  "index": 2000,
  "description": "Block internet for kids room",
  "sourceFilter": null,
  "destinationFilter": null,
  "protocolFilter": null
}
```

### ACL Rule Object Structure (Response)

```json
{
  "type": "IPV4",
  "id": "497f6eca-6276-4993-bfeb-53cbbbba6f08",
  "enabled": true,
  "name": "string",
  "description": "string",
  "action": "ALLOW|BLOCK",
  "enforcingDeviceFilter": {
    "type": "string"
  },
  "index": 0,
  "sourceFilter": null,
  "destinationFilter": null,
  "metadata": {
    "origin": "string"
  },
  "protocolFilter": ["TCP"]
}
```

### Key Fields for This App

| Field | Description |
|-------|-------------|
| `id` | UUID identifier for the rule (used in API calls) |
| `name` | Display name (filter for names starting with "downtime") |
| `enabled` | Boolean to enable/disable the rule |
| `action` | "BLOCK" for blocking rules, "ALLOW" for allow rules |
| `type` | "IPV4" (IPv6 rules use "IPV6") |
| `index` | Priority order - must preserve when updating |

## Data Models (SwiftData)

### AppConfiguration
```swift
@Model
final class AppConfiguration {
    var unifiHost: String          // IP address of UniFi controller (e.g., "192.168.1.1")
    var siteId: String             // Site UUID from UniFi (required for all API calls)
    var isConfigured: Bool         // Setup complete flag
    var lastUpdated: Date

    // Note: API key stored in Keychain, NOT here
}
```

**Note:** The `siteId` is a UUID (e.g., `"a1b2c3d4-e5f6-7890-abcd-ef1234567890"`), not a simple string like "default". It can be extracted from the UniFi console URL or discovered via the Sites API.

### ACLRule
```swift
@Model
final class ACLRule {
    // Identity
    var ruleId: String             // UniFi UUID (id field)

    // Required fields for PUT requests (must store all to update)
    var ruleType: String           // "IPV4" or "IPV6" (API field: "type")
    var name: String               // ACL rule name
    var action: String             // "ALLOW" or "BLOCK"
    var index: Int                 // Priority order (lower = higher priority)
    var isEnabled: Bool            // Current enabled state

    // Optional fields (store for complete PUT request)
    var ruleDescription: String?   // API field: "description"

    // App-specific fields
    var isSelected: Bool           // User selected this rule to manage
    var lastSynced: Date

    // Note: sourceFilter, destinationFilter, enforcingDeviceFilter,
    // protocolFilter are complex objects - store as JSON string if needed
    var filtersJSON: String?       // JSON blob of filter objects for PUT requests
}
```

**Implementation Note:** Since the PUT API requires all required fields, we must store the complete rule state. When toggling `enabled`, fetch the current rule first (GET), modify `enabled`, then send the full object (PUT).

## App Flow

### First Launch (Not Configured)

1. **Welcome Screen**
   - Brief explanation of what the app does
   - "Get Started" button

2. **UniFi IP Configuration Screen**
   - Auto-detect: Get iPhone's current IP and suggest common router IPs (e.g., if phone is 192.168.1.x, suggest 192.168.1.1)
   - Manual entry field for UniFi controller IP
   - "Test Connection" button to verify reachability
   - Validate that the host responds on port 443

3. **API Key & Site ID Entry Screen**
   - Secure text field for API key entry
   - Site ID field (try to auto-discover, or manual entry)
   - Instructions on how to create an API key in UniFi
   - "Verify Connection" button to test authentication with a simple API call
   - Store API key securely in Keychain (not SwiftData)
   - Store siteId in SwiftData

4. **ACL Rule Selection Screen**
   - Fetch all ACL rules from UniFi API
   - Filter and display only rules where name starts with "downtime" (case-insensitive)
   - Multi-select list for user to choose which rules to manage
   - Store selected rules in SwiftData

5. **Setup Complete**
   - Transition to main app view

### Main App View (Configured)

1. **Dashboard View**
   - List of selected ACL rules with toggle switches
   - Each row shows:
     - Rule name (e.g., "Downtime-KidsRoom")
     - Current status (Enabled/Disabled)
     - Toggle switch to change state
   - Pull-to-refresh to sync with UniFi
   - Last synced timestamp

2. **Settings Screen**
   - View/Edit UniFi IP
   - Re-enter API Key
   - Manage selected ACL rules
   - Reset app configuration

## Security Considerations

1. **API Key Storage**
   - Store API key in iOS Keychain, NOT in SwiftData or UserDefaults
   - Use `kSecAttrAccessibleWhenUnlocked` for Keychain access

2. **SSL Certificate Handling**
   - UniFi uses self-signed certificates
   - Implement certificate pinning or trust evaluation delegate
   - Consider: Allow user to trust certificate on first connection

3. **Network Security**
   - App only works on local network (same subnet as UniFi)
   - No cloud connectivity required
   - API key never leaves the local network

4. **Input Validation**
   - Validate IP address format
   - Sanitize API responses
   - Handle network timeouts gracefully

## Implementation Phases

### Phase 1: Core Infrastructure
- [ ] Set up project structure (MVVM)
- [ ] Create SwiftData models
- [ ] Implement Keychain wrapper for API key storage
- [ ] Create UniFi API service layer
- [ ] Handle SSL certificate trust for local connections

### Phase 2: Configuration Flow
- [ ] Welcome/onboarding screen
- [ ] UniFi IP configuration with auto-detection
- [ ] API key entry and verification
- [ ] ACL rule fetching and selection
- [ ] Configuration persistence

### Phase 3: Main Functionality
- [ ] Dashboard view with rule list
- [ ] Toggle functionality to enable/disable rules (see Toggle Workflow below)
- [ ] Pull-to-refresh sync
- [ ] Error handling and retry logic
- [ ] Loading states and feedback

### Toggle Workflow (Critical)

Since the PUT API requires all fields, toggling a rule requires:

1. **GET** the current rule state: `GET /acl-rules/{aclRuleId}`
2. **Modify** only the `enabled` field in the response
3. **PUT** the complete object back: `PUT /acl-rules/{aclRuleId}`

```swift
func toggleRule(ruleId: String, newEnabledState: Bool) async throws {
    // 1. Fetch current state
    let currentRule = try await api.getACLRule(siteId: siteId, ruleId: ruleId)

    // 2. Build update request with ALL required fields
    let updateRequest = ACLRuleUpdateRequest(
        type: currentRule.type,
        enabled: newEnabledState,  // Only this changes
        name: currentRule.name,
        action: currentRule.action,
        index: currentRule.index,
        description: currentRule.description,
        sourceFilter: currentRule.sourceFilter,
        destinationFilter: currentRule.destinationFilter,
        protocolFilter: currentRule.protocolFilter
    )

    // 3. Send update
    try await api.updateACLRule(siteId: siteId, ruleId: ruleId, body: updateRequest)
}
```

### Phase 4: Polish
- [ ] Settings screen
- [ ] App icon and launch screen
- [ ] Haptic feedback on toggle
- [ ] Widget for quick access (future)

## File Structure

```
SilenceTheLAN/
├── App/
│   └── SilenceTheLANApp.swift
├── Models/
│   ├── AppConfiguration.swift
│   └── ACLRule.swift
├── Services/
│   ├── UniFiAPIService.swift
│   ├── KeychainService.swift
│   └── NetworkDetectionService.swift
├── ViewModels/
│   ├── ConfigurationViewModel.swift
│   └── DashboardViewModel.swift
├── Views/
│   ├── Onboarding/
│   │   ├── WelcomeView.swift
│   │   ├── IPConfigurationView.swift
│   │   ├── APIKeyEntryView.swift
│   │   └── RuleSelectionView.swift
│   ├── Dashboard/
│   │   ├── DashboardView.swift
│   │   └── RuleRowView.swift
│   └── Settings/
│       └── SettingsView.swift
├── Utilities/
│   ├── SSLDelegate.swift
│   └── Extensions.swift
└── Resources/
    └── Assets.xcassets/
```

## Testing Notes

- Test on physical device (simulator may not have same network access)
- Ensure UniFi controller is accessible on local network
- Create test ACL rules prefixed with "downtime" for testing
- Test with invalid API keys to verify error handling
- Test network disconnection scenarios

## Common Issues

1. **SSL Certificate Errors**
   - UniFi uses self-signed certs; implement URLSessionDelegate to handle trust
   - Use `URLSessionDelegate` with `urlSession(_:didReceive:completionHandler:)` to accept the certificate

2. **API 401 Unauthorized**
   - API key may be invalid or expired
   - Ensure API key has appropriate permissions
   - Check `X-API-Key` header is being sent correctly

3. **API 400 Bad Request on PUT**
   - Missing required fields (`type`, `enabled`, `name`, `action`, `index`)
   - Must send complete object, not partial updates
   - Ensure `index` is >= 0

4. **Connection Timeout**
   - Verify iPhone is on same network as UniFi
   - Check if UniFi controller IP is correct
   - Firewall may be blocking API access

5. **Rules Not Appearing**
   - Ensure ACL rules are named with "downtime" prefix
   - Check pagination - may need to fetch multiple pages if >25 rules
   - Verify API response `data` array contains rules

6. **Invalid siteId**
   - siteId must be a valid UUID
   - Can be found in UniFi console URL or via Sites API
   - Common error: using "default" instead of actual UUID
