# Story 5.2: Official Broadcasts System

Status: ready-for-dev

## Story

As a condominium manager,
I want to send official announcements to all residents,
So that important news (maintenance, meetings, security alerts) are seen by everyone.

## Acceptance Criteria

1. [AC1] The manager can create a broadcast with: Title, Content, and Priority (Normal, Important, Critical).
2. [AC2] Residents see broadcasts on their main dashboard.
3. [AC3] **Priority UI**:
   - **Critical**: Red/Banner style (hard to miss).
   - **Normal/Important**: Standard card style.
4. [AC4] Residents can mark a broadcast as "Read" to dismiss it from the main view (unless it's Critical and configured to stay).
5. [AC5] History of broadcasts is available for reference.

## Tasks / Subtasks

- [ ] Data Layer
  - [ ] Implement `BroadcastRepository` (Mock).
  - [ ] Define `Broadcast` model with status tracking.
- [ ] UI Implementation
  - [ ] Build `BroadcastBanner` / `BroadcastCard`.
  - [ ] Build `BroadcastHistoryScreen`.
- [ ] Integration
  - [ ] Inject broadcasts into the Resident Dashboard.

## Dev Notes

- **Aesthetics**: Use the Design System's semantic colors (e.g., `AppColors.primary` for normal, `Colors.red` for critical).
- **Persistence**: For the MVP, dismissing a broadcast will be local-only (simulated).
