int _level(dynamic value) {
  final level = jsonInt(value);
  if (level < 1) return 1;
  if (level > 5) return 5;
  return level;
}

double jsonNum(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}'.replaceAll(',', '.')) ?? 0;
}

int jsonInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}

Map<String, dynamic> jsonMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

class LoyaltyProgram {
  const LoyaltyProgram({
    required this.id,
    required this.title,
    required this.slug,
    required this.enabled,
  });

  final int id;
  final String title;
  final String slug;
  final bool enabled;

  factory LoyaltyProgram.fromJson(Map<String, dynamic> json) {
    return LoyaltyProgram(
      id: jsonInt(json['id']),
      title: '${json['title'] ?? ''}',
      slug: '${json['slug'] ?? ''}',
      enabled: json['enabled'] == true,
    );
  }
}

class LoyaltyTerminal {
  const LoyaltyTerminal({
    required this.id,
    required this.name,
    required this.formatCode,
    required this.isActive,
    required this.coinEnabled,
    this.onecRegister,
  });

  final int id;
  final String name;
  final String formatCode;
  final bool isActive;
  final bool coinEnabled;
  final String? onecRegister;

  factory LoyaltyTerminal.fromJson(Map<String, dynamic> json) {
    return LoyaltyTerminal(
      id: jsonInt(json['id']),
      name: '${json['name'] ?? ''}',
      formatCode: '${json['format_code'] ?? 'SM'}',
      isActive: json['is_active'] != false,
      coinEnabled: json['coin_enabled'] == true,
      onecRegister: json['onec_register']?.toString(),
    );
  }
}

class LoyaltyProgramState {
  const LoyaltyProgramState({
    required this.program,
    required this.config,
    required this.terminals,
    required this.members,
    required this.appLink,
  });

  final LoyaltyProgram? program;
  final Map<String, dynamic> config;
  final List<LoyaltyTerminal> terminals;
  final int members;
  final String? appLink;

  factory LoyaltyProgramState.fromJson(Map<String, dynamic> json) {
    final rawTerminals = json['terminals'];
    return LoyaltyProgramState(
      program: json['program'] is Map
          ? LoyaltyProgram.fromJson(jsonMap(json['program']))
          : null,
      config: jsonMap(json['config']),
      terminals: rawTerminals is List
          ? [
              for (final item in rawTerminals)
                if (item is Map)
                  LoyaltyTerminal.fromJson(Map<String, dynamic>.from(item)),
            ]
          : const [],
      members: jsonInt(json['members']),
      appLink: json['app_link']?.toString(),
    );
  }
}

class LoyaltyMember {
  const LoyaltyMember({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.status,
    required this.balance,
    required this.debt,
    required this.spendMonth,
    required this.isStaff,
    required this.segment,
    required this.isRegular,
    required this.wholesaleFlag,
    required this.messages,
    this.birthDate,
    this.country,
  });

  final int id;
  final String firstName;
  final String lastName;
  final String phone;
  final int status;
  final double balance;
  final double debt;
  final double spendMonth;
  final bool isStaff;
  final String? segment;
  final bool isRegular;
  final String? wholesaleFlag;
  final bool messages;
  final String? birthDate;
  final String? country;

  String get name => '$firstName $lastName'.trim();

  factory LoyaltyMember.fromJson(Map<String, dynamic> json) {
    return LoyaltyMember(
      id: jsonInt(json['id']),
      firstName: '${json['first_name'] ?? ''}',
      lastName: '${json['last_name'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      status: _level(json['status']),
      balance: jsonNum(json['balance']),
      debt: jsonNum(json['debt']),
      spendMonth: jsonNum(json['spend_month']),
      isStaff: json['is_staff'] == true,
      segment: json['segment']?.toString(),
      isRegular: json['is_regular'] == true,
      wholesaleFlag: json['wholesale_flag']?.toString(),
      messages: json['messages'] == true,
      birthDate: json['birth_date']?.toString(),
      country: json['country']?.toString(),
    );
  }
}

class LoyaltyMembersPage {
  const LoyaltyMembersPage({
    required this.items,
    required this.total,
    required this.byStatus,
  });

  final List<LoyaltyMember> items;
  final int total;
  final Map<String, int> byStatus;

