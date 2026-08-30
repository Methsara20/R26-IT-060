# AGENTS.md

# Smart Omni-Retail System — Repository Instructions

## 1. Project Context

This repository is part of a university Final Year Research Project for a Smart Omni-Retail System.

The repository may contain code created by multiple team members and may currently have inconsistent folder structures, naming conventions, duplicate organizational patterns, or files placed in inappropriate directories.

The current objective is to standardize and clean the repository structure WITHOUT changing existing functionality.

---

## 2. CRITICAL RULE — PRESERVE EXISTING FUNCTIONALITY

Existing application behavior must be preserved.

Unless the user explicitly requests a functional change:

* DO NOT change business logic.
* DO NOT change algorithms.
* DO NOT change calculations.
* DO NOT change conditions or decision rules.
* DO NOT rewrite working functions.
* DO NOT change API behavior.
* DO NOT change request or response formats.
* DO NOT change database behavior.
* DO NOT change Firebase queries or collections.
* DO NOT change authentication behavior.
* DO NOT change AI/ML logic.
* DO NOT change recommendation logic.
* DO NOT change forecasting logic.
* DO NOT change analytics logic.
* DO NOT change marketing logic.
* DO NOT change UI behavior.
* DO NOT remove UI features.
* DO NOT remove API endpoints.
* DO NOT delete functions, classes, widgets, models, services, routes, schemas, assets, configuration, or other existing implementation files.

The code may be reorganized, but its behavior must remain equivalent.

---

## 3. NO DELETION POLICY

Do not delete existing project code during cleanup.

If a file appears:

* unused,
* duplicated,
* obsolete,
* misplaced,
* strangely named,
* unrelated,
* or potentially unnecessary,

do NOT delete it automatically.

Move questionable files to an appropriate location if their purpose is clear.

If their purpose is unclear, leave them unchanged and report them to the user.

Deletion may only happen when the user explicitly authorizes it.

---

## 4. STRUCTURE-ONLY REFACTORING

When asked to clean or standardize the repository, permitted operations include:

* Creating folders.
* Moving files.
* Renaming folders where necessary.
* Renaming files when clearly necessary for consistency.
* Updating imports after moving files.
* Updating relative paths after moving files.
* Updating package/module references caused strictly by file movement.
* Removing genuinely empty directories.
* Organizing assets.
* Organizing configuration files.
* Organizing tests.
* Organizing documentation.

Do not perform unrelated refactoring while reorganizing files.

For example, moving a service from one directory to another does NOT give permission to rewrite that service.

---

## 5. IMPORT/PATH CHANGES

Import and path updates are allowed ONLY when required because files were moved.

When updating imports:

1. Preserve the imported symbols.
2. Preserve application behavior.
3. Do not replace libraries.
4. Do not redesign dependency relationships unless required for the new path.
5. Do not modify function bodies unless an import/path issue makes it absolutely necessary.

---

## 6. BEFORE MAKING STRUCTURAL CHANGES

Inspect the complete repository first.

Identify:

* frontend technology,
* backend technology,
* current folder structure,
* entry points,
* configuration files,
* environment files,
* dependencies,
* API routes,
* services,
* models,
* schemas,
* utilities,
* UI screens/pages,
* components/widgets,
* assets,
* tests,
* database-related files,
* authentication files,
* AI/ML-related files,
* team-member-specific modules,
* duplicated organizational patterns.

Do not assume a framework merely from folder names.

Use the actual project files and dependency manifests to determine the technology.

---

## 7. SAFE RESTRUCTURING WORKFLOW

For repository cleanup tasks, follow this order:

### Phase 1 — Inspect

Read the repository and understand the current structure.

### Phase 2 — Map

Determine where each existing file belongs in the standardized structure.

### Phase 3 — Reorganize

Move files into the appropriate directories.

### Phase 4 — Repair References

Update imports and file paths caused by those moves.

### Phase 5 — Validate

Run available formatting, static analysis, tests, builds, or startup validation.

### Phase 6 — Report

Explain exactly:

* what folders were created,
* what files were moved,
* what files were renamed,
* what imports/paths were updated,
* what files were intentionally left unchanged,
* what questionable/duplicate files remain,
* whether validation succeeded.

---

## 8. FRONTEND ORGANIZATION

Determine the actual frontend framework before changing anything.

For a Flutter frontend, prefer a scalable structure similar to:

frontend/
lib/
core/
constants/
config/
theme/
utils/
models/
services/
repositories/
screens/
widgets/
providers/
routes/
assets/
test/

