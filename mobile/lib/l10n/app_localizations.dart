import 'package:flutter/widgets.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocDelegate();

  static const supportedLocales = [
    Locale('en'),
    Locale('tr'),
    Locale('ar'),
  ];

  bool get isRtl => locale.languageCode == 'ar';

  String get _code => locale.languageCode;

  String _t(String en, String tr, String ar) {
    switch (_code) {
      case 'tr':
        return tr;
      case 'ar':
        return ar;
      default:
        return en;
    }
  }

  String get appName => _t('Voyage eSIM', 'Voyage eSIM', 'فوييج eSIM');
  String get home => _t('Home', 'Ana sayfa', 'الرئيسية');
  String get explore => _t('Explore', 'Keşfet', 'استكشف');
  String get myEsims => _t('My eSIMs', 'eSIM\'lerim', 'شرائحي');
  String get orders => _t('Orders', 'Siparişler', 'الطلبات');
  String get profile => _t('Profile', 'Profil', 'الملف');
  String get login => _t('Sign in', 'Giriş yap', 'تسجيل الدخول');
  String get register => _t('Create account', 'Hesap oluştur', 'إنشاء حساب');
  String get email => _t('Email', 'E-posta', 'البريد');
  String get password => _t('Password', 'Şifre', 'كلمة المرور');
  String get fullName => _t('Full name', 'Ad soyad', 'الاسم الكامل');
  String get forgotPassword => _t('Forgot password?', 'Şifremi unuttum', 'نسيت كلمة المرور؟');
  String get resetPassword => _t('Reset password', 'Şifreyi sıfırla', 'إعادة تعيين كلمة المرور');
  String get sendReset => _t('Send reset link', 'Sıfırlama gönder', 'إرسال رابط الإعادة');
  String get newPassword => _t('New password', 'Yeni şifre', 'كلمة مرور جديدة');
  String get resetToken => _t('Reset token', 'Sıfırlama kodu', 'رمز الإعادة');
  String get searchDestination => _t('Where are you going?', 'Nereye gidiyorsun?', 'إلى أين تسافر؟');
  String get popularCountries => _t('Popular countries', 'Popüler ülkeler', 'دول شائعة');
  String get featuredPlans => _t('Featured packages', 'Öne çıkan paketler', 'باقات مميزة');
  String get yourEsims => _t('Your eSIMs', 'eSIM\'lerin', 'شرائحك');
  String get seeAll => _t('See all', 'Tümünü gör', 'عرض الكل');
  String get regions => _t('Regions', 'Bölgeler', 'المناطق');
  String get packages => _t('Packages', 'Paketler', 'الباقات');
  String get data => _t('Data', 'Veri', 'البيانات');
  String get validity => _t('Validity', 'Süre', 'المدة');
  String get days => _t('days', 'gün', 'أيام');
  String get price => _t('Price', 'Fiyat', 'السعر');
  String get checkout => _t('Checkout', 'Ödeme', 'الدفع');
  String get payMock => _t('Pay with mock provider', 'Sahte sağlayıcı ile öde', 'ادفع بالمزوّد التجريبي');
  String get mockNotice => _t(
        'This checkout uses the mock payment adapter. No real card is charged and no live eSIM is issued.',
        'Bu ödeme sahte ödeme adaptörünü kullanır. Gerçek kart çekilmez, canlı eSIM üretilmez.',
        'يستخدم هذا الدفع محول الدفع التجريبي. لن تُخصم بطاقة حقيقية ولن تُصدر شريحة حية.',
      );
  String get taxes => _t('Taxes', 'Vergiler', 'الضرائب');
  String get fees => _t('Fees', 'Ücretler', 'الرسوم');
  String get total => _t('Total', 'Toplam', 'الإجمالي');
  String get remaining => _t('Remaining', 'Kalan', 'المتبقي');
  String get original => _t('Original', 'Orijinal', 'الأصلي');
  String get status => _t('Status', 'Durum', 'الحالة');
  String get expires => _t('Expires', 'Bitiş', 'ينتهي');
  String get activated => _t('Activated', 'Etkinleştirme', 'التفعيل');
  String get install => _t('Install eSIM', 'eSIM kur', 'تثبيت الشريحة');
  String get qrInstall => _t('QR installation', 'QR ile kurulum', 'التثبيت عبر QR');
  String get manualInstall => _t('Manual installation', 'Manuel kurulum', 'التثبيت اليدوي');
  String get iosSteps => _t(
        'iOS: Settings → Cellular → Add eSIM → Use QR Code, or enter SM-DP+ and activation code.',
        'iOS: Ayarlar → Hücresel → eSIM Ekle → QR Kod Kullan veya SM-DP+ ve etkinleştirme kodunu gir.',
        'iOS: الإعدادات → خلوي → إضافة eSIM → استخدام رمز QR أو إدخال SM-DP+ ورمز التفعيل.',
      );
  String get androidSteps => _t(
        'Android: Settings → Network & internet → SIMs → Add eSIM → Scan QR, or enter the activation code.',
        'Android: Ayarlar → Ağ ve internet → SIM\'ler → eSIM ekle → QR tara veya etkinleştirme kodunu gir.',
        'Android: الإعدادات → الشبكة والإنترنت → بطاقات SIM → إضافة eSIM → امسح QR أو أدخل الرمز.',
      );
  String get noInstallData => _t(
        'Installation data is not available yet. The provider has not supplied a payload.',
        'Kurulum verisi henüz yok. Sağlayıcı bir yük iletmedi.',
        'بيانات التثبيت غير متاحة بعد. لم يزوّد المزوّد حمولة.',
      );
  String get mockInstall => _t(
        'Mock installation payload. Do not treat this as a live carrier profile.',
        'Sahte kurulum yükü. Bunu canlı operatör profili sanmayın.',
        'حمولة تثبيت تجريبية. لا تعتبرها ملف مشغّل حي.',
      );
  String get activate => _t('Mark as installed', 'Kuruldu olarak işaretle', 'علّم كمثبّتة');
  String get language => _t('Language', 'Dil', 'اللغة');
  String get currency => _t('Currency', 'Para birimi', 'العملة');
  String get theme => _t('Theme', 'Tema', 'السمة');
  String get notifications => _t('Notifications', 'Bildirimler', 'الإشعارات');
  String get logout => _t('Sign out', 'Çıkış', 'تسجيل الخروج');
  String get retry => _t('Retry', 'Yeniden dene', 'أعد المحاولة');
  String get empty => _t('Nothing here yet', 'Henüz bir şey yok', 'لا يوجد شيء بعد');
  String get emptyEsims => _t('You have no eSIMs yet. Buy a one-time plan to start.', 'Henüz eSIM\'in yok. Tek kullanımlık bir paket al.', 'لا تملك شرائح بعد. اشتر باقة لمرة واحدة.');
  String get emptyOrders => _t('No orders yet.', 'Sipariş yok.', 'لا طلبات بعد.');
  String get loading => _t('Loading', 'Yükleniyor', 'جارٍ التحميل');
  String get oneTimeRule => _t(
        'Each eSIM has its own balance. Balances cannot be transferred or merged.',
        'Her eSIM\'in kendi bakiyesi vardır. Bakiyeler aktarılamaz veya birleştirilemez.',
        'لكل شريحة رصيدها. لا يمكن نقل الأرصدة أو دمجها.',
      );
  String get network => _t('Network', 'Şebeke', 'الشبكة');
  String get iccid => _t('ICCID', 'ICCID', 'ICCID');
  String get smdp => _t('SM-DP+', 'SM-DP+', 'SM-DP+');
  String get activationCode => _t('Activation code', 'Etkinleştirme kodu', 'رمز التفعيل');
  String get filterAll => _t('All', 'Tümü', 'الكل');
  String get filterActive => _t('Active', 'Aktif', 'نشطة');
  String get filterReady => _t('Ready', 'Hazır', 'جاهزة');
  String get filterExpired => _t('Expired', 'Süresi doldu', 'منتهية');
  String get filterDepleted => _t('Depleted', 'Tükendi', 'مستنفدة');
  String get filterCancelled => _t('Cancelled', 'İptal', 'ملغاة');
  String get buy => _t('Continue to checkout', 'Ödemeye geç', 'متابعة الدفع');
  String get usageHistory => _t('Usage history', 'Kullanım geçmişi', 'سجل الاستخدام');
  String get alreadyHaveAccount => _t('Already have an account?', 'Hesabın var mı?', 'لديك حساب؟');
  String get needAccount => _t('New here?', 'Yeni misin?', 'جديد هنا؟');
  String get systemTheme => _t('System', 'Sistem', 'النظام');
  String get lightTheme => _t('Light', 'Açık', 'فاتح');
  String get darkTheme => _t('Dark', 'Koyu', 'داكن');
  String get paymentFailed => _t('Payment failed. No eSIM was created.', 'Ödeme başarısız. eSIM oluşturulmadı.', 'فشل الدفع. لم تُنشأ شريحة.');
  String get purchaseOk => _t('Purchase complete', 'Satın alma tamam', 'اكتمل الشراء');
  String get viewEsim => _t('View eSIM', 'eSIM\'i gör', 'عرض الشريحة');
  String get noResults => _t('No destinations match your search.', 'Aramanızla eşleşen destinasyon yok.', 'لا توجد وجهات مطابقة.');
}

class _AppLocDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'tr', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}
