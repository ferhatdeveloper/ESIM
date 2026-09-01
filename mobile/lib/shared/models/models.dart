class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.userId,
    required this.email,
    required this.fullName,
    required this.locale,
    required this.preferredCurrency,
    required this.appRole,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String userId;
  final String email;
  final String fullName;
  final String locale;
  final String preferredCurrency;
  final String appRole;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: (json['expires_in'] as num?)?.toInt() ?? 900,
      userId: json['user_id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String? ?? '',
      locale: json['locale'] as String? ?? 'en',
      preferredCurrency: json['preferred_currency'] as String? ?? 'USD',
      appRole: json['app_role'] as String? ?? 'customer',
    );
  }
}

class Country {
  const Country({
    required this.id,
    required this.iso2,
    required this.nameEn,
    required this.nameTr,
    required this.nameAr,
    required this.flagEmoji,
    required this.isPopular,
  });

  final String id;
  final String iso2;
  final String nameEn;
  final String nameTr;
  final String nameAr;
  final String flagEmoji;
  final bool isPopular;

  String localizedName(String locale) {
    switch (locale) {
      case 'tr':
        return nameTr;
      case 'ar':
        return nameAr;
      default:
        return nameEn;
    }
  }

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      id: json['id'] as String,
      iso2: json['iso2'] as String,
      nameEn: json['name_en'] as String,
      nameTr: json['name_tr'] as String,
      nameAr: json['name_ar'] as String,
      flagEmoji: json['flag_emoji'] as String? ?? '',
      isPopular: json['is_popular'] as bool? ?? false,
    );
  }
}

class Region {
  const Region({
    required this.id,
    required this.slug,
    required this.nameEn,
    required this.nameTr,
    required this.nameAr,
    required this.isPopular,
  });

  final String id;
  final String slug;
  final String nameEn;
  final String nameTr;
  final String nameAr;
  final bool isPopular;

  String localizedName(String locale) {
    switch (locale) {
      case 'tr':
        return nameTr;
      case 'ar':
        return nameAr;
      default:
        return nameEn;
    }
  }

  factory Region.fromJson(Map<String, dynamic> json) {
    return Region(
      id: json['id'] as String,
      slug: json['slug'] as String,
      nameEn: json['name_en'] as String,
      nameTr: json['name_tr'] as String,
      nameAr: json['name_ar'] as String,
      isPopular: json['is_popular'] as bool? ?? false,
    );
  }
}

class PlanPrice {
  const PlanPrice({required this.currency, required this.amount});

  final String currency;
  final double amount;

  factory PlanPrice.fromJson(Map<String, dynamic> json) {
    return PlanPrice(
      currency: json['currency'] as String,
      amount: (json['amount'] as num).toDouble(),
    );
  }
}

class MarketplacePlan {
  const MarketplacePlan({
    required this.id,
    this.countryId,
    this.regionId,
    required this.nameEn,
    required this.nameTr,
    required this.nameAr,
    required this.dataAmountMb,
    required this.validityDays,
    required this.isFeatured,
    required this.prices,
    this.countryNameEn,
    this.countryNameTr,
    this.countryNameAr,
    this.flagEmoji,
    this.regionNameEn,
  });

  final String id;
  final String? countryId;
  final String? regionId;
  final String nameEn;
  final String nameTr;
  final String nameAr;
  final int dataAmountMb;
  final int validityDays;
  final bool isFeatured;
  final List<PlanPrice> prices;
  final String? countryNameEn;
  final String? countryNameTr;
  final String? countryNameAr;
  final String? flagEmoji;
  final String? regionNameEn;

  String localizedName(String locale) {
    switch (locale) {
      case 'tr':
        return nameTr;
      case 'ar':
        return nameAr;
      default:
        return nameEn;
    }
  }

  String destination(String locale) {
    if (countryNameEn != null) {
      switch (locale) {
        case 'tr':
          return countryNameTr ?? countryNameEn!;
        case 'ar':
          return countryNameAr ?? countryNameEn!;
        default:
          return countryNameEn!;
      }
    }
    return regionNameEn ?? nameEn;
  }

  double? priceFor(String currency) {
    for (final price in prices) {
      if (price.currency == currency) return price.amount;
    }
    if (prices.isEmpty) return null;
    return prices.first.amount;
  }

  String get dataLabel {
    final gb = dataAmountMb / 1024;
    if (gb >= 1) return '${gb.toStringAsFixed(gb.truncateToDouble() == gb ? 0 : 1)} GB';
    return '$dataAmountMb MB';
  }

