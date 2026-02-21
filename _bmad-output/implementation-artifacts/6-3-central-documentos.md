# Story 6.3: Community Document Center

Status: ready-for-dev

## Story

As a resident,
I want to have access to official condominium documents (By-laws, Meeting Minutes, Forms),
So that I can stay informed and resolve bureaucratic needs independently.

## Acceptance Criteria

1. [AC1] The resident can see a categorized list of documents (Minutas, Regimento, Formulários).
2. [AC2] Each document entry shows: Title, Category, and Upload Date.
3. [AC3] **Visual Distinction**: Icons for different file types (PDF, Doc, Image).
4. [AC4] **Search/Filter**: Search by title or filter by category.
5. [AC5] **Download Simulation**: Tapping a document triggers a "Downloading/Opening" feedback.

## Tasks / Subtasks

- [ ] Data Layer
  - [ ] Define `CondoDocument` model.
  - [ ] Implement `DocumentRepository` (Mock).
- [ ] UI Implementation
  - [ ] Build `DocumentCenterScreen` with category tabs or a searchable list.
  - [ ] Create `DocumentTile` widget with file type icons.
- [ ] Integration
  - [ ] Add "Documentos" entry point to navigation.

## Dev Notes

- **Aesthetics**: Use a clean, professional folder/file list layout.
- **Interactions**: Use shimmer or loading states for the initial fetch and snackbars for "Opening File" simulation.
