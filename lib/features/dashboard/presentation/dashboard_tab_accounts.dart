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

    if (accountsReport == null || ratesReport == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => _refreshDashboard(context),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            languageCubit.translate('dashboard_bank_accounts'),
            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          ...accountsReport.accounts.map(
            (acc) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: LedgerCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
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
                    Text(
                      '${_formatAmount(context, acc.balance)} ${acc.currency}',
                      style: textStyles.bodyMono.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
          Text(
            languageCubit.translate('dashboard_nbt_rates'),
            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
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
        ],
      ),
    );
  }
}
