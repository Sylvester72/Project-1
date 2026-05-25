# AST AI — Data Flows & Privacy (Developer Prototype)

This document specifies how data moves through the developer prototype, how it is stored, and privacy/security controls required for testing.

## Data Classification
- Sensitive (secrets): email passwords, IMAP/SMTP credentials, OpenAI API key, APNs auth key, Twilio/WhatsApp API tokens.
- Personal Identifiers (PII): user email addresses, phone numbers, WhatsApp IDs, device VoIP tokens.
- Message Content: email bodies, WhatsApp messages, call metadata (caller ID), calendar event details.
- Telemetry/Logs: non-sensitive operational logs (errors, statuses) — must not contain secrets/PII.

## Principles
- Minimize storage of message content on backend; prefer transient forwarding where possible.
- Store secrets only in secure locations (Keychain on device, environment variables or secrets store for backend).
- Mask or truncate tokens in all logs; never log full API keys or passwords.
- Explicit user consent in UI for connecting email accounts and messaging APIs.
- Allow easy deletion of cached data and registered device tokens.

## Component Data Flows

### 1) Device Registration (VoIP Token)
- Flow: Device (PushKit) -> `POST /register-voip-token` -> Backend DB (prototype: in-memory or file)
- Data: deviceToken (APNs binary hex), device identifier (optional), user id (dev prototype: optional)
- Storage: Prototype may persist token for testing; production must store securely with association to account.
- Privacy: Token treated as sensitive; do not expose in logs. Implement deletion endpoint for token removal.

### 2) VoIP Push (Incoming Call)
- Flow: External event (Twilio) or admin -> Backend constructs APNs payload -> APNs -> Device
- Data: minimal payload {caller, uuid} only. Avoid attaching message bodies or long content.
- Security: Backend signs APNs JWT using private `.p8` file stored outside repo.

### 3) Email (IMAP fetch / SMTP send)
- Flow: User supplies IMAP/SMTP settings -> App stores credentials in Keychain -> App connects directly to mail server.
- Data: Email credentials (Keychain), message metadata and bodies fetched by app.
- Storage: Prefer ephemeral in-memory caching for messages; if backend sync is implemented, encrypt at rest and store only necessary metadata.
- Privacy: App shows explicit consent UI before accessing mail. Never send email credentials to backend.

### 4) Calendar (EventKit)
- Flow: App requests EventKit permissions -> events accessed/created locally on-device.
- Storage: Local only. Do not sync events to backend unless user explicitly opts in; if syncing, encrypt in transit and at rest.

### 5) LLM / AI Reply Generation
- Local fallback: LLM prompt templates run on-device; no data leaves device.
- OpenAI: If enabled, the app sends prompt to OpenAI endpoint using the stored API key. Options:
  - Send prompts directly from device to OpenAI (recommended for prototype) — Key stored in Keychain.
  - Or route prompts through backend (not recommended without auth and rate-limiting).
- Privacy: If using OpenAI, inform user that message content is sent to third party. Offer opt-out.

### 6) WhatsApp Business (send + webhook)
- Sending: App -> Backend `/whatsapp/send` (to, message). Backend -> Meta Graph API with `WA_API_TOKEN`.
  - Data: recipient phone number (PII), message body (message content).
  - Storage: Backend should not persist message body; log only message-id/status. If storing, encrypt and document retention.
- Webhook: Meta -> Backend `/whatsapp/webhook`.
  - Data: incoming message content and sender `wa_id`.
  - Handling: For prototype, log the event (mask PII in logs) and optionally forward a notification to the device via APNs (see next section).

## Webhook → Device Forwarding (optional)
- Design: Backend receives webhook, looks up recipient device tokens, and sends a VoIP or silent push notifying the app to fetch details.
- Recommendation: Send minimal notification {type: "wa_event", id: <event-id>} and store event payload server-side for short-term retrieval via authenticated `GET /events/:id`.
- Security: Require authentication for retrieval (prototype: simple token or device id); production: OAuth or device-bound JWT.

## Logging & Telemetry
- Allowed: timestamps, non-sensitive status messages, non-PII error codes.
- Forbidden: full device tokens, API keys, passwords, full message content (unless anonymized and consented).
- Masking: Mask device tokens and PII in logs, e.g., show first/last 6 chars only.

## Retention & Deletion
- Device tokens: keep until explicit unregister or 90 days of inactivity.
- Message payloads: prefer 0 retention; if stored, default to automatic purge after 7 days for prototype.
- Secrets: never store in repo; rotate API tokens and remove test tokens before sharing.

## Key Management
- Device: Keychain for OpenAI key and email password.
- Backend: environment variables for APNS `.p8`, Twilio, WhatsApp tokens. For local dev, use `.env` excluded from source control.
- Rotation: document how to rotate WA_API_TOKEN and APNS keys and reload backend.

## Threat Model & Mitigations (quick)
- Compromise of backend server: store minimal user data, encrypt sensitive stored payloads.
- Leaked logs: mask tokens/PII and use structured logging to avoid accidental dumps.
- Man-in-the-middle: require `https` for backend; validate certificates; use `https` to Meta and Twilio.

## Developer Checklist (before testing on device)
- [ ] Remove any hardcoded keys from code.
- [ ] Put APNS/TWILIO/WA keys in env vars and confirm `backend/server.js` reads them.
- [ ] Confirm `KeychainHelper.swift` is used for secrets (OpenAI key, email password).
- [ ] Configure `WA_WEBHOOK_VERIFY_TOKEN` and register webhook URL in Meta Business Manager.
- [ ] Ensure `Xcode` entitlements: Push Notifications, Background Modes (VoIP).

## Next Steps
- Implement server-side short-lived event storage and a secure `GET /event/:id` for app fetches (if forwarding webhooks).
- Add UI text explaining what data is sent to third-party LLM providers.
- Implement deletion endpoints for device tokens and user data.


*This file documents the developer prototype privacy posture. For production, contract a security review and implement hardened auth, rate-limiting, and data access controls.*