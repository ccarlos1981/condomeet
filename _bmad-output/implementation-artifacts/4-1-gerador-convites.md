# Story 4.1: Digital Invitation Generator

Status: ready-for-dev

## Story

As a resident,
I want to generate a digital invitation for my guest,
So that they can enter the condominium without the porter needing to call my unit.

## Acceptance Criteria

1. [AC1] The resident chooses a "Guest Name".
2. [AC2] The resident sets a "Validity" (Today, Tomorrow, or Custom Date).
3. [AC3] The system generates a unique invitation (Mock QR code representation).
4. [AC4] The invitation can be shared via the native mobile share sheet.
5. [AC5] UI must use the design system (CondoInput, CondoButton).

## Tasks / Subtasks

- [x] Data Layer
  - [x] Create `Invitation` model.
  - [x] Implement `InvitationRepository` (Mock).
- [x] UI Implementation
  - [x] Build `InvitationGeneratorScreen`.
  - [x] Implement "Share" logic using `share_plus` (Simulated for web).
- [x] Navigation
  - [x] Add "Gerar Convite" to the resident's home.

## Dev Notes

- **UX**: The form should be extremely fast (2 fields: Name & Date).
- **Security**: Invitations are unit-specific and have an expiry.
