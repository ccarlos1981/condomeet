# Story 4.2: Guest Access Terminal (Porter)

Status: ready-for-dev

## Story

As a porter,
I want to see a list of active invitations and verify guests quickly,
So that I can authorize entry without manual phone calls to residents.

## Acceptance Criteria

1. [AC1] The porter sees a list of "Active" digital invitations.
2. [AC2] Porter can search for invitations by guest name.
3. [AC3] Each invitation shows the resident's name, unit, and validity.
4. [AC4] Porter can mark a guest as "Entered" (Check-in).
5. [AC5] Fast interaction with success feedback (Snackbar/Haptics).

## Tasks / Subtasks

- [ ] UI Implementation
  - [ ] Build `GuestCheckinScreen`.
  - [ ] Implement live search/filtering of invitations.
- [ ] Integration
  - [ ] Use `InvitationRepository.getActiveInvitations()`.
  - [ ] Use `InvitationRepository.markAsUsed()`.
- [ ] Navigation
  - [ ] Add "Terminal de Visitantes" to the porter's dashboard/menu.

## Dev Notes

- **Efficiency**: Porters should be able to check-in a guest with 2 taps (find -> authorize).
- **Offline First**: PowerSync handles the invitation sync between resident and porter in the background.
