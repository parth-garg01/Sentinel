import crypto from 'crypto';
import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import {MongoClient} from 'mongodb';

dotenv.config();

const app = express();
const port = process.env.PORT || 8080;
const mongoUri = process.env.MONGODB_URI || '';
const mongoDbName = process.env.MONGODB_DB || 'sentinel';
const mongoCollectionName = process.env.MONGODB_COLLECTION || 'incidents';
const gatewayBase =
  process.env.EVIDENCE_GATEWAY_BASE || 'https://w3s.link/ipfs/';
const adminApiToken = process.env.ADMIN_API_TOKEN || '';
const adminAesKey = process.env.ADMIN_AES_KEY || '';
const mongoClient = mongoUri ? new MongoClient(mongoUri) : null;
let incidentsCollectionPromise;

app.use(cors());
app.use(express.json({limit: '2mb'}));

app.use((req, _res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.originalUrl}`);
  next();
});

async function getIncidentsCollection() {
  if (!mongoClient) {
    throw new Error('Missing MONGODB_URI');
  }

  if (!incidentsCollectionPromise) {
    incidentsCollectionPromise = mongoClient.connect().then((client) =>
      client.db(mongoDbName).collection(mongoCollectionName),
    );
  }

  return incidentsCollectionPromise;
}

function serializeCase(doc) {
  const item = {...doc};

  if (item._id) {
    item.mongoId = item._id.toString();
    delete item._id;
  }

  if (!item.incidentId && item.mongoId) {
    item.incidentId = item.mongoId;
  }

  return item;
}

function requireAuth(req, res, next) {
  if (!adminApiToken) {
    return next();
  }

  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';

  if (!token || token !== adminApiToken) {
    return res.status(401).json({error: 'unauthorized'});
  }

  return next();
}

function decryptEvidence(buffer) {
  if (!adminAesKey) {
    throw new Error('Missing ADMIN_AES_KEY');
  }

  const key = Buffer.from(adminAesKey, 'utf8');
  if (key.length !== 32) {
    throw new Error('ADMIN_AES_KEY must be exactly 32 bytes');
  }

  const iv = buffer.subarray(0, 16);
  const ciphertext = buffer.subarray(16);
  const decipher = crypto.createDecipheriv('aes-256-cbc', key, iv);
  return Buffer.concat([decipher.update(ciphertext), decipher.final()]);
}

function verifyHash(bytes, expectedHash) {
  const digest = crypto.createHash('sha256').update(bytes).digest('hex');
  return digest === expectedHash;
}

async function fetchFromGateway(cid) {
  const normalizedBase = gatewayBase.endsWith('/')
    ? gatewayBase
    : `${gatewayBase}/`;

  const candidates = [
    `${normalizedBase}${cid}`,
    `https://${cid}.ipfs.w3s.link`,
    `https://dweb.link/ipfs/${cid}`,
    `https://${cid}.ipfs.dweb.link`,
  ];

  let lastStatus = 'no_response';

  for (const url of candidates) {
    try {
      const response = await fetch(url);
      if (response.ok) {
        return response;
      }

      lastStatus = `${response.status} from ${url}`;
      console.warn(`Gateway fetch miss for ${cid}: ${lastStatus}`);
    } catch (error) {
      lastStatus = `${error instanceof Error ? error.message : String(error)} from ${url}`;
      console.warn(`Gateway fetch error for ${cid}: ${lastStatus}`);
    }
  }

  throw new Error(`gateway_fetch_failed: ${lastStatus}`);
}

app.get('/api/admin/cases', requireAuth, async (req, res) => {
  try {
    const assignedTo = req.query.assignedTo;
    const incidents = await getIncidentsCollection();
    const query = assignedTo ? {assignedAdminId: assignedTo} : {};
    const cases = await incidents
      .find(query)
      .sort({timestamp: -1})
      .toArray();

    res.json(cases.map(serializeCase));
  } catch (error) {
    console.error('Failed to load cases', error);
    res.status(500).json({
      error: 'cases_fetch_failed',
      message: error instanceof Error ? error.message : String(error),
    });
  }
});

app.get('/api/admin/cases/:incidentId/evidence', requireAuth, async (req, res) => {
  try {
    const incidentId = req.params.incidentId;
    const incidents = await getIncidentsCollection();
    const data = await incidents.findOne({incidentId});

    if (!data) {
      return res.status(404).json({error: 'case_not_found'});
    }

    if (!data?.cid) {
      return res.status(400).json({error: 'missing_cid'});
    }

    const response = await fetchFromGateway(data.cid);
    const encrypted = Buffer.from(await response.arrayBuffer());
    const decrypted = decryptEvidence(encrypted);
    const expectedRawHash = data.rawSha256Hash || data.fileSha256Hash;

    if (expectedRawHash && !verifyHash(decrypted, expectedRawHash)) {
      return res.status(409).json({error: 'hash_verification_failed'});
    }

    res.setHeader('Content-Type', data.mimeType || 'application/octet-stream');
    res.send(decrypted);
  } catch (error) {
    console.error('Failed to fetch evidence', error);
    res.status(500).json({
      error: 'evidence_fetch_failed',
      message: error instanceof Error ? error.message : String(error),
    });
  }
});

app.patch('/api/admin/cases/:incidentId/status', requireAuth, async (req, res) => {
  try {
    const incidentId = req.params.incidentId;
    const status = String(req.body.status || '').toLowerCase();
    const allowed = ['submitted', 'underreview', 'investigating', 'resolved', 'closed'];

    if (!allowed.includes(status)) {
      return res.status(400).json({error: 'invalid_status'});
    }

    const incidents = await getIncidentsCollection();
    const result = await incidents.updateOne(
      {incidentId},
      {
        $set: {
          status,
          reviewedAt: new Date().toISOString(),
        },
      },
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({error: 'case_not_found'});
    }

    res.json({ok: true});
  } catch (error) {
    console.error('Failed to update status', error);
    res.status(500).json({
      error: 'status_update_failed',
      message: error instanceof Error ? error.message : String(error),
    });
  }
});

app.listen(port, () => {
  console.log(
    `Sentinel admin backend listening on ${port} using MongoDB database "${mongoDbName}" collection "${mongoCollectionName}"`,
  );
});
