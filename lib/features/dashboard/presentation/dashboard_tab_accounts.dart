part of 'dashboard_screen.dart';

extension _DashboardAccountsTab on _DashboardViewState {
  Widget _buildAccountsRatesTab(
    BuildContext context,
    BankAccountsReport? accountsReport,
    ExchangeRatesReport? ratesReport,
    String currency,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final languageCubit = context.read<LanguageCubit>();
    final auth = context.watch<AuthBloc>().state;
    final canWrite = auth is AuthAuthenticated &&
        auth.role.canWrite(AppCapability.dashboard);
    final isDirector =
        auth is AuthAuthenticated && auth.role == UserRole.director;

    if (accountsReport == null || ratesReport == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => _refreshDashboard(context),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  languageCubit.translate('dashboard_bank_accounts'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (canWrite)
                IconButton(
                  onPressed: () => _showCreateAccountSheet(context),
                  icon: Icon(TablerIcons.plus, color: colors.brand),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...accountsReport.accounts.map(
            (acc) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: LedgerCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                languageCubit.translateMessage(acc.name),
                                style: textStyles.bodySans.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${acc.bank ?? languageCubit.translate('dashboard_settlement_account')} • ${acc.number ?? ""}',
                                style: textStyles.captionSans.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${_formatAmount(context, acc.balance)} ${acc.currency}',
                          style: textStyles.bodyMono.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (canWrite) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (isDirector && acc.balance != 0)
                            TextButton(
                              onPressed: () => context.read<DashboardBloc>().add(
                                    ZeroOutAccountRequested(acc.id),
                                  ),
                              child: Text(
                                languageCubit.translate(
                                  'dashboard_account_zero_out',
                                ),
                              ),
                            ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => context.read<DashboardBloc>().add(
                                  DeleteAccountRequested(acc.id),
                                ),
                            icon: Icon(
                              TablerIcons.trash,
                              size: 18,
                              color: colors.accentRed,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          LedgerCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  languageCubit.translate('dashboard_total_balance_tjs'),
                  style: textStyles.captionSans.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${_formatAmount(context, accountsReport.totalTjs)} TJS',
                  style: textStyles.bodyMono.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colors.brand,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  languageCubit.translate('dashboard_nbt_rates'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (canWrite)
                TextButton.icon(
                  onPressed: () => context.read<DashboardBloc>().add(
                        const RefreshRatesRequested(),
                      ),
                  icon: Icon(TablerIcons.refresh, size: 16, color: colors.brand),
                  label: Text(
                    languageCubit.translate('dashboard_rates_refresh'),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          LedgerCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: ratesReport.rates.map((rate) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '1 ${rate.code}',
                        style: textStyles.bodySans.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${formatLocalizedNumber(context, rate.rate, minimumFractionDigits: 4, maximumFractionDigits: 4)} TJS',
                        style: textStyles.bodyMono.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            languageCubit.translate('dashboard_converter_title'),
            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          _CurrencyConverterCard(rates: ratesReport.rates),
        ],
      ),
    );
  }

  Future<void> _showCreateAccountSheet(BuildContext context) async {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.read<LanguageCubit>();
    final nameCtrl = TextEditingController();
    final bankCtrl = TextEditingController();
    final numberCtrl = TextEditingController();
    final balanceCtrl = TextEditingController(text: '0');
    String currency = 'TJS';

    try {
      await LedgerBottomSheet.show(
        context: context,
        title: language.translate('dashboard_account_add'),
        builder: (context, setSheetState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameCtrl,
                style: textStyles.bodySans,
                decoration: InputDecoration(
                  labelText: language.translate('dashboard_account_name'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bankCtrl,
                style: textStyles.bodySans,
                decoration: InputDecoration(
                  labelText: language.translate('dashboard_account_bank'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: numberCtrl,
                style: textStyles.bodySans,
                decoration: InputDecoration(
                  labelText: language.translate('dashboard_account_number'),
                ),
              ),
              const SizedBox(height: 12),
              ExpansibleWidget<String>.selection(
                cardPadding: EdgeInsets.zero,
                tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Text(
                  currency,
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                items: const ['TJS', 'USD', 'EUR', 'RUB'],
                selectedValue: currency,
                itemLabelBuilder: (c) => c,
                onSelected: (v) => setSheetState(() => currency = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: balanceCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: textStyles.bodySans,
                decoration: InputDecoration(
                  labelText: language.translate('dashboard_account_balance'),
                ),
              ),
            ],
          );
        },
        footerBuilder: (context, setSheetState) {
          return SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final balance =
                    parseLocalizedNumber(context, balanceCtrl.text.trim()) ?? 0;
                this.context.read<DashboardBloc>().add(
                      CreateAccountRequested(
                        name: name,
                        bank: bankCtrl.text.trim().isEmpty
                            ? null
                            : bankCtrl.text.trim(),
                        number: numberCtrl.text.trim().isEmpty
                            ? null
                            : numberCtrl.text.trim(),
                        currency: currency,
                        balance: balance,
                      ),
                    );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.brand,
                foregroundColor: colors.surface,
                elevation: 0,
              ),
              child: Text(language.translate('common_create')),
            ),
          );
        },
      );
    } finally {
      nameCtrl.dispose();
      bankCtrl.dispose();
      numberCtrl.dispose();
      balanceCtrl.dispose();
    }
  }
}

class _CurrencyConverterCard extends StatefulWidget {
  final List<RateRow> rates;

  const _CurrencyConverterCard({required this.rates});

  @override
  State<_CurrencyConverterCard> createState() => _CurrencyConverterCardState();
}

class _CurrencyConverterCardState extends State<_CurrencyConverterCard> {
  final _amountCtrl = TextEditingController(text: '100');
  String _base = 'USD';
  ConvertResult? _result;
  bool _loading = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _convert() async {
    final amount = parseLocalizedNumber(context, _amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) return;
    setState(() => _loading = true);
    try {
      final res = await context.read<FinanceRepository>().convertAmount(
            amount,
            _base,
          );
      if (!mounted) return;
      setState(() => _result = res);
    } catch (_) {
      if (!mounted) return;
      setState(() => _result = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);

    return LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: textStyles.bodySans,
                  decoration: InputDecoration(
                    labelText: language.translate('dashboard_converter_amount'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 100,
                child: ExpansibleWidget<String>.selection(
                  cardPadding: EdgeInsets.zero,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: Text(
                    _base,
                    style: textStyles.bodySans.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  items: const ['USD', 'EUR', 'RUB', 'TJS'],
                  selectedValue: _base,
                  itemLabelBuilder: (c) => c,
                  onSelected: (v) => setState(() => _base = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loading ? null : _convert,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.brand,
              foregroundColor: colors.surface,
              elevation: 0,
            ),
            child: _loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.surface,
                    ),
                  )
                : Text(language.translate('dashboard_converter_run')),
          ),
          if (_result != null) ...[
            const SizedBox(height: 12),
            ..._result!.values.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: textStyles.captionSans),
                    Text(
                      oCcy.format(e.value),
                      style: textStyles.bodyMono.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
