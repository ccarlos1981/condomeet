# Story 5.4: Resident-Admin Official Chat

Status: ready-for-dev

## Story

As a resident,
I want to have a direct, authenticated chat channel with the condominium administration,
So that I can resolve doubts and receive official support without using non-official channels like WhatsApp groups.

## Acceptance Criteria

1. [AC1] The resident can open a chat session with the "Administration".
2. [AC2] **Real-time feel**: Messages sent by the resident appear immediately in the UI (simulated).
3. [AC3] **Authenticated Profile**: Each message shows the sender's identity (Resident name/Unit).
4. [AC4] **History**: Residents can see previous messages in the conversation.
5. [AC5] **Admin Mock**: For the MVP, we will simulate administration replies to demonstrate the flow.

## Tasks / Subtasks

- [ ] Data Layer
  - [ ] Implement `ChatRepository` (Mock).
  - [ ] Define `ChatMessage` model.
- [ ] UI Implementation
  - [ ] Build `ChatScreen` with message bubbles and input bar.
  - [ ] Implement message grouping by date.
- [ ] Integration
  - [ ] Add entry point to the Resident's side menu or home.

## Dev Notes

- **Aesthetics**: Use distinct bubble styles (Primary color for resident, Surface/Gray for Adiministration).
- **Prototyping**: We will use a `Stream` to simulate incoming messages from the admin after a short delay.
