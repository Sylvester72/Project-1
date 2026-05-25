# AST AI Backend Example

This backend is a minimal Node.js example for registering VoIP push tokens and sending VoIP pushes to iOS devices.

## Setup

1. Install dependencies:

```bash
cd "c:\Users\HP\OneDrive\Desktop\PROJECT 1\AST_AI_prototype\backend"
npm install
```

2. Create an APNs auth key in Apple Developer and save it as `AuthKey.p8` in this folder.
3. Set environment variables:

```bash
set APNS_KEY_ID=YOUR_KEY_ID
set APNS_TEAM_ID=YOUR_TEAM_ID
set APNS_BUNDLE_ID=com.example.ASTAI
set APNS_AUTH_KEY_PATH=./AuthKey.p8
```

4. Start the server:

```bash
npm start
```

5. For Twilio integration, also set:

```bash
set TWILIO_ACCOUNT_SID=YOUR_TWILIO_ACCOUNT_SID
set TWILIO_AUTH_TOKEN=YOUR_TWILIO_AUTH_TOKEN
set TWILIO_FROM_NUMBER=+1234567890
set TWILIO_CALL_URL=https://your-server.example.com/twilio/voice
```

## API

- `POST /register-voip-token`
  - body: `{ "deviceToken": "..." }`
- `POST /send-voip-push`
  - body: `{ "deviceToken": "...", "caller": "+1234567890" }`
- `POST /twilio/incoming-call`
  - body: `{ "deviceToken": "...", "caller": "+1234567890" }`
  - used when Twilio notifies your backend of an incoming call and you want to forward it to the app as a VoIP push.
- `POST /twilio/make-call`
  - body: `{ "to": "+1234567890" }`
  - creates an outbound Twilio call using your configured Twilio number.
- `POST /twilio/voice`
  - Twilio fetches this webhook for TwiML when a call is created.

The backend can receive Twilio webhooks for inbound PSTN/SIP calls and send a VoIP push to the app. The app then reports the call to CallKit.
