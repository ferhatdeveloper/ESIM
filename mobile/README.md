# Voyage eSIM (Flutter)

MVVM + Riverpod + GoRouter. Varsayılan veri katmanı **SQLite**.

```bash
flutter pub get
flutter test
flutter run --dart-define=USE_SQLITE=true
```

PostgREST için: `--dart-define=USE_SQLITE=false --dart-define=POSTGREST_URL=http://127.0.0.1:3000`