Do not force these directories if the existing architecture has a legitimate equivalent.

Existing functional modules should remain recognizable.

Do not merge unrelated screens/services simply to reduce the number of files.

---

## 9. BACKEND ORGANIZATION

Determine the backend framework before changing anything.

For a FastAPI/Python backend, prefer a scalable structure similar to:

backend/
app/
api/
routes/
core/
schemas/
models/
services/
repositories/
utils/
ml/
tests/

Keep the existing application entry point working.

If moving the entry point would create unnecessary risk, leave it where it is.

Do not change endpoint URLs during structural cleanup.

Do not change request/response schemas during structural cleanup.

---

## 10. TEAM MODULE SEPARATION

This is a multi-member research project.

Different team members may own different modules.

Keep component boundaries understandable.

Do not merge another member's business logic into an unrelated module merely because similar helper functions exist.

Shared functionality may be placed in common/core/shared directories only when it is clearly shared already.

When ownership or purpose is uncertain, preserve the current separation.

---

## 11. CONFIGURATION AND SECRETS

Never expose secrets.

Do not print or commit values from:

* .env
* Firebase credentials
* service-account files
* API keys
* private keys
* database passwords
* access tokens

Do not replace existing environment-variable logic during structural cleanup.

Keep `.env` files out of source control where appropriate.

Preserve `.env.example` or equivalent configuration templates.

---

## 12. DEPENDENCIES

Do not:

* upgrade dependencies,
* downgrade dependencies,
* replace dependencies,
* remove packages,
* add alternative frameworks,

unless the user explicitly requests it.

Structural cleanup should use the project's existing dependencies.

---

## 13. API COMPATIBILITY

Existing frontend/backend integration must continue working.

Preserve:

* endpoint paths,
* HTTP methods,
* query parameters,
* request bodies,
* response structures,
* authentication headers,
* status-code expectations,
* service interfaces.

Do not introduce breaking API changes while reorganizing files.

---

## 14. DATABASE COMPATIBILITY

Do not modify existing database schema or Firestore structure unless explicitly requested.

Preserve:

* collection names,
* document structures,
* field names,
* query behavior,
* database references,
* IDs,
* relationships.

Moving source files must not alter persisted data behavior.

---

## 15. COMMENTS AND DOCUMENTATION

Do not remove existing meaningful comments.

You may add brief comments only where needed to explain structural decisions.

Do not flood the code with unnecessary generated comments.

---

## 16. FORMATTING

Avoid massive formatting-only changes.

Do not reformat entire working files simply because they were moved.

This keeps Git diffs readable and makes it easier to verify that logic did not change.

---

## 17. DUPLICATE FILES

If two files appear duplicated:

DO NOT choose one and delete the other automatically.

First determine whether they are genuinely duplicates and whether either one is referenced.

Unless deletion is explicitly authorized, preserve both and report the duplication.

---

## 18. GIT SAFETY

Prefer changes that produce clear, reviewable Git diffs.

Do not modify unrelated files.

Do not rewrite Git history.

Do not remove existing branches or commits.

Do not commit secrets.

When possible, use file moves rather than delete-and-recreate operations so Git history remains understandable.

---

## 19. VALIDATION

After structural changes, use the project's existing validation tools.

Depending on the discovered technology, this may include:

Flutter:

* flutter pub get
* flutter analyze
* flutter test
* flutter build web

Python/FastAPI:

* syntax/import validation
* existing tests
* project-specific startup checks

JavaScript/Node:

* npm install or npm ci when appropriate
* npm test
* npm run lint
* npm run build

Only run commands relevant to the actual repository.

Do not introduce new tools simply for validation.

---

## 20. FAILURE HANDLING

If moving a file creates a failure:

1. Identify whether the failure is caused by an import/path reference.
2. Fix only the structural reference.
3. Do not rewrite the underlying logic as a workaround.

If preserving behavior becomes uncertain, stop modifying that specific area and report it instead of guessing.

---

## 21. USER PRIORITY

Direct instructions from the user override structural preferences in this document.

However, never interpret a general request such as:

"clean the project"

as permission to delete code or redesign functionality.

Cleaning means organization unless the user explicitly requests functional refactoring.

---

## 22. MAIN PRINCIPLE

PRESERVE BEHAVIOR, IMPROVE ORGANIZATION.

The goal is:

Same application.
Same functions.
Same logic.
Same features.
Same APIs.
Same data behavior.

Better repository structure.