  factory LoyaltyMembersPage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final counts = jsonMap(json['by_status']);
    return LoyaltyMembersPage(
      items: raw is List
          ? [
              for (final item in raw)
                if (item is Map)
                  LoyaltyMember.fromJson(Map<String, dynamic>.from(item)),
            ]
          : const [],
      total: jsonInt(json['total']),
      byStatus: {
        for (final entry in counts.entries) entry.key: jsonInt(entry.value),
      },
    );
  }
}

class LoyaltyBillBrief {
  const LoyaltyBillBrief({
    required this.extId,
    required this.amount,
    required this.mode,
    required this.format,
    required this.state,
    required this.ts,
    required this.earn,
    required this.burn,
  });

  final String extId;
  final double amount;
  final String mode;
  final String format;
  final String state;
  final String ts;
  final double earn;
  final double burn;

  factory LoyaltyBillBrief.fromJson(Map<String, dynamic> json) {
    return LoyaltyBillBrief(
      extId: '${json['ext_id'] ?? ''}',
      amount: jsonNum(json['amount']),
      mode: '${json['mode'] ?? 'earn'}',
      format: '${json['format'] ?? ''}',
      state: '${json['state'] ?? ''}',
      ts: '${json['ts'] ?? ''}',
      earn: jsonNum(json['earn']),
      burn: jsonNum(json['burn']),
    );
  }
}

class LoyaltyMemberCard {
  const LoyaltyMemberCard({required this.member, required this.bills});

  final LoyaltyMember member;
  final List<LoyaltyBillBrief> bills;

  factory LoyaltyMemberCard.fromJson(Map<String, dynamic> json) {
    final raw = json['bills'];
    return LoyaltyMemberCard(
      member: LoyaltyMember.fromJson(json),
      bills: raw is List
          ? [
              for (final item in raw)
                if (item is Map)
                  LoyaltyBillBrief.fromJson(Map<String, dynamic>.from(item)),
            ]
          : const [],
    );
  }
}

class LoyaltyCoupon {
  const LoyaltyCoupon({
    required this.applied,
    required this.amount,
    required this.offer,
    required this.usable,
  });

  final bool applied;
  final double amount;
  final double offer;
  final bool usable;

  factory LoyaltyCoupon.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const LoyaltyCoupon(
        applied: false,
        amount: 0,
        offer: 0,
        usable: false,
      );
    }
    return LoyaltyCoupon(
      applied: json['applied'] == true,
      amount: jsonNum(json['amount']),
      offer: jsonNum(json['offer']),
      usable: json['usable'] == true,
    );
  }
}

class LoyaltyPreview {
  const LoyaltyPreview({
    required this.id,
    required this.state,
    required this.format,
    required this.amount,
    required this.mode,
    required this.earn,
    required this.burn,
    required this.cashToPay,
    required this.payk,
    required this.coin,
    required this.clientConfirmed,
    required this.coupon,
    required this.coinSuggested,
    required this.expiresAt,
    required this.why,
  });

  final int id;
  final String state;
  final String format;
  final double? amount;
  final String? mode;
  final double earn;
  final double burn;
  final double cashToPay;
  final double payk;
  final double coin;
  final bool clientConfirmed;
  final LoyaltyCoupon coupon;
  final bool coinSuggested;
  final String? expiresAt;
  final String? why;

  bool get priced => state == 'pending' && amount != null;

  factory LoyaltyPreview.fromJson(Map<String, dynamic> json) {
    return LoyaltyPreview(
      id: jsonInt(json['id']),
      state: '${json['state'] ?? 'draft'}',
      format: '${json['format'] ?? ''}',
      amount: json['amount'] == null ? null : jsonNum(json['amount']),
      mode: json['mode']?.toString(),
      earn: jsonNum(json['x']),
      burn: jsonNum(json['v'] ?? json['burn_amount']),
      cashToPay: jsonNum(json['cash_to_pay'] ?? json['to_pay']),
      payk: jsonNum(json['b']),
      coin: jsonNum(json['r']),
      clientConfirmed: json['client_confirmed'] == true,
      coupon: LoyaltyCoupon.fromJson(
        json['coupon'] is Map ? jsonMap(json['coupon']) : null,
      ),
      coinSuggested: json['coin_suggested'] == true,
      expiresAt: json['expires_at']?.toString(),
      why: json['why']?.toString(),
    );
  }
}

class LoyaltyPosState {
  const LoyaltyPosState({required this.preview, required this.member});

