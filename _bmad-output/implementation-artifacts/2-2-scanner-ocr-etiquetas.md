# Story 2.2: Scanner OCR de Etiquetas (ML Kit)

Status: review

## Story

As a porter,
I want to scan package labels using the device camera,
So that I can extract the unit number without manual typing.

## Acceptance Criteria

1. [AC1] The app must open the camera with a defined scanning area (overlay).
2. [AC2] Use Google ML Kit (Text Recognition) locally for label extraction.
3. [AC3] Detect unit numbers (e.g., "Apt 101", "Unidade 202") and auto-fill the search.
4. [AC4] Provide a "Flash" toggle for low-light conditions.
5. [AC5] Fallback to manual search if scanning fails or takes > 2 seconds.

## Tasks / Subtasks

- [x] Dependency Setup
  - [x] Add `camera` and `google_mlkit_text_recognition` to `pubspec.yaml`.
- [x] OCR Logic
  - [x] Implement `OcrService` to process camera frames.
  - [x] Add regex logic to extract numbers from recognized text.
- [x] UI Implementation
  - [x] Create `OcrScannerScreen` with camera preview and overlay.
  - [x] Integrate scanner button into `ResidentSearchScreen`.

## Dev Notes

- **Regex**: Look for patterns like `\d{2,4}` often prefixed by labels like "Apto", "Unit", etc.
- **Optimization**: Don't process every single frame; skip frames to save battery and CPU.
