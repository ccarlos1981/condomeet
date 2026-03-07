# Story 1.2: Schema Multi-Condomínio (Postgres + RLS)

Status: done

## Review Follow-ups (AI)

- [x] [AI-Review][High] Implemented `deleted_at` columns and functional soft-delete support in SQL.
- [x] [AI-Review][High] Added `handle_updated_at()` trigger function and applied to all tables for PowerSync.
- [x] [AI-Review][High] Optimized RLS policies to avoid Recursion and N+1 performance bottlenecks.
- [x] [AI-Review][High] Updated Dart models (`Profile`, `Condominium`) with full metadata and robust parsing.

## Story

As a system architect,
I want to implement a multi-tenant database schema with Row Level Security (RLS),
so that each condominium's data is strictly isolated and secure.

## Acceptance Criteria

1. [AC1] The `condominiums` table must be created with `id` (UUID), `name`, `slug` (unique), and `created_at`.
2. [AC2] The `profiles` table must extend Supabase Auth and include `condominium_id` and `role` (porter, resident, admin).
3. [AC3] RLS Policies must be enabled on all tables to restrict access: `SELECT`, `INSERT`, `UPDATE` must filter by `condominium_id` based on the user's JWT claim or profile.
4. [AC4] A foreign key constraint must exist between all functional tables (parcels, residents) and the `condominiums` table.
5. [AC5] SQL scripts must be idempotent (using `CREATE TABLE IF NOT EXISTS` or Migrations).

## Tasks / Subtasks

- [x] Database Schema Definition (AC: 1, 2, 4)
  - [x] Create `condominiums` table.
  - [x] Create `profiles` table linked to `auth.users` and `condominiums`.
  - [x] Add `condominium_id` to future tables (placeholders or notes).
- [x] Security & Isolation (AC: 3)
  - [x] Enable RLS on `condominiums` and `profiles`.
  - [x] Implement the `check_condo_access()` Postgres function to validate user access in RLS policies.
  - [x] Create policies for `condominiums` and `profiles` tables.
- [x] PowerSync Integration Preparation
  - [x] Ensure all tables have `updated_at` and `deleted_at` (soft-delete) support for sync.

## Dev Notes

- **Multi-tenancy Strategy**: Database-level isolation via RLS is mandatory.
- **Supabase**: Use `auth.uid()` and custom claims or profile lookups in RLS.
- **PowerSync**: PowerSync needs RLS to be correctly configured to filter data for the client's local SQLite database.
- **Reference**: [Architecture: architecture.md#DataSecurity], [PRD: prd.md#Non-FunctionalRequirements].

### Project Structure Notes

- SQL migrations should be placed in `supabase/migrations/` (if using Supabase CLI) or documented in a `docs/sql/` folder.

### References

- [Architecture Document](file:///Users/cristiano/Library/CloudStorage/OneDrive-Pessoal/projetos/condomeet-v2/_bmad-output/planning-artifacts/architecture.md)
- [PRD Requirements](file:///Users/cristiano/Library/CloudStorage/OneDrive-Pessoal/projetos/condomeet-v2/_bmad-output/planning-artifacts/prd.md)

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

- SQL migration created with idempotent DDL statements.
- Multi-tenancy enforced via Row Level Security (RLS) policies.
- `check_condo_access()` function implemented for secure condominium-scoped queries.
- Dart models (`Condominium`, `Profile`) created with Equatable for clean state management.
- All code passes static analysis with zero issues.
- **IMPORTANT**: SQL script is local only - no database changes have been applied to production.

### File List

- `supabase/migrations/20260212_create_multi_condo_schema.sql`
- `lib/shared/models/condominium.dart`
- `lib/shared/models/profile.dart`
