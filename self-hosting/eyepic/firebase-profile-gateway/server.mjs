import { createServer } from 'node:http';
import { readFileSync } from 'node:fs';
import { getApps, initializeApp, cert } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

const port = Number(process.env.PORT || 8080);
const token = process.env.FIREBASE_PROFILE_GATEWAY_TOKEN;
const credentialsPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;

if (!token || !credentialsPath) throw new Error('Firebase profile gateway credentials are not configured');

const credentials = JSON.parse(readFileSync(credentialsPath, 'utf8'));
const app = getApps()[0] || initializeApp({ credential: cert(credentials), projectId: credentials.project_id });
const auth = getAuth(app);
const firestore = getFirestore(app);

const send = (response, status, body) => {
  response.writeHead(status, { 'content-type': 'application/json' });
  response.end(JSON.stringify(body));
};

const document = async (collection, uid) => {
  const snapshot = await firestore.collection(collection).doc(uid).get();
  return { found: snapshot.exists, data: snapshot.exists ? snapshot.data() : null };
};

createServer(async (request, response) => {
  if (request.method === 'GET' && request.url === '/healthz') return send(response, 200, { ok: true });
  if (request.method !== 'POST' || request.url !== '/v1/profile') return send(response, 404, { error: 'Not found' });
  if (request.headers.authorization !== `Bearer ${token}`) return send(response, 401, { error: 'Unauthorized' });

  let raw = '';
  for await (const chunk of request) raw += chunk;
  let payload;
  try {
    payload = JSON.parse(raw || '{}');
  } catch {
    return send(response, 400, { error: 'Invalid JSON payload' });
  }
  const { email } = payload;
  if (typeof email !== 'string' || !email.trim()) return send(response, 422, { error: 'Email is required' });

  try {
    const user = await auth.getUserByEmail(email.trim());
    const [credits, subscription] = await Promise.all([
      document(process.env.FIREBASE_PROFILE_CREDITS_COLLECTION || 'users_credits', user.uid),
      document(process.env.FIREBASE_PROFILE_SUBSCRIPTIONS_COLLECTION || 'subscriptions', user.uid),
    ]);
    return send(response, 200, {
      auth: { found: true, uid: user.uid, email: user.email, disabled: user.disabled, emailVerified: user.emailVerified },
      credits,
      subscription,
    });
  } catch (error) {
    if (error.code === 'auth/user-not-found') return send(response, 200, { auth: { found: false }, credits: null, subscription: null });
    console.error('Firebase profile lookup failed', error);
    return send(response, 502, { error: 'Firebase profile lookup failed' });
  }
}).listen(port, '0.0.0.0');
