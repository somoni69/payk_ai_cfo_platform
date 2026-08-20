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

    String fmt(double? v) =>
        v == null ? '—' : formatLocalizedNumber(context, v);

    return LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(TablerIcons.building_bank, size: 20, color: colors.brand),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  language.translate('dashboard_rates_title'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                tooltip: language.translate('dashboard_rates_refresh'),
                onPressed: _loading ? null : _load,
                icon: Icon(
                  TablerIcons.refresh,
                  size: 18,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          if (freshest != null) ...[
            const SizedBox(height: 4),
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
              style: textStyles.smallSans.copyWith(color: colors.textTooltip),
            ),
          ],
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else ...[
            Row(
              children: [
                for (var i = 0; i < _codes.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceNested,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _codes[i],
                            style: textStyles.smallSans.copyWith(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            fmt(official[_codes[i]]?.rate),
                            style: textStyles.bodySans.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            language.translate('dashboard_rates_nbt'),
                            style: textStyles.smallSans.copyWith(
                              color: colors.textTooltip,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (byBank.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...byBank.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        names[entry.key] ?? entry.key,
                        style: textStyles.captionSans.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          children: [
                            for (var i = 0; i < _codes.length; i++) ...[
                              if (i > 0)
                                TextSpan(
                                  text: '   ',
                                  style: textStyles.smallSans,
                                ),
                              TextSpan(
                                text: '${_codes[i]} ',
                                style: textStyles.smallSans.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.baseline,
                                baseline: TextBaseline.alphabetic,
                                child: _buySell(
                                  context,
                                  entry.value[_codes[i]],
                                ),
                              ),
                            ],
                          ],
                        ),
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

  Widget _buySell(BuildContext context, BankRateQuote? quote) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    if (quote == null) {
      return Text('—', style: textStyles.smallMono);
    }
    String fmt(double? v) =>
        v == null ? '—' : formatLocalizedNumber(context, v);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: fmt(quote.buy),
            style: textStyles.smallMono.copyWith(color: colors.accentGreen),
          ),
          TextSpan(
            text: ' / ',
            style: textStyles.smallMono.copyWith(color: colors.textTooltip),
          ),
          TextSpan(
            text: fmt(quote.sell),
            style: textStyles.smallMono.copyWith(color: colors.accentRed),
          ),
        ],
      ),
    );
  }
}
