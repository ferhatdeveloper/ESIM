# eSIM — Flutter + SQLite (şimdilik)

Tek kullanımlık eSIM pazaryeri. Her satın alınan eSIM’in kendi bakiyesi vardır. Kullanıcı cüzdanı, bakiyeler arası aktarım veya birleştirme yoktur.

**Şu an varsayılan veri katmanı yerel SQLite.** PostgREST/PostgreSQL şeması `backend/` altında duruyor; üretimde `USE_SQLITE=false` ile açılacak.

## Mimari

```
Flutter (Riverpod / MVVM / GoRouter)
        │
        ├─ SQLite (varsayılan, cihaz içi)
        └─ PostgREST + PostgreSQL (hazır, henüz varsayılan değil)
```

İş kuralları her iki katmanda da aynıdır: fiyat SQLite/PostgreSQL’den okunur, ödeme doğrulanmadan eSIM oluşmaz, bakiye yalnızca `applyEsimUsage` ile değişir.

## Geliştirme

```bash
cd mobile
flutter pub get
flutter test
flutter run --dart-define=USE_SQLITE=true
```

Demo hesaplar:

- `demo@esim.app` / `Demo12345!`
- `admin@esim.app` / `Admin12345!`

## CI

GitHub Actions (`Flutter` workflow) analiz, test ve debug APK derlemesi çalıştırır.

## PostgREST (sonra)

```bash
cd backend && docker compose up -d
cd mobile && flutter run --dart-define=USE_SQLITE=false --dart-define=POSTGREST_URL=http://127.0.0.1:3000
```

Sözleşme: [docs/API_CONTRACT.md](docs/API_CONTRACT.md)
