# AST AI Prototype

A privacy-first iOS assistant prototype. Open `ASTAI.xcodeproj` in Xcode.

## What’s included

- SwiftUI app scaffold with `ContentView`, `EventKitManager`, `CallKitManager`, and `PushKitManager`
- `Info.plist` with VoIP and remote notification background modes
- `ASTAI.entitlements` for APNs/PushKit
- backend example in `backend/` for registering VoIP tokens, sending VoIP pushes, and Twilio call integration
- MailCore2 IMAP/SMTP helper in `MailCoreManager.swift` (will work when MailCore2 is installed)
- AI reply engine with local fallback and OpenAI provider support in `LLMManager.swift`
- App settings and permission manager in `SettingsView.swift` and `PermissionManager.swift`
- SIP/VoIP backend integration sample in `SIPProviderManager.swift`

## Opening the project

1. Open `ASTAI.xcodeproj` in Xcode.
2. Set your signing team in the target's `Signing & Capabilities`.
3. Add `Push Notifications` and `Background Modes` → check `Voice over IP` and `Remote notifications`.
4. The app already includes `NSCalendarsUsageDescription` for EventKit access.
5. To enable email IMAP/SMTP, install MailCore2 in the Xcode project and add `import MailCore` where needed.

## Backend setup

See `backend/README.md` for a minimal Node.js server to register VoIP tokens and send pushes.

## Notes

- To test VoIP pushes you need an Apple Developer account and an APNs auth key.
- The email helper in `EmailClient.swift` currently contains a MailCore2 integration stub; follow the comments to install MailCore2.
