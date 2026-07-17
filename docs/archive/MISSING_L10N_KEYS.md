# Missing Localization Keys

This document lists all the hardcoded French strings that need to be added to the localization files (`app_en.arb` and `app_fr.arb`).

## Keys to Add

### General UI Elements
```json
"refresh": "Refresh",
"loadingEllipsis": "Loading...",
"approved": "Approved",
"rejected": "Rejected",
"suspended": "Suspended",
"reactivate": "Reactivate",
"reject": "Reject",
"approve": "Approve",
"suspend": "Suspend",
"rejectionReason": "Reason for rejection",
"complete": "Complete",
"buyer": "Buyer",
"seller": "Seller",
"deleteContent": "Delete content",
"process": "Process",
"clearFilters": "Clear filters",
"newAdmin": "New Admin",
"changeRole": "Change role",
"revokeAccess": "Revoke access"
```

### Admin-Specific Keys
```json
"exportInProgress": "Export of {type} in progress...",
"embassyCreated": "Embassy created successfully!",
"errorOccurred": "Error: {error}",
"createEmbassy": "Create an embassy",
"moderationMode": "Moderation Mode",
"joinAction": "Join",
"errorConnecting": "Error connecting",
"viewReports": "View Reports",
"manageUsers": "Manage Users",
"sendNotification": "Send Notification",
"viewAnalytics": "View Analytics",
"configuration": "Configuration",
"featureFlags": "Feature Flags",
"auditHistory": "Audit History"
```

### Embassy & Contact Keys
```json
"requestSent": "Request sent successfully",
"emailAction": "Email",
"website": "Website",
"getDirections": "Get directions",
"details": "Details",
"contactEmbassy": "Contact the embassy",
"department": "Department",
"messageTitle": "Title",
"messageBody": "Message",
"clear": "Clear",
"confirmSending": "Confirm sending",
"aboutToSend": "You are about to send a notification to:",
"messageLabel": "Message: {message}"
```

### Search & Filters
```json
"searchBy": "Search by name, reason, ID...",
"viewTheItem": "View the {item}",
"changeToRole": "Change to {role}",
"revokeAdminAccess": "Revoke admin access",
"revokeAction": "Revoke"
```

### Settings & Configuration
```json
"feesUpdated": "Fees updated",
"feePercentage": "Fee percentage",
"minimumFee": "Minimum fee (XOF)",
"maximumFee": "Maximum fee (XOF)",
"platformCommission": "Platform commission",
"minimumCommission": "Minimum commission (XOF)",
"maximumCommission": "Maximum commission (XOF)",
"boostRatesUpdated": "Boost rates updated",
"vatRateUpdated": "VAT rate updated",
"mediaLimitsUpdated": "Media limits updated",
"maxDimension": "Max dimension (px)",
"compressionQuality": "Compression quality (%)",
"maxImagesPerUpload": "Max images/upload",
"maxImageSize": "Max image size (MB)",
"maxVideoSize": "Max video size (MB)",
"maxCharsPerMessage": "Max characters per message",
"urlsUpdated": "URLs updated",
"intervalsUpdated": "Intervals updated",
"baseShareUrl": "Base URL for sharing",
"supportEmail": "Support email",
"privacyEmail": "Privacy email (GDPR)",
"bugReportEmail": "Bug report email",
"feedbackEmail": "Feedback email",
"moderationEmail": "Moderation email",
"locationUpdateInterval": "Location update (min)",
"onlineStatusHeartbeat": "Online status heartbeat (min)",
"cacheDuration": "Cache duration (min)",
"audioSettingsUpdated": "Audio settings updated",
"exampleValues": "Ex: 1, 2, 5, 10, 20"
```

### User Management
```json
"searchUser": "Search for a user...",
"noUserFound": "No user found",
"noActivityRecorded": "No activity recorded",
"activityOf": "Activity of {name}",
"confirmLogoutTitle": "Confirm logout",
"disconnect": "Disconnect",
"privateGroup": "Private",
"publicGroup": "Public"
```