  final LoyaltyPreview preview;
  final LoyaltyMember member;

  factory LoyaltyPosState.fromJson(Map<String, dynamic> json) {
    return LoyaltyPosState(
      preview: LoyaltyPreview.fromJson(jsonMap(json['preview'])),
      member: LoyaltyMember.fromJson(jsonMap(json['member'])),
    );
  }
}

class LoyaltyBillRow {
  const LoyaltyBillRow({
    required this.extId,
    required this.member,
    required this.phone,
    required this.amount,
    required this.mode,
    required this.state,
    required this.ts,
    required this.format,
  });

  final String extId;
  final String member;
  final String phone;
  final double amount;
  final String mode;
  final String state;
  final String ts;
  final String format;

  factory LoyaltyBillRow.fromJson(Map<String, dynamic> json) {
    return LoyaltyBillRow(
      extId: '${json['ext_id'] ?? ''}',
      member: '${json['member'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      amount: jsonNum(json['amount']),
      mode: '${json['mode'] ?? ''}',
      state: '${json['state'] ?? ''}',
      ts: '${json['ts'] ?? ''}',
      format: '${json['format'] ?? ''}',
    );
  }
}

class LoyaltyBirthday {
  const LoyaltyBirthday({
    required this.memberId,
    required this.name,
    required this.phone,
    required this.dayMonth,
    required this.daysUntil,
    required this.status,
    required this.segment,
    required this.couponState,
    required this.couponAmount,
  });

  final int memberId;
  final String name;
  final String phone;
  final String dayMonth;
  final int daysUntil;
  final int status;
  final String? segment;
  final String couponState;
  final double couponAmount;

  factory LoyaltyBirthday.fromJson(Map<String, dynamic> json) {
    final coupon = jsonMap(json['coupon']);
    return LoyaltyBirthday(
      memberId: jsonInt(json['member_id']),
      name: '${json['name'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      dayMonth: '${json['day_month'] ?? json['birthday'] ?? ''}',
      daysUntil: jsonInt(json['days_until']),
      status: _level(json['status']),
      segment: json['segment']?.toString(),
      couponState: '${coupon['state'] ?? 'none'}',
      couponAmount: jsonNum(coupon['amount']),
    );
  }
}

class LoyaltyMessageRow {
  const LoyaltyMessageRow({
    required this.id,
    required this.kind,
    required this.state,
    required this.channel,
    required this.text,
    required this.memberName,
    required this.createdAt,
  });

  final int id;
  final String kind;
  final String state;
  final String channel;
  final String text;
  final String memberName;
  final String createdAt;

  factory LoyaltyMessageRow.fromJson(Map<String, dynamic> json) {
    final member = jsonMap(json['member']);
    return LoyaltyMessageRow(
      id: jsonInt(json['id']),
      kind: '${json['kind'] ?? ''}',
      state: '${json['state'] ?? ''}',
      channel: '${json['channel'] ?? ''}',
      text: '${json['text'] ?? ''}',
      memberName: '${member['name'] ?? ''}',
      createdAt: '${json['created_at'] ?? ''}',
    );
  }
}

class LoyaltyMessageSummary {
  const LoyaltyMessageSummary({
    required this.fcm,
    required this.telegram,
    required this.sms,
    required this.app,
    required this.failed,
    required this.smsUsed,
    required this.smsLimit,
    required this.subscribed,
  });

  final int fcm;
  final int telegram;
  final int sms;
  final int app;
  final int failed;
  final int smsUsed;
  final int smsLimit;
  final int subscribed;

  factory LoyaltyMessageSummary.fromJson(Map<String, dynamic> json) {
    final counts = jsonMap(json['counts']);
    return LoyaltyMessageSummary(
      fcm: jsonInt(counts['fcm']),
      telegram: jsonInt(counts['telegram']),
      sms: jsonInt(counts['sms']),
      app: jsonInt(counts['app']),
      failed: jsonInt(counts['failed']),
      smsUsed: jsonInt(json['sms_used']),
      smsLimit: jsonInt(json['sms_limit']),
      subscribed: jsonInt(json['subscribed']),
    );
  }
}

