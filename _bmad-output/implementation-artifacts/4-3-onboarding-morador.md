# Story 4.3: Resident Self-Onboarding flow

Status: ready-for-dev

## Story

As a new resident,
I want to register myself in the app by providing my details and unit,
So that the condominium manager can approve my access.

## Acceptance Criteria

1. [AC1] The user can access a "Registrar-se" screen during the login/onboarding flow.
2. [AC2] Registration form must include:
   - Full Name.
   - Profile Photo (Optional but recommended).
   - Block and Unit Number selection.
3. [AC3] Data must be saved as "Pending Approval" in the repository.
4. [AC4] User must see a clear "Waiting for Approval" status screen after submission.
5. [AC5] Fast and responsive form validation.

## Tasks / Subtasks

- [ ] Repository Layer
  - [ ] Add `requestOnboarding` to `AuthRepository` or `ResidentRepository`.
- [ ] UI Implementation
  - [ ] Build `SelfRegistrationScreen`.
  - [ ] Build `WaitingApprovalScreen`.
- [ ] Navigation
  - [ ] Link from Phone/OTP flow to Self-Registration if the user is not found.

## Dev Notes

- **UX**: If the user is already found in the database (via Phone number), we skip this. If not, we offer self-registration.
- **Trust**: We collect the unit info but it's only active after the manager swiped "Approve" (Story 4.4).