### Embassy Status Messages
```json
"embassyApproved": "Embassy {name} approved",
"embassyRejected": "Embassy {name} rejected",
"embassySuspended": "Embassy {name} suspended",
"embassyReactivated": "Embassy {name} reactivated",
"rejectRequest": "Reject the request",
"featureFlagsUpdated": "Feature flags updated",
"maintenanceMessage": "Ex: Application under maintenance..."
```

### Authentication
```json
"signInWithGoogle": "Sign in with Google",
"loginButton": "Login"
```

### Marketplace & Business
```json
"products": "Products ({count})",
"orders": "Orders ({count})",
"disputes": "Disputes ({count})",
"groupsCount": "Groups ({count})",
"sendButton": "Send",
"history": "History",
"titleLabel": "Title",
"emailAddress": "Email address",
"emailPlaceholder": "user@example.com",
"passwordLabel": "Password",
"businessCreated": "Business created successfully!",
"creationError": "Error during creation",
"newBusiness": "New business",
"photos": "Photos",
"category": "Category",
"businessName": "Business name *",
"description": "Description *",
"contact": "Contact",
"telephone": "Telephone",
"address": "Address",
"offeredServices": "Offered services",
"addService": "Add a service",
"createBusiness": "Create business",
"typeColon": "Type:",
"durationColon": "Duration:",
"totalColon": "Total:"
```

### Reviews
```json
"modifyReview": "Modify",
"report": "Report",
"pleaseRate": "Please rate",
"pleaseWriteReview": "Please write a review",
"submissionError": "Error during submission",
"titleOptional": "Title (optional)",
"titleExample": "Ex: Excellent service",
"yourReview": "Your review",
"shareExperience": "Share your experience...",
"addButton": "Add"
```

### Camera & Media
```json
"flipCamera": "Flip",
"selectImages": "Select images",
"imageLimitReached": "Limit of 5 posters reached",
"selectionError": "Error during selection: {error}",
"shareRecap": "Share the recap",
"photoLimitReached": "Limit of 10 photos reached",
"addAtLeastOnePhoto": "Please add at least one photo",
"selectPhotos": "Select photos",
"addPhotos": "Add photos ({current}/{max})"
```

### Requests & Forms
```json
"requestSubmitted": "Request submitted successfully!",
"newRequest": "New request",
"exampleRequest": "Ex: Inquiry about passport",
"describeRequest": "Describe your request in detail...",
"searchCountry": "Search for a country",
"typeCountryName": "Type the country name",
"itinerary": "Itinerary"
```

### Group Management
```json
"modifyGroup": "Modify the group",
"requestSentSuccess": "Request sent successfully",
"promoteAdminTitle": "Promote Admin",
"removeAdminTitle": "Remove Admin",
"requestApproved": "Request approved",
"requestRefused": "Request refused",
"refuse": "Refuse",
"allLabel": "All",
"allCategories": "All"
```

### Social Sharing
```json
"whatsApp": "WhatsApp",
"facebook": "Facebook",
"xTwitter": "X",
"more": "More"
```

### Navigation & Services
```json
"messagesLabel": "Messages",
"groupsLabel": "Groups",
"marketplace": "Marketplace",
"transfers": "Transfers",
"directory": "Directory",
"activateButton": "ACTIVATE",
"simpleMapTest": "Simple Map Test"
```

### Product Form
```json
"addImage": "Add at least one image",
"customRate": "Custom rate (%)",
"rateExample": "Ex: 15",
"priceTTC": "Price incl. tax",
"subtotal": "Subtotal",
"tax": "Tax ({rate}%)",
"titlePlaceholder": "Ex: iPhone 13 Pro Max",
"descriptionPlaceholder": "Describe your product...",
"price": "Price",
"quantity": "Quantity",
"currency": "Currency",
"categoryLabel": "Category",
"condition": "Condition",
"countryLabel": "Country",
"cityAddress": "City/Address (optional)",
"cityExample": "Ex: Niamey",
"everything": "Everything",
"views": "views",
"published": "published"
```

