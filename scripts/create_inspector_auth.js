#!/usr/bin/env node
/**
 * create_inspector_auth.js
 *
 * Usage:
 *   node scripts/create_inspector_auth.js <inspectorDocId>
 *   node scripts/create_inspector_auth.js --all
 *
 * This script uses the Firebase Admin SDK (serviceAccountKey.json) to create a
 * Firebase Authentication user for an inspector document in Firestore and writes
 * the created user's uid into the inspector document as the `uid` field. If an
 * account with the same email already exists, the script links the existing
 * auth UID to the inspector document.
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const KEY_PATH = process.env.GOOGLE_APPLICATION_CREDENTIALS || path.join(__dirname, '..', 'serviceAccountKey.json');

if (!fs.existsSync(KEY_PATH)) {
  console.error(`Service account key not found at ${KEY_PATH}. Set GOOGLE_APPLICATION_CREDENTIALS or place serviceAccountKey.json at repo root.`);
  process.exit(2);
}

admin.initializeApp({
  credential: admin.credential.cert(require(KEY_PATH)),
});

const firestore = admin.firestore();
const auth = admin.auth();

async function createForDoc(docId) {
  const docRef = firestore.collection('inspectors').doc(docId);
  const doc = await docRef.get();
  if (!doc.exists) {
    console.error(`Inspector document not found: ${docId}`);
    return;
  }

  const data = doc.data() || {};
  let email = (data.email || '').toString().trim();
  const inspectorNo = (data.inspectorNo || '').toString().trim();
  const displayName = (data.displayName || `${data.firstName || ''} ${data.lastName || ''}`).toString().trim();

  if (!email) {
    // Fallback to inspector{inspectorNo}@gmail.com
    email = inspectorNo ? `inspector${inspectorNo}@gmail.com` : `inspector_${docId}@gmail.com`;
  }

  try {
    const user = await auth.createUser({
      email,
      password: '123123',
      displayName,
    });
    await docRef.update({ uid: user.uid });

    // Upsert a user record in the top-level `users` collection keyed by UID
    await firestore.collection('users').doc(user.uid).set({
      email: email,
      authid: user.uid,
      role: 'inspector',
      displayName: displayName,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    console.log(`Created auth user ${user.uid} for inspector ${docId} (${email}) and wrote users/${user.uid}`);
  } catch (err) {
    // If the user already exists, fetch and link
    if (err && err.code === 'auth/email-already-exists') {
      try {
        const existing = await auth.getUserByEmail(email);
        await docRef.update({ uid: existing.uid });

        // Upsert a user record in `users` collection for existing user
        await firestore.collection('users').doc(existing.uid).set({
          email: email,
          authid: existing.uid,
          role: 'inspector',
          displayName: displayName,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        console.log(`Linked existing auth user ${existing.uid} to inspector ${docId} (${email}) and wrote users/${existing.uid}`);
      } catch (e2) {
        console.error(`Failed to link existing user by email ${email}:`, e2);
      }
    } else {
      console.error('Failed to create auth user:', err);
    }
  }
}

async function run() {
  const args = process.argv.slice(2);

  if (args.includes('--watch')) {
    console.log('Watching `inspectors` collection for documents missing `uid`...');
    // Keep a set of in-flight document IDs to avoid double-processing
    const processing = new Set();

    const unsubscribe = firestore.collection('inspectors').onSnapshot(snapshot => {
      snapshot.docChanges().forEach(change => {
        const d = change.doc;
        const data = d.data() || {};
        if (!data.uid && !processing.has(d.id)) {
          processing.add(d.id);
          // fire-and-forget; remove from processing when done
          createForDoc(d.id).catch(err => {
            console.error(`Watcher: failed to create auth for ${d.id}:`, err);
          }).finally(() => processing.delete(d.id));
        }
      });
    }, err => {
      console.error('Watcher snapshot error:', err);
    });

    // Graceful shutdown
    process.on('SIGINT', () => {
      console.log('Shutting down watcher...');
      unsubscribe();
      process.exit(0);
    });

    return; // keep process alive
  }

  if (args[0] === '--all') {
    console.log('Processing all inspectors missing uid...');
    const snap = await firestore.collection('inspectors').get();
    const docs = snap.docs.filter(d => !(d.data() || {}).uid);
    console.log(`Found ${docs.length} inspector(s) without uid.`);
    for (const d of docs) {
      // eslint-disable-next-line no-await-in-loop
      await createForDoc(d.id);
    }
    console.log('Done.');
    process.exit(0);
  }

  if (args.length === 0) {
    console.log('Usage: node scripts/create_inspector_auth.js <inspectorDocId>  OR --all  OR --watch');
    process.exit(0);
  }

  const docId = args[0];
  await createForDoc(docId);
  process.exit(0);
}

run().catch((e) => {
  console.error('Unhandled error:', e);
  process.exit(1);
});
