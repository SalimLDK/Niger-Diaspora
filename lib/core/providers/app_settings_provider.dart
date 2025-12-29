/// Global App Settings Provider
///
/// This file re-exports the app settings from the admin module and provides
/// global access throughout the application. All configuration values
/// (fees, exchange rates, media limits, feature flags, etc.) should be
/// accessed through these providers.
///
/// The settings are stored in Firestore (app_config/settings) and can be
/// modified through the admin dashboard. Changes are reflected in real-time.
library;

// Re-export entities for easy access
export '../../features/admin/domain/entities/app_settings_entity.dart';

// Re-export models for serialization
export '../../features/admin/data/models/app_settings_model.dart';

// Re-export datasource for direct Firestore access if needed
export '../../features/admin/data/datasources/app_settings_datasource.dart';

// Re-export providers
export '../../features/admin/presentation/providers/app_settings_provider.dart';
