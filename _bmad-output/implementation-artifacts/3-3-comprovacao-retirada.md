# Story 3.4: Histórico & Arquivamento

Status: ready-for-dev

## Story

As a user (Porter or Resident),
I want to consult the history of parcels delivered in the last 30 days,
So that I can resolve any disputes about past deliveries.

## Acceptance Criteria

1. [AC1] Porter can view a history of all delivered parcels in the condominium.
2. [AC2] Resident can view their own history of delivered parcels.
3. [AC3] Full audit trail: Show who received, when, and local proof (PIN/Photo).
4. [AC4] Filter by date range or unit number (for porter).
5. [AC5] Automatic archiving (per NFR9/LGPD): UI hides records > 90 days.

## Tasks / Subtasks

- [ ] Repository Layer
  - [ ] Add `getParcelHistory` to `ParcelRepository`.
- [ ] UI Implementation
  - [ ] Create `ParcelHistoryScreen`.
  - [ ] Use a consistent style with the current dashboard and pending lists.
- [ ] Logic
  - [ ] Apply date filtering.

## Dev Notes

- **LGPD**: Records older than 90 days should be marked for deletion or moved to an archive table in the real implementation. For the mock, we just filter them out.
