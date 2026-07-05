# FreeThumb for Windows

Status: **skeleton only** — not yet functional. The macOS version is the stable
reference implementation and lives in `../macos/`.

## Tech stack

- C# / .NET 8
- WPF (Windows Presentation Foundation)
- Win32 P/Invoke for power management
- xUnit for tests

## Project layout

```
apps/windows/
├── FreeThumb.sln
├── FreeThumb/          # WPF application
│   ├── App/            # Application orchestration (AppController)
│   ├── UI/             # Tray popup, settings window
│   ├── Power/          # Win32 power wrappers (PowerRequest, status, events)
│   ├── Settings/       # Settings persistence
│   ├── Update/         # Update checking
│   └── Resources/      # Icons and resources
└── FreeThumb.Tests/    # xUnit tests
```

## Open in Visual Studio

1. Open `FreeThumb.sln` in Visual Studio 2022 (17.8+).
2. Restore NuGet packages.
3. Build and run `FreeThumb`.

## Build from the command line

```powershell
dotnet build FreeThumb.sln -c Release
dotnet test FreeThumb.sln
```

## Roadmap

See `../../docs/windows-development-lessons.md` for the macOS-to-Windows port
guidance. The MVP order is:

1. System tray UI, timed session, status icon.
2. Power Request idle-sleep prevention with cleanup.
3. AC/battery/low-battery events reusing the macOS alert semantics.
4. Sleep-model and lid capability diagnostics (no automatic policy change).
5. Evaluate a user-confirmed lid-policy wizard later.
