# BLoC Guidelines

## Naming and intent
- Use `LoadX` for first fetch when screen opens.
- Use `RefreshX` for pull-to-refresh or user-initiated reload.
- Use `SubmitX` for form actions (login, save settings, etc).
- Keep events feature-scoped; avoid generic event names.

## States
- Every feature must have: `Initial`, `Loading`, `Loaded`, and `Error`.
- `Error` must carry a user-visible message.
- Never fall back to blank UI for unhandled states.

## UI behavior
- Loading state shows deterministic indicator/skeleton.
- Error state shows message + retry action.
- Retry should dispatch `LoadX` or `RefreshX`.

## Error handling
- Repositories throw `AppException` only (not raw `Exception`).
- Bloc maps exception through `userMessageFor(...)` before emitting `Error`.

## Data flow
- UI -> Event -> Bloc -> Repository -> ApiClient.
- Keep parsing and HTTP concerns out of bloc/widgets.
- Keep business rules out of widgets.

## Practical rules
- One feature bloc per feature boundary.
- Avoid cross-feature bloc dependencies unless unavoidable.
- Keep state immutable and minimal.