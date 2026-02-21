# Story 6.1: Common Area Availability (Calendar)

Status: ready-for-dev

## Story

As a resident,
I want to see the availability of common areas in a visual calendar,
So that I can plan my events without needing to call the caretaker.

## Acceptance Criteria

1. [AC1] The resident can see a list of available amenities (Grill, Party Room, Multi-sport Court).
2. [AC2] Each amenity has a dedicated calendar view.
3. [AC3] **Visual Availability**:
   - Days with availability are clearly marked.
   - Fully booked days are grayed out or marked "Full".
4. [AC4] The resident can navigate between months.
5. [AC5] Basic info for each area is shown (Capacity, Guest rules, Opening hours).

## Tasks / Subtasks

- [ ] Data Layer
  - [ ] Define `CommonArea` and `AvailabilitySlot` models.
  - [ ] Implement query for available areas in `BookingRepository`.
- [ ] UI Implementation
  - [ ] Build `AreaListTile` widget.
  - [ ] Integrate a Calendar widget (or custom grid) for availability.
- [ ] Integration
  - [ ] Add "Reservas" entry point to navigation.

## Dev Notes

- **Aesthetics**: Use clean, card-based layouts with high-quality icons or images for each area.
- **Calendar**: For the MVP, a custom grid showing a 7-day or 30-day view is preferred over complex external calendar libraries.
