# Story 4.4: Manager Approval Swipe UI

Status: ready-for-dev

## Story

As a condominium manager,
I want to quickly review pending resident registrations using a swipe interface (Tinder-style or list-swipe),
So that I can maintain the community's security without friction.

## Acceptance Criteria

1. [AC1] The manager sees a list of "Pending" residents.
2. [AC2] Each registration item shows the resident's photo, name, and unit.
3. [AC3] **Swipe Right** to Approve.
4. [AC4] **Swipe Left** to Reject/Delete.
5. [AC5] Immediate visual feedback (Success message + list update).
6. [AC6] UI must look premium and administrative (Safe & Trusted).

## Tasks / Subtasks

- [ ] Repository Layer
  - [ ] Add `getPendingResidents` to `ResidentRepository`.
  - [ ] Add `approveResident` and `rejectResident` methods.
- [ ] UI Implementation
  - [ ] Build `ManagerApprovalScreen`.
  - [ ] Implement swipeable list items or a high-engaging deck UI.
- [ ] Navigation
  - [ ] Link from Admin/Showcase dashboard.

## Dev Notes

- **Aesthetics**: Use smooth animations (e.g., `Dismissible` with colored backgrounds).
- **Security**: This is the final gate. Approval should move the user record to the active `residents` table (simulated in mock).
