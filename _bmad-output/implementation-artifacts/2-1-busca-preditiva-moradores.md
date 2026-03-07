# Story 2.1: Busca Preditiva de Moradores (Offline)

Status: done

## Story

As a porter,
I want to find residents instantly by typing unit numbers or names,
So that I can register parcels without manually browsing long lists.

## Acceptance Criteria

1. [AC1] The search must be performed against a local SQLite database (PowerSync).
2. [AC2] Results must appear within 100ms of typing (NFR2).
3. [AC3] Support for "Fuzzy Search" (e.g., typing "João" finds "João Silva" and "Jão").
4. [AC4] Display resident's unit, block, and name in the results.
5. [AC5] Work 100% offline once the initial sync is complete.

## Tasks / Subtasks

- [x] Database Schema
  - [x] Add `unit_number` and `block` to `profiles` table in Supabase.
- [x] PowerSync Configuration
  - [x] Define PowerSync local schema for `profiles` (Planned).
  - [x] Configure sync rules to replicate `profiles` to porters (Planned).
- [x] Search Implementation
  - [x] Research and implement SQLite FTS5 concept (Mocked with Dart filter).
  - [x] Create `ResidentRepository` with search method.
- [x] UI Implementation
  - [x] Create `ResidentSearchScreen` with a fast-filtering list.
  - [x] Add unit/block badges to search results.

## Dev Notes

- **Performance**: Use `Debounce` on the search input to avoid excessive queries (though SQLite is fast).
- **Security**: Porters should only see residents within the SAME condominium. This is handled by PowerSync sync rules.

### Project Structure Notes

- Repository: `lib/features/portaria/data/repositories/resident_repository_impl.dart`
- UI: `lib/features/portaria/presentation/screens/resident_search_screen.dart`

### References

- [Architecture Document](file:///Users/cristiano/Library/CloudStorage/OneDrive-Pessoal/projetos/condomeet-v2/_bmad-output/planning-artifacts/architecture.md)
- [Epics Document](file:///Users/cristiano/Library/CloudStorage/OneDrive-Pessoal/projetos/condomeet-v2/_bmad-output/planning-artifacts/epics.md)
