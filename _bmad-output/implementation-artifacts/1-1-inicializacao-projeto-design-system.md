# Story 1.1: Inicialização do Projeto & Design System

Status: done

## Review Follow-ups (AI)

- [x] [AI-Review][High] Added `focusNode`, `textInputAction` and `onFieldSubmitted` to `CondoInput`.
- [x] [AI-Review][High] Implemented robust widget tests in `test/widget_test.dart`.
- [x] [AI-Review][Medium] Converted `AppTypography` to static final constants for performance.
- [x] [AI-Review][Medium] Completed `AppTheme.dark` with full `textTheme` mapping.
- [x] [AI-Review][Medium] Added `fold` method to `Result` class for functional patterns.
- [x] [AI-Review][Low] Removed TODO comments and cleaned up theme code.

## Story

As a developer,
I want to initialize the Flutter project with a custom theme and Tailwind UI tokens,
so that all features have a consistent and premium "Tranquilidade" look and feel.

## Acceptance Criteria

1. [AC1] The app should use the brand Orange-Red (`#FA542F`) as `primaryColor` in `ThemeData`.
2. [AC2] Typography must be configured with Google Fonts (Inter/Outfit) as per UX spec.
3. [AC3] Folder structure must follow the "Feature-First" pattern (e.g., `lib/features/auth`, `lib/core/design_system`).
4. [AC4] Custom base widgets (Buttons, Inputs) must implement the Tailwind UI style guidelines.
5. [AC5] Basic error handling using the Result Pattern must be established in `lib/core/errors`.

## Tasks / Subtasks

- [x] Project Setup (AC: 3)
  - [x] Initialize Flutter project.
  - [x] Configure `pubspec.yaml` with essential dependencies: `flutter_bloc`, `supabase_flutter`, `powersync`, `fpdart`, `google_fonts`.
  - [x] Create folder structure following feature-first architecture.
- [x] Design System Foundation (AC: 1, 2, 4)
  - [x] Implement `AppColors` and `AppTypography` constants.
  - [x] Define the global `ThemeData` in `lib/core/design_system/theme.dart`.
  - [x] Create `CondoButton` and `CondoInput` atomic components following Tailwind UI aesthetics.
- [x] Core Utils (AC: 5)
  - [x] Implement the `Result` class (success/failure) for consistent error handling.
  - [x] Setup initial logging for development.

## Dev Notes

- **Arch Pattern**: Use BLoC for state management and Repository Pattern for data access.
- **Visuals**: Aim for "vibrant colors", "subtle micro-animations", and "glassmorphism" where applicable.
- **Structure**: All design tokens should be in `lib/core/design_system`.
- **Reference**: [Architecture: architecture.md#ImplementationPatterns], [UX Spec: ux-design-specification.md#DesignSystemFoundation].

### Project Structure Notes

- Feature-first structure:
  ```
  lib/
    core/
      design_system/
      errors/
      network/
    features/
      auth/
      parcels/
  ```

### References

- [UX: _bmad-output/planning-artifacts/ux-design-specification.md]
- [Arch: _bmad-output/planning-artifacts/architecture.md]
- [Epics: _bmad-output/planning-artifacts/epics.md]

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

- Flutter project initialized using SDK 3.41.0.
- Feature-first directory structure established.
- Core dependencies configured and installed (`flutter_bloc`, `supabase_flutter`, `powersync`, etc.).
- Design System tokens (Colors, Typography) and Theme implemented.
- Atomic widgets (`CondoButton`, `CondoInput`) created with haptic feedback.
- Global `Result` pattern established for error handling.
- `main.dart` updated with a Design System showcase.
- Static analysis and widget tests pass 100%.

### File List

- `pubspec.yaml`
- `lib/main.dart`
- `lib/core/design_system/app_colors.dart`
- `lib/core/design_system/app_typography.dart`
- `lib/core/design_system/theme.dart`
- `lib/core/design_system/condo_button.dart`
- `lib/core/design_system/condo_input.dart`
- `lib/core/design_system/design_system.dart`
- `lib/core/errors/result.dart`
- `test/widget_test.dart`
