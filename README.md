# Diary App

Personal diary app built with Flutter for iOS, Android, Windows, and macOS.

## Current Scope

This repository is intentionally scoped to a single-user MVP:

- Create and edit diary entries
- Attach multiple photos to an entry
- Browse recent entries
- Browse entries by month in a calendar view
- Search titles and content
- Persist data locally with SQLite
- Copy selected photos into the app's own media directory

## Stack

- Flutter
- Riverpod for state wiring
- go_router for app navigation
- SQLite via `sqflite` and `sqflite_common_ffi`
- `file_picker` for cross-platform image selection
- `path_provider` for application storage directories

## Project Structure

```text
lib/
  app/                     App bootstrap, theme, router
  core/
    database/              SQLite initialization
    storage/               Media file import/delete
    utils/                 Date formatting helpers
    widgets/               Shared UI building blocks
  features/
    calendar/              Month view
    entries/               Models, repository, editor, recent list
    search/                Search screen
```

## Local Storage Model

- `entries` table stores the diary metadata and text content.
- `photos` table stores photo metadata and local file paths.
- Image files are copied into the application support directory under `media/original/`.

This keeps the app independent from the original gallery or filesystem path chosen during import.

## Run

```bash
flutter pub get
flutter run
```

Example desktop run:

```bash
flutter run -d windows
```

Example mobile run after a simulator/device is available:

```bash
flutter run -d ios
flutter run -d android
```

## Quality Checks

```bash
flutter analyze
flutter test
```

## Recommended Next Steps

1. Add backup and restore for `diary.db` plus the `media/` directory.
2. Add thumbnail generation for large photo sets.
3. Add app lock with PIN or biometric unlock.
4. Add sync only after the local-first flow feels stable.
5. Add tag, mood, and weather metadata if you find yourself actually using them.