  factory MarketplacePlan.fromJson(Map<String, dynamic> json) {
    final rawPrices = json['prices'];
    return MarketplacePlan(
      id: json['id'] as String,
      countryId: json['country_id'] as String?,
      regionId: json['region_id'] as String?,
      nameEn: json['name_en'] as String,
      nameTr: json['name_tr'] as String,
      nameAr: json['name_ar'] as String,
      dataAmountMb: (json['data_amount_mb'] as num).toInt(),
      validityDays: (json['validity_days'] as num).toInt(),
      isFeatured: json['is_featured'] as bool? ?? false,
      prices: rawPrices is List
          ? rawPrices
              .whereType<Map>()
              .map((e) => PlanPrice.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      countryNameEn: json['country_name_en'] as String?,
      countryNameTr: json['country_name_tr'] as String?,
      countryNameAr: json['country_name_ar'] as String?,
      flagEmoji: json['flag_emoji'] as String?,
      regionNameEn: json['region_name_en'] as String?,
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.locale,
    required this.preferredCurrency,
    this.phone,
    required this.appRole,
  });

  final String id;
  final String email;
  final String fullName;
  final String locale;
  final String preferredCurrency;
  final String? phone;
  final String appRole;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String? ?? '',
      locale: json['locale'] as String? ?? 'en',
      preferredCurrency: json['preferred_currency'] as String? ?? 'USD',
      phone: json['phone'] as String?,
      appRole: json['app_role'] as String? ?? 'customer',
    );
  }
}

class UserEsim {
  const UserEsim({
    required this.id,
    required this.orderId,
    required this.status,
    required this.originalBalance,
    required this.remainingBalance,
    required this.balanceUnit,
    required this.isMock,
    required this.planNameEn,
    required this.planNameTr,
    required this.planNameAr,
    required this.destinationEn,
    required this.destinationTr,
    required this.destinationAr,
    required this.dataAmountMb,
    required this.validityDays,
    this.flagEmoji,
    this.activatedAt,
    this.expiresAt,
    this.iccid,
    this.smdpAddress,
    this.activationCode,
    this.confirmationCode,
  });

  final String id;
  final String orderId;
  final String status;
  final double originalBalance;
  final double remainingBalance;
  final String balanceUnit;
  final bool isMock;
  final String planNameEn;
  final String planNameTr;
  final String planNameAr;
  final String destinationEn;
  final String destinationTr;
  final String destinationAr;
  final int dataAmountMb;
  final int validityDays;
  final String? flagEmoji;
  final DateTime? activatedAt;
  final DateTime? expiresAt;
  final String? iccid;
  final String? smdpAddress;
  final String? activationCode;
  final String? confirmationCode;

  String destination(String locale) {
    switch (locale) {
      case 'tr':
        return destinationTr;
      case 'ar':
        return destinationAr;
      default:
        return destinationEn;
    }
  }

  String planName(String locale) {
    switch (locale) {
      case 'tr':
        return planNameTr;
      case 'ar':
        return planNameAr;
      default:
        return planNameEn;
    }
  }

  String remainingLabel() {
    final gb = remainingBalance / 1024;
    if (gb >= 1) return '${gb.toStringAsFixed(2)} GB';
    return '${remainingBalance.toStringAsFixed(0)} MB';
  }

  bool get hasInstallPayload =>
      (activationCode != null && activationCode!.isNotEmpty) ||
      (smdpAddress != null && smdpAddress!.isNotEmpty);

  factory UserEsim.fromJson(Map<String, dynamic> json) {
    return UserEsim(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      status: json['status'] as String,
      originalBalance: (json['original_balance'] as num).toDouble(),
      remainingBalance: (json['remaining_balance'] as num).toDouble(),
      balanceUnit: json['balance_unit'] as String? ?? 'MB',
      isMock: json['is_mock'] as bool? ?? true,
      planNameEn: json['plan_name_en'] as String? ?? '',
      planNameTr: json['plan_name_tr'] as String? ?? '',
      planNameAr: json['plan_name_ar'] as String? ?? '',
      destinationEn: json['destination_en'] as String? ?? '',
      destinationTr: json['destination_tr'] as String? ?? '',
      destinationAr: json['destination_ar'] as String? ?? '',
      dataAmountMb: (json['data_amount_mb'] as num?)?.toInt() ?? 0,
      validityDays: (json['validity_days'] as num?)?.toInt() ?? 0,
      flagEmoji: json['flag_emoji'] as String?,
      activatedAt: json['activated_at'] != null ? DateTime.tryParse(json['activated_at'] as String) : null,
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'] as String) : null,
      iccid: json['iccid'] as String?,
      smdpAddress: json['smdp_address'] as String?,
      activationCode: json['activation_code'] as String?,
      confirmationCode: json['confirmation_code'] as String?,
    );
  }
}

class Order {
  const Order({
    required this.id,
    required this.status,
    required this.currency,
    required this.total,
    required this.subtotal,
    required this.tax,
    required this.fees,
    required this.createdAt,
    required this.planNameEn,
    required this.dataAmountMb,
    required this.validityDays,
    this.destinationEn,
    this.flagEmoji,
    this.esimId,
    this.esimStatus,
    this.paymentStatus,
  });

