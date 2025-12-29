// Script to set a user as admin in Firestore
// Run with: node scripts/set_admin.js

const admin = require('firebase-admin');

// Initialize Firebase Admin with default credentials
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'diaspo-niger'
});

const db = admin.firestore();

async function setUserAsAdmin(email) {
  try {
    // Find user by email
    const usersSnapshot = await db.collection('users')
      .where('email', '==', email)
      .get();

    if (usersSnapshot.empty) {
      console.log(`No user found with email: ${email}`);
      console.log('Creating admin flag will happen when user logs in.');

      // List all users to help debug
      const allUsers = await db.collection('users').limit(10).get();
      console.log('\nExisting users:');
      allUsers.forEach(doc => {
        const data = doc.data();
        console.log(`- ${doc.id}: ${data.email || 'no email'}`);
      });
      return;
    }

    // Update each matching user document
    for (const doc of usersSnapshot.docs) {
      await doc.ref.update({
        isAdmin: true
      });
      console.log(`✓ User ${doc.id} (${email}) is now an admin!`);
    }

    console.log('\nDone! You can now use the admin panel.');
  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    process.exit(0);
  }
}

// Run with the email
setUserAsAdmin('dankobosalim@gmail.com');
