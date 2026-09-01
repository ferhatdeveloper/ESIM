class ApiConstants {
  const ApiConstants._();

  static const postgrestBaseUrl = String.fromEnvironment(
    'POSTGREST_URL',
    defaultValue: 'http://127.0.0.1:3000',
  );

  static const connectTimeout = Duration(seconds: 20);
  static const receiveTimeout = Duration(seconds: 20);

  static const register = '/rpc/register';
  static const login = '/rpc/login';
  static const refreshSession = '/rpc/refresh_session';
  static const logout = '/rpc/logout';
  static const requestPasswordReset = '/rpc/request_password_reset';
  static const resetPassword = '/rpc/reset_password';
  static const updateProfile = '/rpc/update_profile';
  static const createCheckout = '/rpc/create_checkout';
  static const confirmMockPayment = '/rpc/confirm_mock_payment';
  static const retryProvisioning = '/rpc/retry_provisioning';
  static const activateEsim = '/rpc/activate_esim';
  static const applyEsimUsage = '/rpc/apply_esim_usage';
  static const markNotificationRead = '/rpc/mark_notification_read';
  static const markAllNotificationsRead = '/rpc/mark_all_notifications_read';

  static const countries = '/countries';
  static const regions = '/regions';
  static const marketplacePlans = '/marketplace_plans';
  static const publicSettings = '/public_settings';
  static const me = '/me';
  static const myEsims = '/my_esims';
  static const myEsimUsage = '/my_esim_usage';
  static const myOrders = '/my_orders';
  static const myNotifications = '/my_notifications';
}

class AppConstants {
  const AppConstants._();

  static const supportedLocales = ['en', 'tr', 'ar'];
  static const supportedCurrencies = ['USD', 'EUR', 'TRY', 'IQD'];
  static const defaultLocale = 'en';
  static const defaultCurrency = 'USD';
  static const demoEmail = 'demo@esim.app';
  static const demoPassword = 'Demo12345!';

  /// Local SQLite is the default until PostgREST is wired in production.
  static const useSqlite = bool.fromEnvironment('USE_SQLITE', defaultValue: true);
}
