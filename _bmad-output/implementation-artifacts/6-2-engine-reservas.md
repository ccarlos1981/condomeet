# Story 6.2: Rule-Based Booking Engine

Status: ready-for-dev

## Story

As a resident,
I want to be able to request a booking for a common area,
So that I can secure the space for my event while respecting the condominium rules.

## Acceptance Criteria

1. [AC1] The resident can select an available date from the calendar.
2. [AC2] **Validation**:
   - Cannot book a date in the past.
   - Cannot book a date that is already taken.
   - (MVP Rule) Resident can only have one active future booking for a specific area at a time.
3. [AC3] **Confirmation Flow**:
   - Resident clicks "Solicitar Reserva".
   - System confirms the details (Area, Date, Guest Rules).
   - Resident confirms, and the state updates to "Booked".
4. [AC4] **Persistence**: The booking is saved in the repository (simulated).
5. [AC5] **UI Feedback**: Success/Error snackbars and visual update on the calendar.

## Tasks / Subtasks

- [ ] Data Layer
  - [ ] Update `BookingRepository` to actually persist bookings in mock memory.
  - [ ] Implement validation logic in the repository.
- [ ] UI Implementation
  - [ ] Add selection state to `AreaAvailabilityScreen`.
  - [ ] Build a "Confirmation Bottom Sheet" with area rules and final "Confirm" button.
  - [ ] Update calendar colors to show the newly created booking.
- [ ] Integration
  - [ ] Link "Solicitar Reserva" to the confirmation flow.

## Dev Notes

- **Aesthetics**: Use a semi-transparent overlay or high-contrast border for the "Selected Date".
- **Bottom Sheet**: The confirmation should feel "official", displaying the resident's unit and the specific rules they are agreeing to.
