# 🚀 Promptify Automation System

## GitHub Actions Release Workflow ("GitAplay Listesi")

The automated release system uses GitHub Actions to build, package, and distribute new versions of Promptify automatically.

### How It Works

1. **Trigger**: When you push a version tag (e.g., `v2.1.0`), the workflow automatically starts
2. **Build**: Compiles the app for both Intel and Apple Silicon Macs
3. **Package**: Creates DMG installer and ZIP archive
4. **Release**: Publishes to GitHub Releases with download links
5. **Notify**: Sends push notifications to existing users about the update

### Usage

#### Automatic Release (Recommended)
```bash
# Create and push a version tag
git tag v2.1.0
git push origin v2.1.0

# GitHub Actions will automatically:
# ✅ Build the app
# ✅ Create DMG and ZIP packages
# ✅ Publish GitHub release
# ✅ Send notifications to users
```

#### Manual Release
You can also trigger releases manually from GitHub Actions:
1. Go to Actions → "🚀 Automated Release & Notification"
2. Click "Run workflow"
3. Enter version number (e.g., "2.1.0")
4. Choose whether to send notifications
5. Click "Run workflow"

### Workflow Components

#### 1. Build Process
- **Platform**: macOS latest
- **Xcode**: Latest stable version
- **Architecture**: Universal binary (Intel + Apple Silicon)
- **Signing**: Unsigned (for now - can be enhanced with developer certificates)

#### 2. Package Creation
- **DMG**: Disk image with app and Applications symlink
- **ZIP**: Compressed archive for programmatic downloads
- **Naming**: `Promptify-v2.1.0.dmg` / `Promptify-v2.1.0.zip`

#### 3. Push Notifications
- **Webhook**: Calls configured endpoint with release information
- **Polling**: Apps check GitHub API every 30 minutes for new releases
- **Native**: macOS notifications when updates are available

## Push Notification System

### Two-Tier Notification Architecture

#### Tier 1: Polling System (Current Implementation)
- **Service**: `RemoteNotificationService.swift`
- **Method**: Polls GitHub API every 30 minutes
- **Trigger**: Compares latest release version with last known version
- **Notification**: Native macOS notification via `NotificationService.swift`

```swift
// Automatically starts when app launches
RemoteNotificationService.shared.startMonitoring()

// Checks GitHub API: /repos/mehmetsagir/promptify/releases/latest
// Shows notification if new version detected
```

#### Tier 2: Webhook System (Optional Enhancement)
- **Server**: Vercel/Netlify function or dedicated server
- **Trigger**: GitHub webhook on release publish
- **Method**: Real-time push to all app instances
- **Protocol**: Server-Sent Events or WebSocket

### Setting Up Webhooks (Optional)

1. **Create Server Endpoint**:
```javascript
// Vercel function: api/github-webhook.js
export default async function handler(req, res) {
    if (req.method === 'POST' && req.body.action === 'published') {
        const version = req.body.release.tag_name.replace('v', '');
        
        // Send real-time notifications
        await sendPushNotifications({
            title: 'Promptify Update Available',
            body: `Version ${version} is ready to install`,
            version: version
        });
    }
    res.status(200).json({ success: true });
}
```

2. **Configure GitHub Secrets**:
```
WEBHOOK_URL=https://your-domain.vercel.app/api/github-webhook  
WEBHOOK_SECRET=your-secret-key
```

3. **GitHub Webhook Settings**:
- URL: Your server endpoint
- Content type: `application/json`
- Events: `Releases`
- Active: ✅

## Auto-Update System Integration

### In-App Update Flow

1. **Detection**: User gets notification about new version
2. **Consent**: User clicks "Update Available" button in menu bar
3. **Download**: `AutoUpdateService` downloads DMG from GitHub
4. **Install**: Mounts DMG, replaces app in `/Applications`
5. **Restart**: Relaunches updated version
6. **Cleanup**: Removes temporary files and unmounts DMG

### Permission Requirements

The app needs these entitlements for auto-updates:
```xml
<key>com.apple.security.files.downloads.read-write</key>
<true/>
<key>com.apple.security.temporary-exception.files.absolute-path.read-write</key>
<array>
    <string>/Applications/</string>
    <string>/Volumes/</string>
</array>
```

## Configuration

### GitHub Repository Secrets

Add these secrets in GitHub Settings → Secrets and variables → Actions:

| Secret | Description | Required |
|--------|-------------|----------|
| `WEBHOOK_URL` | Push notification endpoint | Optional |
| `WEBHOOK_SECRET` | Webhook authentication token | Optional |

### User Settings

Users can control notifications in Promptify settings:
- ✅ Enable update notifications
- ✅ Auto-download updates
- ✅ Auto-install updates
- ⏰ Check frequency (30min, 1hr, 6hr, daily)

## Testing the System

### Local Testing
```swift
#if DEBUG
// Simulate update available
UpdateTestHelper.simulateUpdateAvailable()

// Test notification system  
NotificationService.shared.showUpdateAvailable(version: "99.99.99")

// Test safe update flow
UpdateTestHelper.testUpdateFlowSafe()
#endif
```

### Release Testing
1. Create a test tag: `git tag v0.0.1-test`
2. Push to trigger workflow: `git push origin v0.0.1-test`
3. Monitor GitHub Actions for build status
4. Verify DMG downloads and installs correctly
5. Check notification system responds to new release

## Security Considerations

- **Unsigned Builds**: Currently building unsigned for testing
- **HTTPS Only**: All downloads use secure connections
- **Checksum Validation**: Could be enhanced with SHA256 verification
- **User Consent**: All updates require explicit user approval
- **Sandboxing**: App remains sandboxed during update process

## Future Enhancements

1. **Code Signing**: Add Apple Developer certificate for signed releases
2. **Delta Updates**: Download only changed files for faster updates
3. **Rollback System**: Ability to revert to previous version if issues occur
4. **Update Channels**: Beta/stable release tracks
5. **Analytics**: Track update success rates and user adoption

---

**"GitAplay Listesi"** = GitHub Actions workflow list/automation system that handles the complete release pipeline from code push to user notification. 🎯