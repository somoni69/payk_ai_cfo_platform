import 'package:flutter/material.dart';

import '../domain/transaction_model.dart';

/// Логотип банка по названию из справочника. Те же правила, что на вебе.
enum BankLogoKey { alif, dc, eskhata }

const _logoAssets = <BankLogoKey, String>{
  BankLogoKey.alif: 'assets/banks/alif.png',
  BankLogoKey.dc: 'assets/banks/dc.png',
  BankLogoKey.eskhata: 'assets/banks/eskhata.png',
};

final _logoTests = <BankLogoKey, RegExp>{
  BankLogoKey.alif: RegExp(r'alif|алиф', caseSensitive: false),
  BankLogoKey.dc: RegExp(
    r'(^|\b)dc(\b|$)|dushanbe|душанбе',
    caseSensitive: false,
  ),
  BankLogoKey.eskhata: RegExp(r'es[kx]hata|[эе]схата', caseSensitive: false),
};

BankLogoKey? bankLogoKeyForName(String? name) {
  if (name == null || name.trim().isEmpty) return null;
  for (final entry in _logoTests.entries) {
    if (entry.value.hasMatch(name)) return entry.key;
  }
  return null;
}

BankLogoKey? paymentLogoKey(PaymentMethod method, {String? bankName}) {
  return switch (method) {
    PaymentMethod.alif => BankLogoKey.alif,
    PaymentMethod.dushanbeCity => BankLogoKey.dc,
    PaymentMethod.card || PaymentMethod.mixed => bankLogoKeyForName(bankName),
    _ => bankLogoKeyForName(bankName),
  };
}

class BankLogo extends StatelessWidget {
  const BankLogo({super.key, required this.logo, this.height = 22});

  final BankLogoKey logo;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _logoAssets[logo]!,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}

/// Название банка с логотипом, если он есть в справочнике.
class BankNameLabel extends StatelessWidget {
  const BankNameLabel({
    super.key,
    required this.name,
    this.style,
    this.height = 18,
  });

  final String name;
  final TextStyle? style;
  final double height;

  @override
  Widget build(BuildContext context) {
    final logo = bankLogoKeyForName(name);
    final text = Text(name, style: style, overflow: TextOverflow.ellipsis);
    if (logo == null) return text;
    return Row(
      children: [
        BankLogo(logo: logo, height: height),
        const SizedBox(width: 8),
        Flexible(child: text),
      ],
    );
  }
}

/// Чип Alif / DC: логотип вместо надписи. Название остаётся в семантике.
Widget paymentChipLabel(String label, PaymentMethod method) {
  final logo = switch (method) {
    PaymentMethod.alif || PaymentMethod.dushanbeCity => paymentLogoKey(method),
    _ => null,
  };
  if (logo == null) return Text(label);
  return Semantics(
    label: label,
    child: BankLogo(logo: logo, height: 22),
  );
}

/// Логотип пункта списка способов оплаты. У карты и смешанной его нет,
/// пока рядом не указан банк.
Widget? paymentMethodLeading(String token) {
  PaymentMethod? method;
  for (final candidate in PaymentMethod.values) {
    if (candidate.name == token || candidate.apiValue == token) {
      method = candidate;
      break;
    }
  }
  if (method == null) return null;
  final logo = switch (method) {
    PaymentMethod.alif || PaymentMethod.dushanbeCity => paymentLogoKey(method),
    _ => null,
  };
  if (logo == null) return null;
  return BankLogo(logo: logo, height: 16);
}
