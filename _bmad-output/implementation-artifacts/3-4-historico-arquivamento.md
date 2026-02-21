# Story 3.4: Histórico & Arquivamento

Status: ready-for-dev

## Story

As a user (Porter or Resident),
I want to consult the history of parcels delivered in the last 30 days,
So that I can resolve any disputes about past deliveries.

## Acceptance Criteria

1. [AC1] Porter can view a history of all delivered parcels in the condominium.
2. [AC2] Resident can view their own history of delivered parcels.
3. [AC3] Full audit trail: Show who received, when, and verification method used.
4. [AC4] Automatic archiving: UI hides records older than 90 days.

## Tasks / Subtasks

- [ ] Repository Layer
  - [ ] Add `getParcelHistory` to `ParcelRepository`.
- [ ] UI Implementation
  - [ ] Create `ParcelHistoryScreen`.
- [ ] Navigation
  - [ ] Add link to history in Porter and Resident dashboards.

## Dev Notes

- **LGPD**: Data retention is strictly 90 days for the audit trail.
