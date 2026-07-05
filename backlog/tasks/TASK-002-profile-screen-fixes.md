# TASK-002 - Profile screen fixes: local photo rendering + reliable form population

**Use case:** [ideas/use-cases/flutter-bug-batch.md](../../ideas/use-cases/flutter-bug-batch.md)
**Research:** [badminton_flutter/docs/codebase-review-2026-07-05.md](../../badminton_flutter/docs/codebase-review-2026-07-05.md)
**Depends on:** TASK-001
**Effort:** S
**Risk:** medium
**Status:** todo

## Goal

Fix B1 (avatar uses `NetworkImage` on a local file path — broken on device)
and B2 (form is populated in `didChangeDependencies` before the async profile
load completes, never repopulates, and can clobber in-flight edits).

## Acceptance criteria

- On iOS/Android the avatar renders a picked photo from disk; web keeps
  working (blob URL via network provider). The web build must still compile —
  no unconditional `dart:io` import in code shared with web (B1).
- Fresh app start → Profile tab shows the saved profile once loading
  completes, without visiting another tab first (B2).
- While `_editing` is true, provider notifications and inherited-widget
  changes do NOT overwrite the user's unsaved field edits (B2).

## Test plan (RED first)

- `test/widgets/profile_avatar_test.dart`
  - `renders FileImage for a local path on non-web`
  - `renders fallback icon when path is null`
- `test/screens/profile_screen_test.dart`
  - `form fields populate when profile loads after first build`
  - `in-flight edits survive a provider notification while editing`
  - `save writes the edited profile to the provider`

## Implementation plan

1. New `lib/widgets/profile_avatar.dart`:
   `class ProfileAvatar extends StatelessWidget { final String? photoPath; final double radius; }`
   — resolves the image provider via a small helper with conditional import
   (`avatar_image_io.dart` using `FileImage(File(path))`,
   `avatar_image_web.dart` using `NetworkImage`), export signature
   `ImageProvider localImageProvider(String path)`.
2. `lib/screens/profile/profile_screen.dart`:
   - replace the `CircleAvatar` block (line ~114) with `ProfileAvatar`.
   - delete `didChangeDependencies`; instead track the last profile identity:
     in `build`, `final profile = context.watch<ProfileProvider>().profile;`
     and `if (!_editing && profile != _syncedProfile) { _syncControllers(profile); _syncedProfile = profile; }`.
   - `_syncControllers(PlayerProfile p)` sets all controllers/fields.
3. `PlayerProfile`: add `operator ==`/`hashCode` (or compare via a changed
   flag) so "profile changed" is detectable — simplest: implement equality on
   all fields.
