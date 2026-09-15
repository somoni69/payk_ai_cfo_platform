import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/localization/locale_number_format.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';
import '../domain/finance_model.dart';
import '../domain/finance_repository.dart';

/// Доска курсов валют: Официальный курс НБТ + сравнительная таблица банков.
class CurrencyBoardCard extends StatefulWidget {
  const CurrencyBoardCard({super.key});

  @override
  State<CurrencyBoardCard> createState() => _CurrencyBoardCardState();
}

class _CurrencyBoardCardState extends State<CurrencyBoardCard> {
  static const _codes = ['USD', 'EUR', 'RUB'];
  static const _switchDuration = Duration(milliseconds: 420);
  static const _switchCurve = Curves.easeOutCubic;
  String _selectedCurrency = 'USD';

  /// 1 — к следующей валюте (вправо), −1 — к предыдущей.
  var _slideDir = 1;
  CurrencyBoard? _board;
  var _loading = true;
  var _failed = false;
  Timer? _poll;

  void _selectCurrency(String code) {
    if (code == _selectedCurrency) return;
    final from = _codes.indexOf(_selectedCurrency);
    final to = _codes.indexOf(code);
    HapticFeedback.selectionClick();
    setState(() {
      _slideDir = to >= from ? 1 : -1;
      _selectedCurrency = code;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(minutes: 30), (_) {
      if (!mounted) return;
      _load();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  bool get _refreshing => _loading && _board != null;

  Widget _shimmerWhenRefreshing(Widget child) {
    if (!_refreshing) return child;
    return LedgerShimmer(child: child);
  }

  Future<void> _load() async {
    if (_board != null) {
      setState(() => _loading = true);
    }
    try {
      final board = await context.read<FinanceRepository>().getCurrencyBoard();
      if (!mounted) return;
      setState(() {
        _board = board;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_board == null) _failed = true;
      });
    }
  }

  String _getCurrencyFlag(String code) {
    switch (code.toUpperCase()) {
      case 'USD':
        return '🇺🇸';
      case 'EUR':
        return '🇪🇺';
      case 'RUB':
        return '🇷🇺';
      default:
        return '🌐';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();

    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final official = {
      for (final r in _board?.official ?? const <RateRow>[]) r.code: r,
    };
    final byBank = <String, Map<String, BankRateQuote>>{};
    final names = <String, String>{};
    DateTime? freshest;

    for (final row in _board?.banks ?? const <BankRateQuote>[]) {
      names[row.bank] = row.bankName;
      byBank.putIfAbsent(row.bank, () => {})[row.currency] = row;
      if (row.fetchedAt != null &&
          (freshest == null || row.fetchedAt!.isAfter(freshest))) {
        freshest = row.fetchedAt;
      }
    }

    // Find best rates for the selected currency
    double? maxBuy;
    double? minSell;
    for (final bankQuotes in byBank.values) {
      final quote = bankQuotes[_selectedCurrency];
      if (quote != null) {
        if (quote.buy != null && (maxBuy == null || quote.buy! > maxBuy)) {
          maxBuy = quote.buy;
        }
        if (quote.sell != null && (minSell == null || quote.sell! < minSell)) {
          minSell = quote.sell;
        }
      }
    }

    int decimalsForCode(String code) => code.toUpperCase() == 'RUB' ? 4 : 2;

    String fmt(double? v, {String? code, int? minDecimals, int? maxDecimals}) {
      if (v == null) return '—';
      final decimals = code != null
          ? decimalsForCode(code)
          : (minDecimals ?? 2);
      return formatLocalizedNumber(
        context,
        v,
        minimumFractionDigits: minDecimals ?? decimals,
        maximumFractionDigits: maxDecimals ?? decimals,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Заголовок виджета
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colors.brand.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                TablerIcons.building_bank,
                size: 18,
                color: colors.brand,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    language.translate('dashboard_rates_title'),
                    style: textStyles.h2Sans.copyWith(
                      fontSize: context.fontSize(16),
                    ),
                  ),
                  if (freshest != null) ...[
                    const SizedBox(height: 1),
                    _shimmerWhenRefreshing(
                      Text(
                        language.translate(
                          'dashboard_rates_updated',
                          params: {
                            'time': formatLocalizedDateTime(
                              context,
                              freshest,
                              style: LocalizedDateTimeStyle.dateTime,
                            ),
                          },
                        ),
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                          fontSize: context.fontSize(11),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: language.translate('dashboard_rates_refresh'),
              onPressed: _loading ? null : _load,
              splashRadius: 18,
              icon: _loading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.brand,
                      ),
                    )
                  : Icon(
                      TablerIcons.refresh,
                      size: 18,
                      color: colors.textSecondary,
                    ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Shimmer состояние
        if (_loading && _board == null)
          LedgerShimmer(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colors.surfaceNested,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.border),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          child: Column(
                            children: [
                              ShimmerBox(
                                width: 36,
                                height: 12,
                                borderRadius: 4,
                              ),
                              SizedBox(height: 6),
                              ShimmerBox(
                                width: 64,
                                height: 18,
                                borderRadius: 4,
                              ),
                              SizedBox(height: 4),
                              ShimmerBox(
                                width: 48,
                                height: 10,
                                borderRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          child: Column(
                            children: [
                              ShimmerBox(
                                width: 36,
                                height: 12,
                                borderRadius: 4,
                              ),
                              SizedBox(height: 6),
                              ShimmerBox(
                                width: 64,
                                height: 18,
                                borderRadius: 4,
                              ),
                              SizedBox(height: 4),
                              ShimmerBox(
                                width: 48,
                                height: 10,
                                borderRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          child: Column(
                            children: [
                              ShimmerBox(
                                width: 36,
                                height: 12,
                                borderRadius: 4,
                              ),
                              SizedBox(height: 6),
                              ShimmerBox(
                                width: 64,
                                height: 18,
                                borderRadius: 4,
                              ),
                              SizedBox(height: 4),
                              ShimmerBox(
                                width: 48,
                                height: 10,
                                borderRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    ShimmerBox(width: 110, height: 13, borderRadius: 4),
                    Spacer(),
                    ShimmerBox(width: 90, height: 11, borderRadius: 4),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: const Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: ShimmerBox(height: 14, borderRadius: 4),
                            ),
                            SizedBox(width: 12),
                            ShimmerBox(width: 64, height: 14, borderRadius: 4),
                            SizedBox(width: 12),
                            ShimmerBox(width: 64, height: 14, borderRadius: 4),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: ShimmerBox(height: 14, borderRadius: 4),
                            ),
                            SizedBox(width: 12),
                            ShimmerBox(width: 64, height: 14, borderRadius: 4),
                            SizedBox(width: 12),
                            ShimmerBox(width: 64, height: 14, borderRadius: 4),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: ShimmerBox(height: 14, borderRadius: 4),
                            ),
                            SizedBox(width: 12),
                            ShimmerBox(width: 64, height: 14, borderRadius: 4),
                            SizedBox(width: 12),
                            ShimmerBox(width: 64, height: 14, borderRadius: 4),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else ...[
          _shimmerWhenRefreshing(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCurrencySwitcher(context, official: official, fmt: fmt),
                const SizedBox(height: 14),
                _buildRatesPanel(
                  context,
                  byBank: byBank,
                  names: names,
                  maxBuy: maxBuy,
                  minSell: minSell,
                  fmt: fmt,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCurrencySwitcher(
    BuildContext context, {
    required Map<String, RateRow> official,
    required String Function(
      double?, {
      String? code,
      int? minDecimals,
      int? maxDecimals,
    })
    fmt,
  }) {
    final colors = context.colors;
    final count = _codes.length;
    final selectedIndex = _codes.indexOf(_selectedCurrency).clamp(0, count - 1);
    final bubbleAlign = count <= 1
        ? Alignment.center
        : Alignment(-1.0 + (2.0 * selectedIndex / (count - 1)), 0);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceNested,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedAlign(
              duration: _switchDuration,
              curve: _switchCurve,
              alignment: bubbleAlign,
              child: FractionallySizedBox(
                widthFactor: 1 / count,
                heightFactor: 1,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.brand.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final code in _codes)
                Expanded(
                  child: _buildNbtCurrencyCard(
                    context,
                    code: code,
                    rate: official[code]?.rate,
                    isSelected: _selectedCurrency == code,
                    onTap: () => _selectCurrency(code),
                    fmt: fmt,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatesPanel(
    BuildContext context, {
    required Map<String, Map<String, BankRateQuote>> byBank,
    required Map<String, String> names,
    required double? maxBuy,
    required double? minSell,
    required String Function(
      double?, {
      String? code,
      int? minDecimals,
      int? maxDecimals,
    })
    fmt,
  }) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    if (byBank.isEmpty) {
      return Text(
        language.translate('dashboard_rates_banks_pending'),
        style: textStyles.smallSans.copyWith(color: colors.textTooltip),
      );
    }

    return ClipRect(
      child: AnimatedSwitcher(
        duration: _switchDuration,
        switchInCurve: _switchCurve,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.hardEdge,
            children: [...previousChildren, ?currentChild],
          );
        },
        transitionBuilder: (child, animation) {
          final isIncoming =
              (child.key as ValueKey<String>?)?.value == _selectedCurrency;
          final begin = Offset(_slideDir * (isIncoming ? 0.12 : -0.12), 0);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(begin: begin, end: Offset.zero).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: _switchCurve,
                  reverseCurve: Curves.easeInCubic,
                ),
              ),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(_selectedCurrency),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    language.translate(
                      'dashboard_rates_for_currency',
                      params: {'currency': _selectedCurrency},
                    ),
                    style: textStyles.captionSans.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: context.fontSize(13),
                      color: colors.textSecondary,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colors.accentGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        language.translate('dashboard_rates_buy'),
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                          fontSize: context.fontSize(11),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colors.accentRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        language.translate('dashboard_rates_sell'),
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                          fontSize: context.fontSize(11),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  children: [
                    for (var idx = 0; idx < byBank.entries.length; idx++) ...[
                      if (idx > 0)
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: colors.border.withValues(alpha: 0.6),
                        ),
                      _buildBankRow(
                        context,
                        currencyCode: _selectedCurrency,
                        bankName:
                            names[byBank.entries.elementAt(idx).key] ??
                            byBank.entries.elementAt(idx).key,
                        quote: byBank.entries
                            .elementAt(idx)
                            .value[_selectedCurrency],
                        maxBuy: maxBuy,
                        minSell: minSell,
                        fmt: fmt,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNbtCurrencyCard(
    BuildContext context, {
    required String code,
    required double? rate,
    required bool isSelected,
    required VoidCallback onTap,
    required String Function(
      double?, {
      String? code,
      int? minDecimals,
      int? maxDecimals,
    })
    fmt,
  }) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.read<LanguageCubit>();
    final accent = isSelected ? colors.brand : colors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: colors.brand.withValues(alpha: 0.08),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 240),
                    curve: _switchCurve,
                    style: textStyles.captionSans.copyWith(
                      fontWeight: FontWeight.w700,
                      color: accent,
                      fontSize: context.fontSize(13),
                    ),
                    child: Text(code),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getCurrencyFlag(code),
                    style: TextStyle(fontSize: context.fontSize(15)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              AnimatedScale(
                scale: isSelected ? 1.04 : 1,
                duration: const Duration(milliseconds: 240),
                curve: _switchCurve,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 240),
                    curve: _switchCurve,
                    style: textStyles.bodyMono.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: context.fontSize(18),
                      color: accent,
                    ),
                    child: Text(fmt(rate, code: code)),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${language.translate('dashboard_rates_nbt')} · TJS',
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                  fontSize: context.fontSize(10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBankRow(
    BuildContext context, {
    required String currencyCode,
    required String bankName,
    required BankRateQuote? quote,
    required double? maxBuy,
    required double? minSell,
    required String Function(
      double?, {
      String? code,
      int? minDecimals,
      int? maxDecimals,
    })
    fmt,
  }) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.read<LanguageCubit>();

    final isBestBuy =
        quote?.buy != null &&
        maxBuy != null &&
        (quote!.buy! - maxBuy).abs() < 0.0001;
    final isBestSell =
        quote?.sell != null &&
        minSell != null &&
        (quote!.sell! - minSell).abs() < 0.0001;
    final isBest = isBestBuy || isBestSell;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // Название банка и бейдж выгоды
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: colors.brand.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    TablerIcons.building_bank,
                    size: 15,
                    color: colors.brand,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        bankName,
                        style: textStyles.bodySans.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: context.fontSize(13.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isBest) ...[
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: colors.accentGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '★ ${language.translate('dashboard_rates_best_badge')}',
                            style: textStyles.captionSans.copyWith(
                              color: colors.accentGreen,
                              fontSize: context.fontSize(9.5),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Колонка Покупка
          SizedBox(
            width: 78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    fmt(quote?.buy, code: currencyCode),
                    style: textStyles.bodyMono.copyWith(
                      color: colors.accentGreen,
                      fontWeight: FontWeight.w700,
                      fontSize: context.fontSize(15),
                    ),
                  ),
                ),
                Text(
                  language.translate('dashboard_rates_buy').toLowerCase(),
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
                    fontSize: context.fontSize(10),
                  ),
                ),
              ],
            ),
          ),

          // Разделитель
          Container(
            height: 24,
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: colors.border.withValues(alpha: 0.7),
          ),

          // Колонка Продажа
          SizedBox(
            width: 78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    fmt(quote?.sell, code: currencyCode),
                    style: textStyles.bodyMono.copyWith(
                      color: colors.accentRed,
                      fontWeight: FontWeight.w700,
                      fontSize: context.fontSize(15),
                    ),
                  ),
                ),
                Text(
                  language.translate('dashboard_rates_sell').toLowerCase(),
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
                    fontSize: context.fontSize(10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
