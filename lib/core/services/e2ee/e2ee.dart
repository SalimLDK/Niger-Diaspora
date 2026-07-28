// E2EE (End-to-End Encryption) Services for Diaspo Niger Messaging
//
// This module implements the Signal Protocol for secure messaging:
// - X3DH (Extended Triple Diffie-Hellman) for session establishment
// - Double Ratchet for message encryption with forward secrecy
// - Sender Keys for efficient group messaging (100+ members)
// - Multi-device support (up to 5 devices per account)
// - Key backup with passphrase encryption
// - Media encryption (images, audio, video, documents)
// - Client-side content moderation (compatible with E2EE)
//
// The server CANNOT decrypt messages - only the intended recipients can.

// Models
export 'models/e2ee_models.dart';

// Core Services
export 'secure_key_storage.dart';
export 'key_manager_service.dart';
export 'messaging_e2ee_service.dart';

// Group Messaging
export 'sender_key_service.dart';

// Multi-Device Support
export 'device_sync_service.dart';

// Backup & Recovery
export 'key_backup_service.dart';
export 'e2ee_backup_coordinator.dart';

// Media Encryption
export 'media_encryption_service.dart';

// Content Moderation (client-side, E2EE compatible)
export 'content_moderation_service.dart';

// Integration Helper (for message_remote_datasource)
export 'message_e2ee_helper.dart';

// Notification Decryption (for foreground notifications)
export 'notification_decryption_service.dart';