### Media Gallery
```json
"photosCount": "Photos ({count})",
"filesCount": "Files ({count})",
"addCaption": "Add a caption..."
```

### File Types
```json
"pdfLabel": "PDF",
"docLabel": "DOC",
"xlsLabel": "XLS",
"pptLabel": "PPT",
"zipLabel": "ZIP",
"txtLabel": "TXT",
"csvLabel": "CSV",
"jsonLabel": "JSON"
```

### Notifications & Reminders
```json
"joinLabel": "Join",
"messageCopied": "Message copied",
"remindLater": "Remind me later",
"inOneHour": "In 1 hour",
"reminderScheduled": "Reminder scheduled",
"tomorrowMorning": "Tomorrow morning (9am)"
```

### Payment Accounts
```json
"exampleBank": "Ex: BCEAO, Ecobank...",
"ibanExample": "NEXX XXXX XXXX XXXX"
```

### Podcasts
```json
"categoryRequired": "Category *",
"languageRequired": "Language *",
"publicationFrequency": "Publication frequency",
"tags": "Tags",
"addTag": "Add a tag",
"likes": "Likes",
"endOfEpisode": "End of episode",
"sleepTimerEnded": "Sleep timer ended",
"timerMinutes": "Timer: {minutes} minutes",
"podcastNotFound": "Podcast not found",
"addChapter": "Add a chapter",
"chapterTitle": "Chapter title",
"minutes": "Minutes",
"seconds": "Seconds",
"newEpisode": "New episode",
"episodeTitle": "Episode title *",
"episodeDescription": "Description / Notes",
"reservedForSubscribers": "Reserved for paying subscribers",
"downloaded": "Downloaded",
"download": "Download",
"deleteDownload": "Delete download",
"downloadDeleted": "Download deleted",
"selectPodcast": "Select a podcast or create a new one",
"recordingAvailableSoon": "The recording will be available soon",
"audioFileNotFound": "Audio file not found",
"publicationError": "Error during publication",
"createPodcast": "Create a podcast",
"episodeTitlePlaceholder": "Episode title",
"episodeDescriptionPlaceholder": "Episode description (optional)",
"publish": "Publish"
```

### Profile & Security
```json
"codeSent": "Code sent to {phone}",
"travelMode": "Travel Mode",
"myReports": "My reports",
"describeIssue": "Describe the issue...",
"sendReport": "Send the report",
"renameDeviceTitle": "Rename the device",
"deviceName": "Device name",
"rename": "Rename",
"revokeDeviceQuestion": "Revoke device?",
"connectedDevicesTitle": "Connected devices",
"backupKeys": "Key backup",
"deleteBackupQuestion": "Delete backup?",
"restoreKeys": "Restore keys",
"generateSecurePassphrase": "Generate a secure passphrase",
"minimumChars": "Minimum 8 characters",
"confirmPassphraseLabel": "Confirm passphrase",
"createBackupButton": "Create backup",
"ok": "OK",
"searchCurrency": "Search for a currency...",
"termsOfUse": "Terms of use",
"bugDescriptionLabel": "Bug description",
"bugDescriptionPlaceholder": "Describe the issue encountered..."
```

