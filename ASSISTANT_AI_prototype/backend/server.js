const express = require('express');
const bodyParser = require('body-parser');
const https = require('https');
const fs = require('fs');
const twilio = require('twilio');

const app = express();
app.use(bodyParser.json());

// In a real deployment, store this securely and do not hardcode.
const APNS_KEY_ID = process.env.APNS_KEY_ID || 'YOUR_KEY_ID';
const APNS_TEAM_ID = process.env.APNS_TEAM_ID || 'YOUR_TEAM_ID';
const APNS_BUNDLE_ID = process.env.APNS_BUNDLE_ID || 'com.example.ASTAI';
const APNS_AUTH_KEY_PATH = process.env.APNS_AUTH_KEY_PATH || './AuthKey.p8';

const TWILIO_ACCOUNT_SID = process.env.TWILIO_ACCOUNT_SID || 'YOUR_TWILIO_SID';
const TWILIO_AUTH_TOKEN = process.env.TWILIO_AUTH_TOKEN || 'YOUR_TWILIO_AUTH_TOKEN';
const TWILIO_FROM_NUMBER = process.env.TWILIO_FROM_NUMBER || '+15005550006';
const TWILIO_CALL_URL = process.env.TWILIO_CALL_URL || 'https://your-server.example.com/twilio/voice';
const twilioClient = twilio(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN);

const WA_PHONE_NUMBER_ID = process.env.WA_PHONE_NUMBER_ID || 'YOUR_WHATSAPP_PHONE_NUMBER_ID';
const WA_API_TOKEN = process.env.WA_API_TOKEN || 'YOUR_WHATSAPP_API_TOKEN';
const WA_WEBHOOK_VERIFY_TOKEN = process.env.WA_WEBHOOK_VERIFY_TOKEN || 'YOUR_WHATSAPP_VERIFY_TOKEN';

app.post('/register-voip-token', (req, res) => {
  const { deviceToken } = req.body;
  if (!deviceToken) {
    return res.status(400).json({ error: 'deviceToken is required' });
  }

  // Save the token securely in your database for this user/device.
  console.log('Registered VoIP token:', deviceToken);
  res.json({ success: true });
});

app.post('/send-voip-push', (req, res) => {
  const { deviceToken, caller } = req.body;
  if (!deviceToken || !caller) {
    return res.status(400).json({ error: 'deviceToken and caller are required' });
  }

  const payload = {
    aps: {
      'content-available': 1,
      sound: 'default',
      category: 'VOIP',
    },
    caller,
    uuid: require('crypto').randomUUID(),
  };

  const tokenHex = deviceToken.replace(/[^0-9a-fA-F]/g, '');
  const options = {
    hostname: 'api.sandbox.push.apple.com',
    port: 443,
    path: `/3/device/${tokenHex}`,
    method: 'POST',
    headers: {
      'apns-topic': `${APNS_BUNDLE_ID}.voip`,
      'apns-push-type': 'voip',
      'content-type': 'application/json',
    },
  };

  const jwt = generateJwt();
  options.headers.authorization = `bearer ${jwt}`;

  const reqPush = https.request(options, (response) => {
    let data = '';
    response.on('data', (chunk) => (data += chunk));
    response.on('end', () => {
      res.json({ status: response.statusCode, body: data });
    });
  });

  reqPush.on('error', (error) => {
    res.status(500).json({ error: error.message });
  });

  reqPush.write(JSON.stringify(payload));
  reqPush.end();
});

app.get('/whatsapp/webhook', (req, res) => {
  const mode = req.query['hub.mode'];
  const token = req.query['hub.verify_token'];
  const challenge = req.query['hub.challenge'];

  if (mode === 'subscribe' && token === WA_WEBHOOK_VERIFY_TOKEN) {
    return res.status(200).send(challenge);
  }

  return res.status(403).json({ error: 'Verification failed' });
});

app.post('/whatsapp/webhook', (req, res) => {
  const body = req.body;
  console.log('WhatsApp webhook payload received');

  if (body.object !== 'whatsapp_business_account') {
    return res.status(400).json({ error: 'Unsupported webhook object' });
  }

  const entry = body.entry?.[0];
  const changes = entry?.changes?.[0];
  const value = changes?.value;
  const message = value?.messages?.[0];
  const contact = value?.contacts?.[0];

  if (message && contact) {
    const from = contact.wa_id;
    const text = message.text?.body || message.button?.text || '<non-text message>';
    console.log(`WhatsApp message from ${from}: ${text}`);
  }

  res.status(200).json({ received: true });
});