class LoyaltyDashboard {
  const LoyaltyDashboard({
    required this.membersTotal,
    required this.membersNew,
    required this.billsCount,
    required this.billsAmount,
    required this.billsAverage,
    required this.accrued,
    required this.burned,
    required this.balance,
    required this.debt,
    required this.byStatus,
    required this.segments,
    required this.couponUsed,
    required this.dobBonus,
  });

  final int membersTotal;
  final int membersNew;
  final int billsCount;
  final double billsAmount;
  final double billsAverage;
  final double accrued;
  final double burned;
  final double balance;
  final double debt;
  final Map<String, int> byStatus;

  /// Код сегмента → число клиентов за 30 дней.
  final Map<String, int> segments;
  final double couponUsed;
  final double dobBonus;

  factory LoyaltyDashboard.fromJson(Map<String, dynamic> json) {
    final members = jsonMap(json['members']);
    final bills = jsonMap(json['bills']);
    final cashback = jsonMap(json['cashback']);
    final liability = jsonMap(json['liability']);
    final gifts = jsonMap(json['gifts']);
    final coupons = jsonMap(gifts['coupons']);
    final dob = jsonMap(gifts['dob_bonus']);
    final segments = jsonMap(json['segments']);
    final window = jsonMap(segments['30']);
    final matrix = jsonMap(window['matrix']);
    final cells = <String, int>{};
    for (final entry in matrix.entries) {
      cells[entry.key] = jsonInt(jsonMap(entry.value)['members']);
    }
    final byStatus = <String, int>{};
    for (final entry in jsonMap(members['by_status']).entries) {
      byStatus[entry.key] = jsonInt(entry.value);
    }
    return LoyaltyDashboard(
      membersTotal: jsonInt(members['total']),
      membersNew: jsonInt(members['new']),
      billsCount: jsonInt(bills['count']),
      billsAmount: jsonNum(bills['amount']),
      billsAverage: jsonNum(bills['average']),
      accrued: jsonNum(cashback['accrued']),
      burned: jsonNum(cashback['burned']),
      balance: jsonNum(liability['balance']),
      debt: jsonNum(liability['debt']),
      byStatus: byStatus,
      segments: cells,
      couponUsed: jsonNum(coupons['used_amount']),
      dobBonus: jsonNum(dob['amount']),
    );
  }
}

class IdentifiedSlice {
  const IdentifiedSlice({
    required this.name,
    required this.bills,
    required this.shareAmount,
    required this.shareCount,
  });

  final String name;
  final int bills;
  final double? shareAmount;
  final double? shareCount;

  factory IdentifiedSlice.fromJson(Map<String, dynamic> json, String name) {
    return IdentifiedSlice(
      name: name,
      bills: jsonInt(json['bills']),
      shareAmount: json['share_amount'] == null
          ? null
          : jsonNum(json['share_amount']),
      shareCount: json['share_count'] == null
          ? null
          : jsonNum(json['share_count']),
    );
  }
}

class BroadcastPreview {
  const BroadcastPreview({
    required this.recipients,
    required this.skipped,
    required this.smsLeft,
  });

  final int recipients;
  final int skipped;
  final int smsLeft;

  factory BroadcastPreview.fromJson(Map<String, dynamic> json) {
    return BroadcastPreview(
      recipients: jsonInt(json['recipients']),
      skipped: jsonInt(json['skipped_no_consent']),
      smsLeft: jsonInt(json['sms_left']),
    );
  }
}

class MemberQuery {
  const MemberQuery({
    this.q,
    this.status,
    this.segment,
    this.window = 30,
    this.regular,
    this.format,
    this.wholesale,
    this.page = 1,
  });

  final String? q;
  final int? status;
  final String? segment;
  final int window;
  final bool? regular;
  final String? format;
  final String? wholesale;
  final int page;

  Map<String, String> filters({bool withWindow = true}) {
    final out = <String, String>{};
    final text = q?.trim() ?? '';
    if (text.isNotEmpty) out['q'] = text;
    if (status != null) out['status_level'] = '$status';
    if (segment != null && segment!.isNotEmpty) out['segment'] = segment!;
    if (withWindow || segment != null || regular != null || format != null) {
      out['window'] = '$window';
    }
    if (regular != null) out['regular'] = regular! ? 'true' : 'false';
    if (format != null && format!.isNotEmpty) out['fmt'] = format!;
    if (wholesale != null && wholesale!.isNotEmpty) {
      out['wholesale'] = wholesale!;
    }
    return out;
  }
}