### Transfers
```json
"addManually": "Add manually",
"chooseRecipient": "Choose a recipient",
"addRecipient": "Add a recipient",
"newRecipient": "New",
"deleteRecipientQuestion": "Delete recipient?",
"deleteRecipientConfirm": "Do you want to delete {name}?",
"deleteQuestion": "Delete?",
"sendMoney": "Send money",
"modify": "Modify",
"deleteConfirm": "Delete {name}?",
"transferDetails": "Transfer details",
"amountSent": "Amount sent",
"fees": "Fees",
"exchangeRate": "Exchange rate",
"copiedToClipboard": "Copied to clipboard",
"retryTransfer": "Retry the transfer",
"contactSupport": "Contact support",
"debitInProgress": "Debit in progress",
"inProgress": "In progress",
"sendingInProgress": "Sending in progress",
"completed": "Completed",
"failed": "Failed",
"refundInProgress": "Refund in progress",
"refunded": "Refunded",
"cancelled": "Cancelled",
"liveChat": "Live chat",
"liveChatAvailable": "Available 24/7",
"chatNotAvailable": "Chat not available at the moment",
"transferHistory": "Transfer history",
"activeFilters": "Active filters: ",
"clearAll": "Clear all",
"sendMoneyButton": "Send money",
"choosePeriod": "Choose a period",
"applyFilters": "Apply filters",
"info": "Info"
```

### Error Messages
```json
"imageSelectionError": "Error selecting image: {error}",
"applicationError": "Error during application: {error}"
```

### Audio Rooms & Heritage
```json
"warnHost": "Warn the host",
"helperText": "Min: {min} XOF - Max: {max} XOF",
"tales": "Tales",
"proverbs": "Proverbs",
"ceremonies": "Ceremonies",
"craft": "Craft",
"recipes": "Recipes",
"medicine": "Medicine"
```

### Tax & VAT
```json
"automatic": "Automatic",
"exempt": "Exempt",
"standardVAT": "Standard VAT (19%)",
"reducedVAT": "Reduced VAT (10%)",
"custom": "Custom",
"typeYourResponse": "Type your response..."
```

## French Translations (app_fr.arb)

All the above keys need corresponding French translations. The French text can be found in the hardcoded strings in the source files.

## Files Already Updated

- ✅ `lib/features/admin/presentation/widgets/permission_guard.dart`

## Files Still Needing Updates

Based on the check script output, the following files have hardcoded French strings that need to be replaced with localized strings:

### High Priority (Admin Screens)
- `lib/core/services/notification_service.dart`
- `lib/core/services/tax_provider.dart`
- `lib/features/admin/presentation/screens/admin_analytics_screen.dart`
- `lib/features/admin/presentation/screens/admin_dashboard_screen.dart`
- `lib/features/admin/presentation/screens/admin_embassy_verification_screen.dart`
- `lib/features/admin/presentation/screens/admin_feature_flags_screen.dart`
- `lib/features/admin/presentation/screens/admin_moderation_screen.dart`
- `lib/features/admin/presentation/screens/admin_reports_screen.dart`
- `lib/features/admin/presentation/screens/admin_settings_screen.dart`
- `lib/features/admin/presentation/screens/admin_transactions_screen.dart`
- All other admin screens...

### Feature Screens
- Business screens
- Embassy screens
- Events screens
- Groups screens
- Marketplace screens
- Messages screens
- Podcasts screens
- Profile screens
- Transfers screens
- And many more...

## DateFormat Locales

Files using `DateFormat` with hardcoded 'fr_FR' locale need to be updated to use:
```dart
DateFormat('pattern', Localizations.localeOf(context).languageCode)
```

Files with this issue include:
- `lib/features/audio_rooms/presentation/screens/schedule_room_screen.dart`
- `lib/features/events/presentation/screens/event_detail_screen.dart`
- `lib/features/events/presentation/screens/events_screen.dart`
- `lib/features/reports/presentation/screens/my_reports_screen.dart`
- `lib/features/transfers/presentation/screens/transaction_detail_screen.dart`
- `lib/features/transfers/presentation/screens/transaction_history_screen.dart`
- And others...

## Next Steps

1. Wait for the localization file stabilization
2. Add all missing keys to `app_en.arb`
3. Add corresponding French translations to `app_fr.arb`
4. Run `flutter gen-l10n` to generate localization classes
5. Update all Dart files to use the localized strings
6. Replace all `DateFormat` hardcoded locales with dynamic locale resolution
7. Run the check script again to verify all hardcoded strings are removed