app.post('/whatsapp/send', async (req, res) => {
  const { to, message } = req.body;
  if (!to || !message) {
    return res.status(400).json({ error: 'Both `to` and `message` are required.' });
  }

  const payload = JSON.stringify({
    messaging_product: 'whatsapp',
    to,
    type: 'text',
    text: { body: message },
  });

  const requestOptions = {
    hostname: 'graph.facebook.com',
    port: 443,
    path: `/v17.0/${WA_PHONE_NUMBER_ID}/messages`,
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${WA_API_TOKEN}`,
      'Content-Length': Buffer.byteLength(payload),
    },
  };

  const request = https.request(requestOptions, (response) => {
    let data = '';
    response.on('data', (chunk) => (data += chunk));
    response.on('end', () => {
      const statusCode = response.statusCode || 500;
      if (statusCode >= 200 && statusCode < 300) {
        res.status(200).json({ success: true, body: JSON.parse(data) });
      } else {
        console.error('WhatsApp send failed', statusCode, data);
        res.status(statusCode).json({ error: 'WhatsApp send failed', body: data });
      }
    });
  });

  request.on('error', (error) => {
    console.error('WhatsApp request error:', error);
    res.status(500).json({ error: error.message });
  });

  request.write(payload);
  request.end();
});

app.post('/twilio/incoming-call', async (req, res) => {
  const { deviceToken, caller } = req.body;
  if (!deviceToken || !caller) {
    return res.status(400).json({ error: 'deviceToken and caller are required' });
  }

  console.log('Received Twilio call event for caller:', caller);
  const payload = {
    aps: {
      'content-available': 1,
      sound: 'default',
      category: 'VOIP',
    },
    caller,
    uuid: require('crypto').randomUUID(),
  };

  const tokenHex = deviceToken.replace(/[^0-9a-fA-F]/g, '');
  const options = {
    hostname: 'api.sandbox.push.apple.com',
    port: 443,
    path: `/3/device/${tokenHex}`,
    method: 'POST',
    headers: {
      'apns-topic': `${APNS_BUNDLE_ID}.voip`,
      'apns-push-type': 'voip',
      'content-type': 'application/json',
    },
  };

  const jwt = generateJwt();
  options.headers.authorization = `bearer ${jwt}`;

  const reqPush = https.request(options, (response) => {
    let data = '';
    response.on('data', (chunk) => (data += chunk));
    response.on('end', () => {
      res.json({ status: response.statusCode, body: data });
    });
  });

  reqPush.on('error', (error) => {
    res.status(500).json({ error: error.message });
  });

  reqPush.write(JSON.stringify(payload));
  reqPush.end();
});

app.post('/twilio/make-call', async (req, res) => {
  const { to } = req.body;
  if (!to) {
    return res.status(400).json({ error: 'The destination phone number (`to`) is required.' });
  }

  try {
    const call = await twilioClient.calls.create({
      url: TWILIO_CALL_URL,
      to,
      from: TWILIO_FROM_NUMBER,
    });
    res.json({ success: true, sid: call.sid });
  } catch (error) {
    console.error('Twilio make-call error:', error);
    res.status(500).json({ error: error.message });
  }
});

app.post('/twilio/voice', (req, res) => {
  res.type('text/xml');
  res.send(`<?xml version="1.0" encoding="UTF-8"?>\n<Response>\n  <Say>Connecting your call through AST AI.</Say>\n</Response>`);
});

function generateJwt() {
  const privateKey = fs.readFileSync(APNS_AUTH_KEY_PATH, 'utf8');
  const header = {
    alg: 'ES256',
    kid: APNS_KEY_ID,
  };
  const claims = {
    iss: APNS_TEAM_ID,
    iat: Math.floor(Date.now() / 1000),
  };
  const base64url = (input) => Buffer.from(input)
    .toString('base64')
    .replace(/=/g, '')
    .replace(/\+/g, '-')
    .replace(/\//g, '_');

  const encodedHeader = base64url(JSON.stringify(header));
  const encodedClaims = base64url(JSON.stringify(claims));
  const unsignedToken = `${encodedHeader}.${encodedClaims}`;

  const sign = require('crypto').createSign('SHA256');
  sign.update(unsignedToken);
  sign.end();
  const signature = sign.sign(privateKey);
  const encodedSignature = base64url(signature);

  return `${unsignedToken}.${encodedSignature}`;
}

const port = process.env.PORT || 3000;
app.listen(port, () => {
  console.log(`AST AI backend listening on port ${port}`);
});
