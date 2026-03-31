# smart_meter_texas

Flutter client for SMT usage tracking.

## Backend Integration

The app reads backend settings from compile-time defines:

- `SMT_BACKEND_BASE_URL` (default: `http://10.0.2.2:3000`)
- `SMT_BACKEND_API_KEY` (optional; required if backend enables `x-api-key`)

Run example:

```bash
flutter run \
  --dart-define=SMT_BACKEND_BASE_URL=http://10.0.2.2:3000 \
  --dart-define=SMT_BACKEND_API_KEY=your_key_here
```

Current integrated flow:

- `login` calls `POST /api/smt/login` and persists `sessionId`
- `home/energy` calls `POST /api/smt/usage`
- `history` calls `POST /api/smt/usage/history` (daily range)
