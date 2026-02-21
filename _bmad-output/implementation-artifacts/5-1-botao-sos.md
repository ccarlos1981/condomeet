# Story 5.1: SOS Button (GPS + Critical Alert)

Status: ready-for-dev

## Story

As a resident in danger,
I want to press an SOS button in the app,
So that the porter and manager receive an immediate high-priority alert with my location.

## Acceptance Criteria

1. [AC1] The SOS button is easily accessible (e.g., bottom bar or pinned widget).
2. [AC2] To prevent accidents, it must be a **Long Press (3 seconds)**.
3. [AC3] Visual feedback: Progress bar or haptic "heartbeat" during the press.
4. [AC4] Once triggered, the app sends GPS coordinates (simulated) and Unit number.
5. [AC5] Porter terminal must show a **Critical Alert Overlay** that persists until acknowledged.

## Tasks / Subtasks

- [ ] UI Implementation
  - [ ] Build `SOSButton` (Progressive feedback UI).
  - [ ] Build `PanicOverlay` for the porter.
- [ ] Data Layer
  - [ ] Create `SOSRepository` (Mock).
  - [ ] Implement alert triggering logic.
- [ ] Navigation
  - [ ] Add SOS button to the main resident dashboard.

## Dev Notes

- **UX**: The 3-second hold is crucial to avoid "pocket dials".
- **Haptics**: Use increasing intensity haptics as the timer approaches the trigger.
