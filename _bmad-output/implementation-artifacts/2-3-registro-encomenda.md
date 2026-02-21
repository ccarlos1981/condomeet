# Story 2.3: Registro de Encomenda (Local-First)

Status: review

## Story

As a porter,
I want to register a parcel with a single tap,
So that I can clear the gate queue immediately.

## Acceptance Criteria

1. [AC1] Navigate to registration screen after selecting a resident.
2. [AC2] Capture a photo of the package (optional but recommended).
3. [AC3] Show resident info (Name, Unit, Block) clearly on the screen.
4. [AC4] Instant feedback (vibration/haptic + success checkmark) upon registration.
5. [AC5] Local-first saving: save to SQLite instantly (Background sync handled by PowerSync).

## Tasks / Subtasks

- [x] Data Layer
  - [x] Create `Parcel` model.
  - [x] Create `ParcelRepository` and mock implementation.
- [x] UI Implementation
  - [x] Create `ParcelRegistrationScreen`.
  - [x] Implement camera capture for package photo (Simulated).
  - [x] Add success animation (Checkmark).
- [x] Integration
  - [x] Update `ResidentSearchScreen` to navigate to `ParcelRegistrationScreen`.
  - [x] Register new routes in `main.dart`.

## Dev Notes

- **Haptics**: Use `HapticFeedback.mediumImpact()`.
- **UX**: The "Registrar" button should be large and easy to hit.
- **Offline**: Data must be written to the local database immediately without waiting for server confirmation.
