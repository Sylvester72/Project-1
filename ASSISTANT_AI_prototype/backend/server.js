const express = require('express');
const bodyParser = require('body-parser');
const https = require('https');
const fs = require('fs');
const twilio = require('twilio');
const sqlite3 = require('sqlite3').verbose();
const rateLimit = require('express-rate-limit');

const app = express();
app.use(bodyParser.json());

// Basic rate limiting for prototype endpoints
const limiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 300 });
app.use('/whatsapp/', limiter);
app.use('/twilio/', limiter);
app.use('/register-voip-token', limiter);

// Ensure data directory exists
const dataDir = './data';
try { fs.mkdirSync(dataDir, { recursive: true }); } catch (e) {}

// Initialize SQLite DB for events persistence (prototype)
const db = new sqlite3.Database(`${dataDir}/events.db`);
db.serialize(() => {
  db.run(`CREATE TABLE IF NOT EXISTS events (
    id TEXT PRIMARY KEY,
    from_id TEXT,
    text TEXT,
    timestamp INTEGER,
    raw TEXT
  )`);
  // purge old events older than 7 days
  const sevenDaysAgo = Date.now() - 7 * 24 * 60 * 60 * 1000;
  db.run('DELETE FROM events WHERE timestamp < ?', [sevenDaysAgo]);
});

// In a real deployment, store this securely and do not hardcode.
const APNS_KEY_ID = process.env.APNS_KEY_ID || 'YOUR_KEY_ID';
const APNS_TEAM_ID = process.env.APNS_TEAM_ID || 'YOUR_TEAM_ID';
const APNS_BUNDLE_ID = process.env.APNS_BUNDLE_ID ||cd "c:\Users\HP\OneDrive\Desktop\PROJECT 1\ASSISTANT_AI_prototype\backend"
npm install
npm start 'com.example.ASTAI';
const APNS_AUTH_KEY_PATH = process.env.APNS_AUTH_KEY_PATH || './AuthKey.p8';

const TWILIO_ACCOUNT_SID = process.env.TWILIO_ACCOUNT_SID || 'YOUR_TWILIO_SID';
const TWILIO_AUTH_TOKEN = process.env.TWILIO_AUTH_TOKEN || 'YOUR_TWILIO_AUTH_TOKEN';
const TWILIO_FROM_NUMBER = process.env.TWILIO_FROM_NUMBER || '+15005550006';
const TWILIO_CALL_URL = process.env.TWILIO_CALL_URL || 'https://your-server.example.com/twilio/voice';
const twilioClient = twilio(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN);

const WA_PHONE_NUMBER_ID = process.env.WA_PHONE_NUMBER_ID || 'YOUR_WHATSAPP_PHONE_NUMBER_ID';
const WA_API_TOKEN = process.env.WA_API_TOKEN || 'YOUR_WHATSAPP_API_TOKEN';
const WA_WEBHOOK_VERIFY_TOKEN = process.env.WA_WEBHOOK_VERIFY_TOKEN || 'YOUR_WHATSAPP_VERIFY_TOKEN';

// In-memory prototype stores
const deviceTokenMap = {}; // waId -> deviceToken
const allDeviceTokens = new Set();
const eventsStore = {}; // small in-memory cache (eventId -> eventPayload)
const authTokenMap = {}; // authToken -> deviceToken

function sendApnsVoipPush(deviceToken, payload, callback) {
  try {
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
        callback && callback(null, { status: response.statusCode, body: data });
      });
    });

    reqPush.on('error', (error) => {
      callback && callback(error);
    });

    reqPush.write(JSON.stringify(payload));
    reqPush.end();
  } catch (err) {
    callback && callback(err);
  }
}

