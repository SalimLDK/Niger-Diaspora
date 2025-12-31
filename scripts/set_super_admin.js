const admin = require('firebase-admin');
const serviceAccount = require('../service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Replace with your user ID or email
const userEmail = process.argv[2];

async function setSuperAdmin() {
  if (!userEmail) {
    console.log('Usage: node set_super_admin.js <email>');
    process.exit(1);
  }

  try {
    const snapshot = await db.collection('users')
      .where('email', '==', userEmail.toLowerCase())
      .limit(1)
      .get();

    if (snapshot.empty) {
      console.log('User not found with email:', userEmail);
      process.exit(1);
    }

    const userDoc = snapshot.docs[0];
    await userDoc.ref.update({
      adminRole: 'superAdmin',
      isAdmin: admin.firestore.FieldValue.delete() // Remove old field
    });

    console.log('✅ User', userDoc.id, 'is now SuperAdmin');
  } catch (error) {
    console.error('Error:', error);
  }

  process.exit(0);
}

setSuperAdmin();
