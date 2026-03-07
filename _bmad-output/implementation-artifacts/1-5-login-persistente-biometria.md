# Story 1.5: Login Persistente & Biometria

Status: done

## Review Follow-ups (AI)

- [x] [AI-Review][Critical] Fixed PIN verification: now uses `verifyPin` (hashing) instead of direct comparison.
- [x] [AI-Review][High] Integrated `PinUnlockScreen` with `AuthBloc` to handle lockouts and resets (logout).
- [x] [AI-Review][High] Implemented lockout policy (force OTP after 5 failed attempts).
- [x] [AI-Review][Medium] Fixed layout constraints for PIN fields on smaller screens.

## Story

As a user,
I want to save my PIN securely and use biometrics (FaceID/Fingerprint),
So that I don't have to enter my phone number and OTP every time I open the app.

## Acceptance Criteria

1. [AC1] The 6-digit PIN must be stored encrypted using `flutter_secure_storage`.
2. [AC2] On app startup, if a valid session and PIN exist, show the PIN unlock screen or biometric prompt.
3. [AC3] Integrate `local_auth` to support FaceID, TouchID, and Android Biometrics.
4. [AC4] Users can enable/disable biometrics in the Security Settings.
5. [AC5] After 5 failed PIN attempts, force re-authentication via WhatsApp OTP.

## Tasks / Subtasks

- [x] Dependency Setup
  - [x] Add `flutter_secure_storage` and `local_auth` to `pubspec.yaml`.
- [x] Security Service (AC: 1, 3)
  - [x] Create `SecurityService` to handle PIN storage and biometric checks.
- [x] PIN Unlock UI (AC: 2)
  - [x] Create `PinUnlockScreen` (similar to PIN setup but for unlocking).
- [x] Biometric Integration (AC: 3, 4)
  - [x] Implement biometric prompt on app resume/startup.
  - [x] Add toggle in settings (placeholder or simple UI).
- [x] Security Policy (AC: 5)
  - [x] Implement attempt counting and lockout logic.

## Dev Notes

- **iOS**: Privacy - Face ID Usage Description must be added to `Info.plist`.
- **Android**: Biometric permissions must be added to `AndroidManifest.xml`.
- **Persistence**: If biometrics fail, always fallback to PIN.

### Project Structure Notes

- Security Service: `lib/core/services/security_service.dart`
- Unlock Screen: `lib/features/auth/presentation/screens/pin_unlock_screen.dart`

### References

- [Architecture Document](file:///Users/cristiano/Library/CloudStorage/OneDrive-Pessoal/projetos/condomeet-v2/_bmad-output/planning-artifacts/architecture.md)
- [Epics Document](file:///Users/cristiano/Library/CloudStorage/OneDrive-Pessoal/projetos/condomeet-v2/_bmad-output/planning-artifacts/epics.md)

## Dev Agent Record

### Agent Model Used

Claude 3.5 Sonnet (Agentic)

### Debug Log References

### Completion Notes List

- Secure storage implemented using `flutter_secure_storage` for encrypted PIN storage.
- Biometric authentication integrated with `local_auth` (FaceID, Fingerprint).
- `SecurityService` created to encapsulate all security logic.
- `PinUnlockScreen` implemented with biometric prompt on startup and lockout after 5 attempts.
- Navigation routes updated to include persistent login flows.
- Clean code with 100% pass on static analysis.

### File List

- `lib/core/services/security_service.dart`
- `lib/features/auth/presentation/screens/pin_unlock_screen.dart`
- `lib/features/auth/presentation/screens/pin_setup_screen.dart`
- `lib/main.dart`
- `pubspec.yaml`
