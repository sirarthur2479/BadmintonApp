# TASK-024 - Flutter auth: AuthProvider, login/register screens, token storage

**Use case:** [ideas/use-cases/self-hosted-backend.md](../../ideas/use-cases/self-hosted-backend.md)
**Research:** [research/fastapi-auth.md](../../research/fastapi-auth.md)
**Depends on:** TASK-021
**Effort:** M
**Risk:** medium

**Status:** done

## Goal

The client half of auth, **web-gated only**: an `AuthProvider` that
registers/logs in against `/api/v1/auth/*`, persists the JWT, exposes
`isLoggedIn`, and injectable-HTTP-client tests; plus login and register
screens. Mobile stays offline-first — on non-web platforms the auth gate is
bypassed entirely and nothing changes. Token storage uses
`shared_preferences` (already a dependency; localStorage-backed on web) —
`flutter_secure_storage` is unnecessary since mobile never stores a token.

## Acceptance criteria

- `pubspec.yaml` adds `http` (latest ^1.x).
- `lib/services/api_client.dart`: thin wrapper holding `baseUrl` (from
  `String.fromEnvironment('API_BASE_URL')` with a localhost default) and an
  injectable `http.Client`; helpers `getJson/postJson/putJson/delete` that
  attach `Authorization: Bearer <token>` when a token callback is set and
  throw typed `ApiException(statusCode, message)` on non-2xx.
- `lib/providers/auth_provider.dart`: `login(email, password)`,
  `register(email, password)` (auto-login after), `logout()`,
  `isLoggedIn`, `token`; persists/restores the token via
  `shared_preferences` key `auth_token`; `restore()` runs at startup;
  401-from-login surfaces a user-readable error string, not an exception.
- `lib/screens/auth/login_screen.dart` + `register_screen.dart`: email +
  password forms, inline error display, disabled button while submitting,
  link between the two screens.
- Auth gate in `lib/app.dart`: on web, unauthenticated → `LoginScreen`;
  non-web → existing `MainShell` untouched (test-locked).
- All logic unit-tested with a mocked `http.Client`
  (`package:http/testing.dart` `MockClient`) — no live server.
- `flutter test` fully green.

## Test plan

RED first in `badminton_flutter/test/providers/auth_provider_test.dart` and
`test/screens/auth_screens_test.dart`:

- `login stores token and sets isLoggedIn`
- `login with 401 exposes error and stays logged out`
- `register auto-logs-in on success`
- `logout clears token from prefs`
- `restore picks up a persisted token`
- `api client attaches bearer header when token present`
- `api client throws ApiException with status on non-2xx`
- `login screen submits credentials and navigates on success`
- `login screen shows inline error on failure`
- `register screen links back to login`
- `app shows MainShell unauthenticated on non-web` (auth gate bypass)

## Implementation plan

1. `flutter pub add http`.
2. `api_client.dart`: `class ApiClient { ApiClient({http.Client? inner,
   String? baseUrl, String? Function()? tokenProvider}) }` + `ApiException`.
3. `auth_provider.dart`: constructor takes `ApiClient` (defaults to real);
   `SharedPreferences` for persistence (mock via
   `SharedPreferences.setMockInitialValues` in tests, same as profile
   tests).
4. Screens under `lib/screens/auth/`; reuse `AppTheme` field styling.
5. `app.dart`: `Consumer<AuthProvider>` gate wrapped in `if (kIsWeb)`;
   register `AuthProvider` in `main.dart` and call `restore()` before
   `runApp` (web only).
6. Full `flutter test`.
