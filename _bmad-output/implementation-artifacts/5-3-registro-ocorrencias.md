# Story 5.3: Occurrence Registration with Photos

Status: ready-for-dev

## Story

As a resident,
I want to report an occurrence in the condominium (e.g., broken equipment, noise, security breach),
So that the administration can resolve it and I have proof of my report.

## Acceptance Criteria

1. [AC1] The resident can create a new occurrence report.
2. [AC2] Form must include:
   - Category (Maintenance, Security, Noise, Others).
   - Description.
3. [AC3] **Photo Evidence**: Resident can attach up to 3 photos (simulated with placeholders/mock paths).
4. [AC4] Reports are saved with a "Pending" status.
5. [AC5] Resident can view the list of their own reports and their current status.

## Tasks / Subtasks

- [ ] Data Layer
  - [ ] Implement `OccurrenceRepository` (Mock).
  - [ ] Define `Occurrence` model with categories and status.
- [ ] UI Implementation
  - [ ] Build `OccurrenceReportScreen` (Form).
  - [ ] Build `OccurrenceListWidget` for the resident's dashboard.
- [ ] Integration
  - [ ] Add entry point to the Resident's side menu or home.

## Dev Notes

- **Aesthetics**: Use clear status badges (Orange for Pending, Blue for In Progress, Green for Resolved).
- **Prototyping**: We will mock the photo selection process for now by allowing the user to "simulate" a capture.