  final String id;
  final String status;
  final String currency;
  final double total;
  final double subtotal;
  final double tax;
  final double fees;
  final DateTime createdAt;
  final String planNameEn;
  final int dataAmountMb;
  final int validityDays;
  final String? destinationEn;
  final String? flagEmoji;
  final String? esimId;
  final String? esimStatus;
  final String? paymentStatus;

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      status: json['status'] as String,
      currency: json['currency'] as String,
      total: (json['total'] as num).toDouble(),
      subtotal: (json['subtotal'] as num).toDouble(),
      tax: (json['tax'] as num?)?.toDouble() ?? 0,
      fees: (json['fees'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      planNameEn: json['plan_name_en'] as String? ?? '',
      dataAmountMb: (json['data_amount_mb'] as num?)?.toInt() ?? 0,
      validityDays: (json['validity_days'] as num?)?.toInt() ?? 0,
      destinationEn: json['destination_en'] as String?,
      flagEmoji: json['flag_emoji'] as String?,
      esimId: json['esim_id'] as String?,
      esimStatus: json['esim_status'] as String?,
      paymentStatus: json['payment_status'] as String?,
    );
  }
}

class CheckoutQuote {
  const CheckoutQuote({
    required this.orderId,
    required this.planId,
    required this.destination,
    required this.planName,
    required this.dataAmountMb,
    required this.validityDays,
    required this.currency,
    required this.subtotal,
    required this.tax,
    required this.fees,
    required this.total,
    required this.paymentMode,
  });

  final String orderId;
  final String planId;
  final String destination;
  final String planName;
  final int dataAmountMb;
  final int validityDays;
  final String currency;
  final double subtotal;
  final double tax;
  final double fees;
  final double total;
  final String paymentMode;

  bool get isMock => paymentMode == 'mock';

  factory CheckoutQuote.fromJson(Map<String, dynamic> json) {
    return CheckoutQuote(
      orderId: json['order_id'] as String,
      planId: json['plan_id'] as String,
      destination: json['destination'] as String? ?? '',
      planName: json['plan_name'] as String? ?? '',
      dataAmountMb: (json['data_amount_mb'] as num).toInt(),
      validityDays: (json['validity_days'] as num).toInt(),
      currency: json['currency'] as String,
      subtotal: (json['subtotal'] as num).toDouble(),
      tax: (json['tax'] as num).toDouble(),
      fees: (json['fees'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
      paymentMode: json['payment_mode'] as String? ?? 'mock',
    );
  }
}

class PurchaseResult {
  const PurchaseResult({
    required this.orderId,
    required this.orderStatus,
    required this.paymentStatus,
    required this.isMockProvisioning,
    required this.message,
    this.esimId,
    this.esimStatus,
  });

  final String orderId;
  final String orderStatus;
  final String paymentStatus;
  final bool isMockProvisioning;
  final String message;
  final String? esimId;
  final String? esimStatus;

  factory PurchaseResult.fromJson(Map<String, dynamic> json) {
    return PurchaseResult(
      orderId: json['order_id'] as String,
      orderStatus: json['order_status'] as String,
      paymentStatus: json['payment_status'] as String? ?? '',
      isMockProvisioning: json['is_mock_provisioning'] as bool? ?? true,
      message: json['message'] as String? ?? '',
      esimId: json['esim_id'] as String?,
      esimStatus: json['esim_status'] as String?,
    );
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.titleEn,
    required this.titleTr,
    required this.titleAr,
    required this.bodyEn,
    required this.bodyTr,
    required this.bodyAr,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String titleEn;
  final String titleTr;
  final String titleAr;
  final String bodyEn;
  final String bodyTr;
  final String bodyAr;
  final bool isRead;
  final DateTime createdAt;

  String title(String locale) {
    switch (locale) {
      case 'tr':
        return titleTr;
      case 'ar':
        return titleAr;
      default:
        return titleEn;
    }
  }

  String body(String locale) {
    switch (locale) {
      case 'tr':
        return bodyTr;
      case 'ar':
        return bodyAr;
      default:
        return bodyEn;
    }
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: json['type'] as String,
      titleEn: json['title_en'] as String,
      titleTr: json['title_tr'] as String,
      titleAr: json['title_ar'] as String,
      bodyEn: json['body_en'] as String,
      bodyTr: json['body_tr'] as String,
      bodyAr: json['body_ar'] as String,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class EsimUsage {
  const EsimUsage({
    required this.id,
    required this.usageAmount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.source,
    required this.createdAt,
  });

  final String id;
  final double usageAmount;
  final double balanceBefore;
  final double balanceAfter;
  final String source;
  final DateTime createdAt;

  factory EsimUsage.fromJson(Map<String, dynamic> json) {
    return EsimUsage(
      id: json['id'] as String,
      usageAmount: (json['usage_amount'] as num).toDouble(),
      balanceBefore: (json['balance_before'] as num).toDouble(),
      balanceAfter: (json['balance_after'] as num).toDouble(),
      source: json['source'] as String,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
