Project

Smart Inventory & Stock Flow Optimization System — Flutter Web frontend for a 16-credit Final Year Research Project.

Agent Role

Act as a senior Flutter product engineer and UI/UX architect building a professional retail inventory decision-support application.

Critical Boundary: Backend Is Read-Only

Backend FastAPI/Python files may be READ for API/schema/reference purposes only.

Never create, modify, delete, rename, or move backend files.

Never change:

backend routes

backend schemas

backend services

Firestore logic

ML models

recommendation logic

stock movement logic

Gemini/Groq logic

weather logic

backend dependencies/configuration

If a frontend task requires a backend change, report the missing capability instead of changing the backend.

Writable Scope

Make implementation changes only in the Flutter frontend and repository-level frontend-support files explicitly requested by the user.

PP2 Frontend Modules

Dashboard

Forecasting

Inventory Intelligence

Optimization

Stock Movements

Analytics

Manager Assistant

Chat History

Contextual Assistant where applicable

Authentication, user management, notifications, and audit-log UI are out of scope until explicitly requested.

Backend Contract

Treat existing backend endpoints and response structures as fixed contracts.

Before integrating any API:

inspect the backend route;

inspect its request schema;

inspect the actual response shape;

implement Flutter code to match exactly.

Never invent endpoints or response fields.

Responsive Design

All screens must work across:

large desktops

standard laptops

smaller laptops

tablets

mobile/narrow browser widths

Avoid fixed-width layouts that overflow.
Use adaptive navigation and responsive card/form/table layouts.

UI Direction

Professional enterprise retail analytics:

clear hierarchy

clean spacing

consistent typography

restrained gradients

accessible contrast

meaningful charts

obvious status/risk/confidence indicators

consistent loading/empty/error states

Do not display invented production metrics or fake authenticated users.

File Naming

All new Dart files require descriptive names.

Good:

forecasting_overview_screen.dart

daily_forecast_form.dart

stock_movements_screen.dart

manager_assistant_screen.dart

app_navigation_sidebar.dart

forecast_api_service.dart

Forbidden generic filenames:

page.dart

screen.dart

widget.dart

card.dart

form.dart

service.dart

helper.dart

utils.dart

Structure

Prefer a feature-based structure under lib/:

core/

models/

services/

features/

Create files only when needed. Do not generate empty architecture scaffolding.

Legacy PP1 Code

PP1 frontend code may be inspected and selectively reused.
Do not delete legacy working code until a verified PP2 replacement exists.
Avoid extending legacy API contracts when the PP2 backend has newer endpoints.

Flutter Quality

Prefer:

const constructors when appropriate

focused widgets

typed models where valuable

centralized API base URL

readable async/error handling

reusable components only when repetition justifies them

descriptive methods and classes

Avoid:

giant monolithic widgets

duplicated API logic

UI-embedded business logic

hardcoded fake backend data

unnecessary packages

unexplained magic numbers

Network UX

For API-connected screens implement:

initial state

loading state

success state

empty state

error state

retry when useful

Prevent accidental duplicate state-changing requests.

Stock Movement Safety

Never present an approve/reject/cancel/execute action as successful unless the backend confirms success.
Use confirmation dialogs for state-changing actions.

Chatbot Safety

Use the PP2 Manager Assistant API contract, including session/history behavior.
Do not revive the legacy PP1 /chat contract unless explicitly requested.
Let the backend build AI context when that capability exists.

Validation

After changes:

format changed Dart files

run flutter analyze

run relevant tests if present

Do not modify the backend to make frontend validation pass.

If tooling cannot run, state that explicitly.

Repository Maintenance Exception

The backend remains read-only for application logic.

However, when the user explicitly requests repository cleanup,
Git cleanup, secret cleanup, ignore-rule maintenance, or removal
of generated/obsolete repository artifacts, the agent may perform
repository-maintenance operations affecting backend paths only under
the following strict conditions.

Allowed repository-maintenance actions:

- inspect Git status and tracked/untracked files
- inspect and update the root .gitignore
- remove generated Python cache files such as:
  - __pycache__/
  - *.pyc
  - *.pyo
- remove IDE/cache/temp artifacts
- stop tracking files that should be ignored using git rm --cached
- remove exposed credential files from Git tracking
- identify obsolete backup files and datasets for user approval
- identify duplicate files
- inspect whether sensitive files are already tracked
- clean generated artifacts that are not application source code

Sensitive files that must never be committed include:

- .env
- .env.*
- Firebase service-account credential files
- API keys
- private credentials
- secret configuration files

Repository cleanup MUST NOT:

- modify Python application logic
- modify backend routes
- modify backend schemas
- modify backend services
- modify Firestore logic
- modify ML/recommendation logic
- modify Gemini/Groq logic
- modify backend dependencies
- delete trained models or datasets without explicit user approval
- delete active source files without explicit user approval
- reset or discard legitimate source-code changes
- commit
- push
- rewrite Git history unless explicitly requested

When files are already tracked but should be ignored, prefer removing
them from Git tracking rather than deleting the user's local copy.

Before destructive cleanup:

1. inspect Git status;
2. categorize files;
3. show the cleanup plan;
4. wait for explicit user approval.

Repository-cleanup tasks are an exception only to file-maintenance
restrictions. The backend remains read-only for application behavior.

Required Final Report

For every task report:

- files created
- files modified
- files moved/renamed
- files deleted, if any
- files removed from Git tracking, if any
- .gitignore changes
- validation commands and outcomes

For normal frontend implementation tasks, end with:

"No backend application file was created, modified, moved, renamed, or deleted."

For explicit repository-maintenance tasks, instead report exactly which
backend-path artifacts were removed, ignored, or untracked and confirm:

"No backend application logic was modified."