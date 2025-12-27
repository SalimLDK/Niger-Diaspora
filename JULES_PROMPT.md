<instruction>You are an expert software engineer. You are working on a WIP branch. Please run `git status` and `git diff` to understand the changes and the current state of the code. Analyze the workspace context and complete the mission brief.</instruction>
<workspace_context>
<artifacts>
--- CURRENT TASK CHECKLIST ---
# Message Encryption Implementation
- [x] Complete

# Group Moderation & Reporting Backend
- [x] Complete

# Group Moderation & Reporting UI
- [x] Implementation
    - [x] Add provider methods <!-- id: 21 -->
    - [x] Update GroupMembersScreen with admin controls <!-- id: 22 -->
    - [x] Add message reporting to DeleteMessageModal <!-- id: 23 -->
    - [x] Add group reporting to ConversationOptionsModal <!-- id: 24 -->
- [ ] Verification (Manual Testing Required)
    - [ ] Test group admin promotion/demotion
    - [ ] Test member removal
    - [ ] Test message reporting
    - [ ] Test group reporting

--- IMPLEMENTATION PLAN ---
# Group Moderation & Reporting UI Implementation Plan

## Goal
Add UI controls for group admins to manage members and allow users to report inappropriate content.

## Current State Analysis
- **GroupMembersScreen**: Already displays members with Admin/Creator badges
- **ConversationScreen**: Has message list and options menu
- **Backend**: All moderation methods implemented ✅

## Proposed UI Changes

### 1. Group Members Screen Enhancements
#### [MODIFY] [group_members_screen.dart](file:///c:/Users/danko/StudioProjects/projet_perso/diaspo_niger/lib/features/groups/presentation/screens/group_members_screen.dart)

**For Admins Only:**
- Add long-press menu on member items with options:
  - **Promote to Admin** (if not admin)
  - **Remove Admin Rights** (if admin, but not creator)
  - **Remove from Group** (if not creator)
- Check if current user is admin using `conversation.adminIds.contains(currentUserId)`

### 2. Message Reporting
#### [MODIFY] [conversation_screen.dart](file:///c:/Users/danko/StudioProjects/projet_perso/diaspo_niger/lib/features/messages/presentation/screens/conversation_screen.dart)

**For All Users:**
- Add long-press menu on messages with "Report Message" option
- Show dialog to collect report reason
- Submit report via new provider method

### 3. Group Reporting
#### [MODIFY] [conversation_screen.dart](file:///c:/Users/danko/StudioProjects/projet_perso/diaspo_niger/lib/features/messages/presentation/screens/conversation_screen.dart)

**In Group Conversation Options:**
- Add "Report Group" option in `_showConversationOptions` menu
- Show dialog to collect report reason

### 4. Provider Methods
#### [NEW] Methods in conversation_actions_provider.dart or message_provider.dart
- `promoteToAdmin(conversationId, userId)`
- `demoteFromAdmin(conversationId, userId)`  
- `removeUserFromGroup(conversationId, userId)`
- `reportMessage(conversationId, messageId, reason)`
- `reportGroup(conversationId, reason)`

## Verification Plan
1. Create a test group with multiple members
2. Verify creator sees admin controls
3. Test promoting/demoting admins
4. Test removing members
5. Test reporting messages and groups
6. Verify reports appear in Firestore `reports` collection
</artifacts>
</workspace_context>
<mission_brief>[Describe your task here...]</mission_brief>