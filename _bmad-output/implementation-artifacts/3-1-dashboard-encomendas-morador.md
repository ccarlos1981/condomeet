# Story 3.1: Dashboard de Encomendas (Morador)

Status: ready-for-dev

## Story

As a resident,
I want to see a clear list of my pending parcels with photos,
So that I know exactly what needs to be collected from the gate.

## Acceptance Criteria

1. [AC1] The resident must see a card-based list of parcels with status "Aguardando Retirada".
2. [AC2] Each card must show:
   - Arrival Date/Time.
   - Parcel Photo (if captured).
   - Porter's name (optional).
3. [AC3] Fast loading (< 300ms) from local storage.
4. [AC4] Empty state should be welcoming and clear.

## Tasks / Subtasks

- [ ] UI Components
  - [ ] Create `ParcelCard` widget for the dashboard.
  - [ ] Handle image loading with placeholders.
- [ ] Screen Implementation
  - [ ] Build `ParcelDashboardScreen`.
  - [ ] Integrate with `ParcelRepository` to fetch parcels for the current user.
- [ ] Navigation
  - [ ] Add "Minhas Encomendas" to the resident's home.

## Dev Notes

- **Optimistic UI**: Residents should see new parcels as soon as PowerSync pushes the sync update.
- **Empty State**: "Tudo limpo! Nenhuma encomenda aguardando você."
