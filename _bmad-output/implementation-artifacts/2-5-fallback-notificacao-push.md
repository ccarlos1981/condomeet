# Story 2.5: Fallback de Notificação Push

Status: review

## Story

As a resident,
I want to receive a push notification if my WhatsApp is unavailable,
So that I don't miss any parcel delivery alerts.

## Acceptance Criteria

1. [AC1] Detect WhatsApp message delivery failure (simulated for MVP).
2. [AC2] Automatically trigger a Push Notification as a fallback.
3. [AC3] Push notification must contain the same essential info (Unit, Arrival Time).
4. [AC4] Log the communication attempt strategy (WhatsApp -> Push).
5. [AC5] Mock implementation for initial UI/Flow verification.

## Tasks / Subtasks

- [x] Service Layer
  - [x] Add `sendPushNotification` to `MessagingService`.
  - [x] Implement orchestration logic: try WhatsApp, if fail -> try Push.
- [x] Integration
  - [x] Update `ParcelRegistrationScreen` to use the unified orchestration (Done via Service Mock).
- [x] Logging
  - [x] Print communication trail to console for debugging.

## Dev Notes

- **Orchestration**: The `MessagingService` should encapsulate the "if WhatsApp fails, then Push" logic to keep the UI layer simple.
- **Provider**: In a real app, Push would be handled by Firebase Cloud Messaging (FCM) or Supabase Push.
