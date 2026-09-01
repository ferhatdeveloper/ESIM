# eSIM — Flutter + PostgREST

Tek kullanımlık eSIM pazaryeri. Her satın alınan eSIM’in kendi bakiyesi vardır. Kullanıcı cüzdanı, bakiyeler arası aktarım veya birleştirme yoktur.

İstemci yalnızca **PostgreSQL + PostgREST** ile konuşur. FastAPI veya başka bir uygulama sunucusu yoktur.

## Mimari

```
Flutter (Riverpod / MVVM / GoRouter)
        │  HTTPS
        ▼
   PostgREST
        │
        ▼
 PostgreSQL
   • public views + RPC
   • app tables (not exposed)
   • app_private JWT, secrets, mock adapters
```

İş kuralları SQL fonksiyonlarında ve kısıtlarda uygulanır: fiyatı sunucu hesaplar, ödeme doğrulanmadan eSIM oluşmaz, bakiye yalnızca `apply_esim_usage` ile değişir.

Sahte ödeme ve sahte eSIM sağlayıcıları SQL içinde açıkça izole edilmiştir (`MOCK-` önekleri). Canlı operatör veya kart ağı gibi davranmazlar.

## Geliştirme

```bash
cd backend
cp .env.example .env
docker compose up --build
```

- PostgREST: `http://localhost:3000`
- PostgreSQL: `localhost:5432`

Demo hesaplar (yalnızca development seed):

- `demo@esim.app` / `Demo12345!`
- `admin@esim.app` / `Admin12345!`

```bash
cd mobile
flutter pub get
flutter run
```

`mobile/lib/core/constants/api_constants.dart` içindeki PostgREST taban URL’sini cihazınıza göre ayarlayın.

## Sözleşme

Ayrıntılar: [docs/API_CONTRACT.md](docs/API_CONTRACT.md)

## Fazlar

1. Mimari, tema, yönlendirme, yerelleştirme, kimlik doğrulama
2. PostgreSQL şema, PostgREST, RLS, seed
3. Ana sayfa, ülke/bölge, paket detayı
4. Checkout, sahte ödeme adaptörü, sipariş yaşam döngüsü
5. Sahte eSIM provizyonu ve eSIM’lerim
6. QR / manuel kurulum ve eSIM detayı
7. Gerçek sağlayıcı (henüz yok — `app_private.mock_provision_esim` değiştirilir)
8. Kullanım senkronu, bildirimler, güvenlik testleri
