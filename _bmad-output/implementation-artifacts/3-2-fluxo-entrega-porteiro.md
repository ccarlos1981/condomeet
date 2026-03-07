# Story 3.2: Fluxo de Entrega (Porteiro)

Status: ready-for-dev

## Story

As a porter,
I want to mark a parcel as "Delivered" when the resident collects it,
So that the inventory is always up-to-date and the queue is cleared.

## Acceptance Criteria

1. [AC1] The porter must see a list of all "Pending" parcels for the condominium.
2. [AC2] Each item must show the resident's name and unit number.
3. [AC3] A clear "Confirmar Entrega" button must be available for each item.
4. [AC4] Upon confirmation, the status must update immediately (Optimistic UI).
5. [AC5] Fast search/filter within the pending list.

## Tasks / Subtasks

- [x] Repository Layer
  - [x] Add `getAllPendingParcels` to `ParcelRepository`.
  - [x] Add `markAsDelivered` to `ParcelRepository`.
- [x] UI Implementation
  - [x] Create `PendingDeliveriesScreen`.
  - [x] Implement "Confirmar" action with success feedback.
- [x] Navigation
  - [x] Add link to "Entregas Pendentes" for porters.

## Dev Notes

- **Real-time**: When a porter marks a parcel as delivered, it should vanish from the resident's dashboard too.
- **Verification**: Story 3.3 will later add proof of pickup (PIN/Photo). For 3.2, we just update the status.
