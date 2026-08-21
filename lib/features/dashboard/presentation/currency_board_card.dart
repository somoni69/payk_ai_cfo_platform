import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/localization/locale_number_format.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../presentation/widgets/ledger_card.dart';
import '../domain/finance_model.dart';
import '../domain/finance_repository.dart';

/// Доска курсов: НБТ + покупка/продажа банков.
class CurrencyBoardCard extends StatefulWidget {
  const CurrencyBoardCard({super.key});

  @override
  State<CurrencyBoardCard> createState() => _CurrencyBoardCardState();
}

class _CurrencyBoardCardState extends State<CurrencyBoardCard> {
  static const _codes = ['USD', 'EUR', 'RUB'];
  CurrencyBoard? _board;
  var _loading = true;
  var _failed = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(minutes: 30), (_) {
      if (!mounted || !TickerMode.valuesOf(context).enabled) return;
      _load();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
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
        _failed = true;
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

    String fmt(double? v, {int minDecimals = 2}) => v == null
        ? '—'
        : formatLocalizedNumber(context, v, minimumFractionDigits: minDecimals);

    return LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
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
                      style: textStyles.bodySans.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: context.fontSize(15),
                      ),
                    ),
                    if (freshest != null) ...[
                      const SizedBox(height: 1),
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
          if (_loading && _board == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else ...[
            // Верхний ряд: Официальные курсы НБТ с крупными цифрами
            Row(
              children: [
                for (var i = 0; i < _codes.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceNested,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: colors.border.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _codes[i],
                                style: textStyles.captionSans.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                  fontSize: context.fontSize(12),
                                ),
                              ),
                              Text(
                                _getCurrencyFlag(_codes[i]),
                                style: TextStyle(
                                  fontSize: context.fontSize(14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            fmt(
                              official[_codes[i]]?.rate,
                              minDecimals: _codes[i] == 'RUB' ? 2 : 2,
                            ),
                            style: textStyles.bodyMono.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: context.fontSize(17),
                              color: colors.brand,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            language.translate('dashboard_rates_nbt'),
                            style: textStyles.captionSans.copyWith(
                              color: colors.textSecondary,
                              fontSize: context.fontSize(10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),

            // Блок курсов коммерческих банков
            if (byBank.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    language.translate('dashboard_rates_commercial_banks'),
                    style: textStyles.captionSans.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: context.fontSize(12),
                      color: colors.textSecondary,
                    ),
                  ),
                  Text(
                    language.translate('dashboard_rates_buy_sell_legend'),
                    style: textStyles.captionSans.copyWith(
                      color: colors.textTooltip,
                      fontSize: context.fontSize(10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...byBank.entries.map((entry) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceNested,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colors.border.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            TablerIcons.building_bank,
                            size: 14,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              names[entry.key] ?? entry.key,
                              style: textStyles.bodySans.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: context.fontSize(13),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          for (var i = 0; i < _codes.length; i++) ...[
                            if (i > 0) const SizedBox(width: 6),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.surface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: colors.border.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _codes[i],
                                      style: textStyles.captionSans.copyWith(
                                        color: colors.textSecondary,
                                        fontSize: context.fontSize(10),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    _buildBuySellRow(
                                      context,
                                      entry.value[_codes[i]],
                                      _codes[i],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
            if (byBank.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                language.translate('dashboard_rates_banks_pending'),
                style: textStyles.smallSans.copyWith(color: colors.textTooltip),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildBuySellRow(
    BuildContext context,
    BankRateQuote? quote,
    String code,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    if (quote == null || (quote.buy == null && quote.sell == null)) {
      return Text(
        '—',
        style: textStyles.smallMono.copyWith(color: colors.textSecondary),
      );
    }
    String fmt(double? v) => v == null
        ? '—'
        : formatLocalizedNumber(context, v, minimumFractionDigits: 2);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            fmt(quote.buy),
            style: textStyles.smallMono.copyWith(
              color: colors.accentGreen,
              fontWeight: FontWeight.w700,
              fontSize: context.fontSize(12.5),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            '/',
            style: textStyles.smallMono.copyWith(
              color: colors.textTooltip,
              fontSize: context.fontSize(10),
            ),
          ),
        ),
        Flexible(
          child: Text(
            fmt(quote.sell),
            style: textStyles.smallMono.copyWith(
              color: colors.accentRed,
              fontWeight: FontWeight.w700,
              fontSize: context.fontSize(12.5),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