app.post('/register-voip-token', (req, res) => {
  const { deviceToken, waId } = req.body;
  if (!deviceToken) {
    return res.status(400).json({ error: 'deviceToken is required' });
  }

  // Prototype storage: allow optional `waId` to map WhatsApp IDs to device tokens.
  if (waId) {
    deviceTokenMap[waId] = deviceToken;
  }

  allDeviceTokens.add(deviceToken);

  // Accept an auth token from the device or generate one to return.
  const { authToken } = req.body;
  let tokenToReturn = authToken;
  if (authToken && typeof authToken === 'string' && authToken.length > 8) {
    authTokenMap[authToken] = deviceToken;
  } else {
    tokenToReturn = require('crypto').randomUUID();
    authTokenMap[tokenToReturn] = deviceToken;
  }

  res.json({ success: true, authToken: tokenToReturn });
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

    // Store event in-memory for short-term retrieval by the app.
    const eventId = require('crypto').randomUUID();
    const ts = Date.now();
    const stored = { id: eventId, from, text, timestamp: ts, raw: value };
    eventsStore[eventId] = stored;

    // persist to sqlite
    try {
      db.run('INSERT INTO events(id, from_id, text, timestamp, raw) VALUES(?,?,?,?,?)', [eventId, from, text, ts, JSON.stringify(value)]);
    } catch (err) {
      console.error('DB insert error:', err.message || err);
    }

    console.log(`Stored WhatsApp event ${eventId} from ${from}`);

    // Notify registered device tokens with minimal payload (no message body)
    const pushPayload = {
      aps: { 'content-available': 1 },
      type: 'whatsapp_event',
      eventId,
    };

    // Send to all registered tokens (prototype). In production, map user->device.
    allDeviceTokens.forEach((token) => {
      sendApnsVoipPush(token, pushPayload, (err) => {
        if (err) {
          console.error('APNs forward error (masked):', err.message || err);
        }
      });
    });
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

// Retrieve a stored event by id (prototype). Returns minimal safe fields.
app.get('/events/:id', (req, res) => {
  // Require Authorization: Bearer <authToken>
  const auth = (req.headers.authorization || '').replace(/^Bearer\s*/i, '');
  if (!auth || !authTokenMap[auth]) return res.status(403).json({ error: 'Unauthorized' });

  const id = req.params.id;
  db.get('SELECT id, from_id as from, text, timestamp FROM events WHERE id = ?', [id], (err, row) => {
    if (err) return res.status(500).json({ error: 'DB error' });
    if (!row) return res.status(404).json({ error: 'Event not found' });
    res.json({ id: row.id, from: row.from, text: row.text, timestamp: row.timestamp });
  });
});

// List recent events (prototype) - requires auth
app.get('/events', (req, res) => {
  const auth = (req.headers.authorization || '').replace(/^Bearer\s*/i, '');
  if (!auth || !authTokenMap[auth]) return res.status(403).json({ error: 'Unauthorized' });

  db.all('SELECT id, from_id as from, text, timestamp FROM events ORDER BY timestamp DESC LIMIT 50', [], (err, rows) => {
    if (err) return res.status(500).json({ error: 'DB error' });
    res.json(rows.map((r) => ({ id: r.id, from: r.from, text: r.text, timestamp: r.timestamp })));
  });
});

// Unregister endpoint: remove device token and revoke auth token
app.post('/unregister-voip-token', (req, res) => {
  const { authToken, deviceToken } = req.body || {};
  if (!authToken && !deviceToken) return res.status(400).json({ error: 'authToken or deviceToken required' });

  if (authToken && authTokenMap[authToken]) {
    const token = authTokenMap[authToken];
    delete authTokenMap[authToken];
    allDeviceTokens.delete(token);
    // also remove any waId mappings
    Object.keys(deviceTokenMap).forEach((k) => { if (deviceTokenMap[k] === token) delete deviceTokenMap[k]; });
    return res.json({ success: true });
  }

  if (deviceToken) {
    allDeviceTokens.delete(deviceToken);
    Object.keys(authTokenMap).forEach((k) => { if (authTokenMap[k] === deviceToken) delete authTokenMap[k]; });
    Object.keys(deviceTokenMap).forEach((k) => { if (deviceTokenMap[k] === deviceToken) delete deviceTokenMap[k]; });
    return res.json({ success: true });
  }
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
