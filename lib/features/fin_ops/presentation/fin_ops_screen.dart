import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_number_format.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/auth/bloc/auth_state.dart';
import '../../../features/auth/domain/app_access.dart';
import '../../../features/fin_ops/bloc/fin_ops_bloc.dart';
import '../../../features/fin_ops/bloc/fin_ops_event.dart';
import '../../../features/fin_ops/bloc/fin_ops_state.dart';
import '../../../features/fin_ops/domain/fin_ops_models.dart';
import '../../../features/fin_ops/domain/fin_ops_repository.dart';
import '../../../features/branches/domain/branch_models.dart';
import '../../../features/branches/domain/branches_repository.dart';
import '../../../features/cash/domain/cash_repository.dart';
import '../../../features/cash/domain/transaction_model.dart';
import '../../../features/hr/domain/hr_models.dart';
import '../../../features/hr/domain/hr_repository.dart';
import '../../../features/audit/presentation/entity_history_sheet.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../../../presentation/widgets/expansible_widget.dart';
import '../../../presentation/widgets/ledger_fab.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';

enum FinOpsSection { banks, transfers, aid, encashments }

String _finOpsSectionTitle(LanguageCubit language, FinOpsSection section) {
  return language.translate(switch (section) {
    FinOpsSection.banks => 'fin_ops_tab_banks',
    FinOpsSection.transfers => 'fin_ops_tab_transfers',
    FinOpsSection.aid => 'fin_ops_tab_aid',
    FinOpsSection.encashments => 'fin_ops_new_encashment',
  });
}

void _openFinOpsSection(BuildContext context, FinOpsSection section) {
  final bloc = context.read<FinOpsBloc>();
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: FinOpsSectionScreen(section: section),
      ),
    ),
  );
}

class FinOpsScreen extends StatelessWidget {
  const FinOpsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FinOpsBloc>(
      create: (context) => FinOpsBloc(
        context.read<FinOpsRepository>(),
        context.read<BranchesRepository>(),
      )..add(const LoadFinOpsData()),
      child: const FinOpsView(),
    );
  }
}

class FinOpsView extends StatefulWidget {
  const FinOpsView({super.key});

  @override
  State<FinOpsView> createState() => _FinOpsViewState();
}

class _FinOpsViewState extends State<FinOpsView> {
  bool _canManage(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated &&
        authState.role.canManage(AppCapability.finOps);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();
    final canManage = _canManage(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          locale.translate('fin_ops_title'),
          style: textStyles.h2Sans.copyWith(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: colors.border),
        ),
      ),
      body: BlocBuilder<FinOpsBloc, FinOpsState>(
        builder: (context, state) {
          if (state is FinOpsLoading) {
            return const FinOpsOverviewShimmer();
          }
          if (state is FinOpsError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      TablerIcons.alert_circle,
                      size: 48,
                      color: colors.accentRed,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      locale.translateMessage(state.message),
                      style: textStyles.bodySans,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.read<FinOpsBloc>().add(
                        const LoadFinOpsData(),
                      ),
                      child: Text(locale.translate('common_retry')),
                    ),
                  ],
                ),
              ),
            );
          }
          if (state is FinOpsLoaded) {
            return _buildFinOpsOverviewHub(context, state, canManage);
          }
          return const SizedBox();
        },
      ),
    );
  }

  Widget _buildFinOpsOverviewHub(
    BuildContext context,
    FinOpsLoaded state,
    bool canManage,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);

    final totalBalance = state.bankAccounts.fold<double>(
      0.0,
      (s, b) => s + b.balance,
    );
    final pendingTransfers = state.storeTransfers
        .where((t) => t.status == 'pending')
        .length;
    final activeAid = state.financialAids
        .where((a) => a.status == 'active')
        .length;
    final hasPending = pendingTransfers > 0 || activeAid > 0;

    return RefreshIndicator(
      onRefresh: () async {
        context.read<FinOpsBloc>().add(const LoadFinOpsData());
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // 1. Hero Card: Total Bank Liquidity & Active Accounts
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        locale.translate('fin_ops_hero_liquidity'),
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w500,
                          fontSize: 13.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.brand.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            TablerIcons.building_bank,
                            size: 13,
                            color: colors.brand,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            locale.translate(
                              'fin_ops_accounts_count',
                              params: {'count': '${state.bankAccounts.length}'},
                            ),
                            style: textStyles.captionSans.copyWith(
                              color: colors.brand,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${oCcy.format(totalBalance)} TJS',
                  style: textStyles.h2Sans.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: colors.border),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      TablerIcons.arrows_transfer_up,
                      size: 16,
                      color: colors.brand,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      locale.translate(
                        'fin_ops_transfers_count',
                        params: {'count': '${state.storeTransfers.length}'},
                      ),
                      style: textStyles.captionSans.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• ${state.financialAids.length} ${locale.translate('fin_ops_tab_aid').toLowerCase()}',
                      style: textStyles.captionSans.copyWith(
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. Actionable Attention & Treasury Control Card
          InkWell(
            onTap: () => _openFinOpsSection(
              context,
              pendingTransfers > 0
                  ? FinOpsSection.transfers
                  : (activeAid > 0 ? FinOpsSection.aid : FinOpsSection.banks),
            ),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasPending
                      ? colors.accentAmber.withValues(alpha: 0.6)
                      : colors.accentGreen.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: hasPending
                          ? colors.accentAmber.withValues(alpha: 0.1)
                          : colors.accentGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      hasPending
                          ? TablerIcons.alert_triangle
                          : TablerIcons.circle_check,
                      color: hasPending
                          ? colors.accentAmber
                          : colors.accentGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locale.translate('fin_ops_attention_title'),
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasPending
                              ? locale.translate(
                                  'fin_ops_attention_pending',
                                  params: {
                                    'transfers': '$pendingTransfers',
                                    'aid': '$activeAid',
                                  },
                                )
                              : locale.translate('fin_ops_attention_ok'),
                          style: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    TablerIcons.chevron_right,
                    size: 18,
                    color: colors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 3. Quick Action Buttons Row (if canManage)
          if (canManage) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showEncashmentModal(context, state),
                    icon: const Icon(TablerIcons.cash_banknote),
                    label: Text(
                      locale.translate('fin_ops_new_encashment'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _showTransferModal(context, state.branches),
                    icon: const Icon(TablerIcons.arrows_transfer_up),
                    label: Text(
                      locale.translate('fin_ops_tab_transfers'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // 4. Main 2x2 Navigation Grid
          Row(
            children: [
              Expanded(
                child: _buildHubCard(
                  context,
                  title: locale.translate('fin_ops_tab_banks'),
                  subtitle: locale.translate(
                    'fin_ops_accounts_count',
                    params: {'count': '${state.bankAccounts.length}'},
                  ),
                  icon: TablerIcons.building_bank,
                  onTap: () => _openFinOpsSection(context, FinOpsSection.banks),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHubCard(
                  context,
                  title: locale.translate('fin_ops_tab_transfers'),
                  subtitle: pendingTransfers > 0
                      ? '$pendingTransfers в пути'
                      : '${state.storeTransfers.length} операций',
                  icon: TablerIcons.arrows_transfer_up,
                  onTap: () =>
                      _openFinOpsSection(context, FinOpsSection.transfers),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildHubCard(
                  context,
                  title: locale.translate('fin_ops_tab_aid'),
                  subtitle: activeAid > 0
                      ? '$activeAid активных'
                      : '${state.financialAids.length} заявок',
                  icon: TablerIcons.heart_handshake,
                  onTap: () => _openFinOpsSection(context, FinOpsSection.aid),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHubCard(
                  context,
                  title: locale.translate('fin_ops_new_encashment'),
                  subtitle: '${state.encashments.length} операций',
                  icon: TablerIcons.receipt_2,
                  onTap: () =>
                      _openFinOpsSection(context, FinOpsSection.encashments),
                ),
              ),
            ],
          ),
          if (state.branchBalances.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              locale.translate('fin_ops_branch_balances'),
              style: textStyles.h2Sans.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            ...state.branchBalances.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          locale.translateMessage(b.branchName),
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${oCcy.format(b.balance)} TJS',
                            style: textStyles.bodyMono.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (b.inTransit > 0)
                            Text(
                              '${locale.translate('fin_ops_in_transit')}: ${oCcy.format(b.inTransit)}',
                              style: textStyles.captionSans.copyWith(
                                color: colors.brand,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),

          // 5. Recent Bank Accounts Feed
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                locale.translate('fin_ops_recent_banks'),
                style: textStyles.h2Sans.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () =>
                    _openFinOpsSection(context, FinOpsSection.banks),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  children: [
                    Text(
                      locale.translate('fin_ops_all_banks'),
                      style: textStyles.captionSans.copyWith(
                        color: colors.brand,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      TablerIcons.chevron_right,
                      size: 14,
                      color: colors.brand,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (state.bankAccounts.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              alignment: Alignment.center,
              child: Text(
                locale.translate('empty_data'),
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                  fontSize: 13.5,
                ),
              ),
            )
          else
            ...state.bankAccounts.take(4).map((bank) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: colors.surfaceNested,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          TablerIcons.building_bank,
                          color: colors.brand,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              locale.translateMessage(bank.bankName),
                              style: textStyles.bodySans.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 14.5,
                                color: colors.textPrimary,
                              ),
                            ),
                            if (bank.accountNumber.isNotEmpty)
                              Text(
                                bank.accountNumber,
                                style: textStyles.captionSans.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 12.5,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: bank.isActive
                                  ? colors.accentGreen.withValues(alpha: 0.1)
                                  : colors.surfaceNested,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              bank.isActive
                                  ? locale.translate('status_active')
                                  : locale.translate('hr_status_inactive'),
                              style: textStyles.captionSans.copyWith(
                                color: bank.isActive
                                    ? colors.accentGreen
                                    : colors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${oCcy.format(bank.balance)} TJS',
                            style: textStyles.bodyMono.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildHubCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.brand.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 19, color: colors.brand),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                  color: colors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                  fontSize: 12.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FinOpsSectionScreen extends StatelessWidget {
  final FinOpsSection section;

  const FinOpsSectionScreen({super.key, required this.section});

  bool _canManage(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated &&
        authState.role.canManage(AppCapability.finOps);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();
    final canManage = _canManage(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
        title: Text(
          _finOpsSectionTitle(locale, section),
          style: textStyles.h2Sans.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: colors.border),
        ),
      ),
      floatingActionButton: canManage
          ? _buildSectionFab(context, locale)
          : null,
      body: BlocBuilder<FinOpsBloc, FinOpsState>(
        builder: (context, state) {
          if (state is FinOpsLoading) {
            return const LedgerListShimmer(itemCount: 6);
          }
          if (state is FinOpsLoaded) {
            return switch (section) {
              FinOpsSection.banks => _buildBanksTab(context, state, canManage),
              FinOpsSection.transfers => _buildTransfersTab(
                context,
                state,
                canManage,
              ),
              FinOpsSection.aid => _buildAidTab(context, state, canManage),
              FinOpsSection.encashments => _buildEncashmentsTab(
                context,
                state,
                canManage,
              ),
            };
          }
          return const SizedBox();
        },
      ),
    );
  }

  Widget? _buildSectionFab(BuildContext context, LanguageCubit locale) {
    final state = context.read<FinOpsBloc>().state;
    if (state is! FinOpsLoaded) return null;

    final (icon, label, action) = switch (section) {
      FinOpsSection.banks => (
        TablerIcons.plus,
        locale.translate('fin_ops_new_bank'),
        () => _showCreateBankSheet(context),
      ),
      FinOpsSection.transfers => (
        TablerIcons.arrows_transfer_up,
        locale.translate('fin_ops_new_transfer'),
        () => _showTransferModal(context, state.branches),
      ),
      FinOpsSection.aid => (
        TablerIcons.plus,
        locale.translate('fin_ops_new_aid'),
        () => _showAidModal(context, state),
      ),
      FinOpsSection.encashments => (
        TablerIcons.plus,
        locale.translate('fin_ops_new_encashment'),
        () => _showEncashmentModal(context, state),
      ),
    };

    return LedgerFab(
      heroTag: null,
      onPressed: action,
      icon: icon,
      label: label,
    );
  }

  Widget _buildBanksTab(
    BuildContext context,
    FinOpsLoaded state,
    bool canManage,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);

    return RefreshIndicator(
      onRefresh: () async {
        context.read<FinOpsBloc>().add(const LoadFinOpsData());
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
        itemCount: state.bankAccounts.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final bank = state.bankAccounts[index];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.surfaceNested,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    TablerIcons.building_bank,
                    color: colors.brand,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        locale.translateMessage(bank.bankName),
                        style: textStyles.bodySans.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: colors.textPrimary,
                        ),
                      ),
                      if (bank.accountNumber.isNotEmpty)
                        Text(
                          bank.accountNumber,
                          style: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: bank.isActive
                            ? colors.accentGreen.withValues(alpha: 0.1)
                            : colors.surfaceNested,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        bank.isActive
                            ? locale.translate('status_active')
                            : locale.translate('hr_status_inactive'),
                        style: textStyles.captionSans.copyWith(
                          color: bank.isActive
                              ? colors.accentGreen
                              : colors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${oCcy.format(bank.balance)} TJS',
                      style: textStyles.bodyMono.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (canManage && bank.isActive) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => context.read<FinOpsBloc>().add(
                      DeleteBankRequested(bank.id),
                    ),
                    icon: Icon(
                      TablerIcons.power,
                      size: 18,
                      color: colors.accentRed,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransfersTab(
    BuildContext context,
    FinOpsLoaded state,
    bool canManage,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);

    final headerCount = state.branchBalances.isEmpty
        ? 0
        : 1 + state.branchBalances.length;

    if (state.storeTransfers.isEmpty && state.branchBalances.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            locale.translate('empty_data'),
            style: textStyles.bodySans.copyWith(color: colors.textSecondary),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<FinOpsBloc>().add(const LoadFinOpsData());
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
        itemCount: headerCount + state.storeTransfers.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (headerCount > 0 && index == 0) {
            return Text(
              locale.translate('fin_ops_branch_balances'),
              style: textStyles.h2Sans.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            );
          }
          if (index < headerCount) {
            final b = state.branchBalances[index - 1];
            return Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      locale.translateMessage(b.branchName),
                      style: textStyles.bodySans.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${oCcy.format(b.balance)} TJS',
                        style: textStyles.bodyMono.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (b.inTransit > 0)
                        Text(
                          '${locale.translate('fin_ops_in_transit')}: ${oCcy.format(b.inTransit)}',
                          style: textStyles.captionSans.copyWith(
                            color: colors.brand,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }
          final tr = state.storeTransfers[index - headerCount];
          final isPending = tr.status == 'pending' || tr.status == 'sent';

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${oCcy.format(tr.amount)} TJS',
                      style: textStyles.h2Sans.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: colors.brand,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isPending
                                ? colors.accentAmber.withValues(alpha: 0.1)
                                : colors.accentGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isPending
                                ? locale.translate('fin_ops_status_pending')
                                : locale.translate('fin_ops_status_received'),
                            style: textStyles.captionSans.copyWith(
                              color: isPending
                                  ? colors.accentAmber
                                  : colors.accentGreen,
                              fontWeight: FontWeight.w600,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: locale.translate('more_audit'),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => showEntityHistorySheet(
                            context,
                            entity: 'store_transfer',
                            id: tr.id,
                          ),
                          icon: Icon(
                            TablerIcons.history,
                            size: 18,
                            color: colors.brand,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${locale.translateMessage(tr.fromBranch)} ➔ ${locale.translateMessage(tr.toBranch)}',
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                if (isPending && canManage) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          context.read<FinOpsBloc>().add(
                            CancelStoreTransferRequested(tr.id),
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: colors.accentRed,
                        ),
                        child: Text(
                          locale.translate('fin_ops_cancel_transfer'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          context.read<FinOpsBloc>().add(
                            UpdateTransferStatusRequested(
                              transferId: tr.id,
                              status: 'received',
                            ),
                          );
                        },
                        child: Text(
                          locale.translate('fin_ops_confirm_receive'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAidTab(
    BuildContext context,
    FinOpsLoaded state,
    bool canManage,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);

    if (state.financialAids.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            locale.translate('empty_data'),
            style: textStyles.bodySans.copyWith(color: colors.textSecondary),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<FinOpsBloc>().add(const LoadFinOpsData());
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
        itemCount: state.financialAids.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final aid = state.financialAids[index];
          final isActive = aid.deductFromSalary && aid.remainingAmount > 0;

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      locale.translateMessage(aid.employeeName),
                      style: textStyles.bodySans.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: colors.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? colors.accentAmber.withValues(alpha: 0.1)
                            : colors.accentGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        aid.deductFromSalary
                            ? (isActive
                                  ? locale.translate('fin_ops_aid_advance')
                                  : locale.translate('fin_ops_aid_closed'))
                            : locale.translate('fin_ops_aid_grant'),
                        style: textStyles.captionSans.copyWith(
                          color: isActive
                              ? colors.accentAmber
                              : colors.accentGreen,
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      locale.translate(
                        'fin_ops_loan_amount',
                        params: {'amount': oCcy.format(aid.amount)},
                      ),
                      style: textStyles.captionSans.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      locale.translate(
                        'fin_ops_repaid_amount',
                        params: {'amount': oCcy.format(aid.repaidAmount)},
                      ),
                      style: textStyles.captionSans.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
                if (aid.deductFromSalary) ...[
                  const SizedBox(height: 8),
                  Text(
                    locale.translate(
                      'fin_ops_aid_remaining',
                      params: {'amount': oCcy.format(aid.remainingAmount)},
                    ),
                    style: textStyles.captionSans.copyWith(
                      color: isActive ? colors.accentRed : colors.accentGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (aid.repayments.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    locale.translate('fin_ops_aid_repayments'),
                    style: textStyles.captionSans.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...aid.repayments.map(
                    (rep) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(rep.period, style: textStyles.captionSans),
                          Text(
                            oCcy.format(rep.amount),
                            style: textStyles.captionSans.copyWith(
                              fontWeight: FontWeight.w600,
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
        },
      ),
    );
  }

  Widget _buildEncashmentsTab(
    BuildContext context,
    FinOpsLoaded state,
    bool canManage,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);

    if (state.encashments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            locale.translate('empty_data'),
            style: textStyles.bodySans.copyWith(color: colors.textSecondary),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<FinOpsBloc>().add(const LoadFinOpsData());
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
        itemCount: state.encashments.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final enc = state.encashments[index];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        enc.registerName != null && enc.registerName!.isNotEmpty
                            ? enc.registerName!
                            : locale.translate(
                                'fin_ops_encashment_to',
                                params: {
                                  'bank': locale.translateMessage(enc.bankName),
                                },
                              ),
                        style: textStyles.bodySans.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                          color: colors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          locale.translateMessage(enc.responsiblePerson),
                          if (enc.bankName.isNotEmpty)
                            locale.translateMessage(enc.bankName),
                        ].join(' • '),
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                          fontSize: 12.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '+${oCcy.format(enc.amount)} TJS',
                      style: textStyles.bodyMono.copyWith(
                        color: colors.accentGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                      maxLines: 1,
                    ),
                    IconButton(
                      tooltip: locale.translate('more_audit'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => showEntityHistorySheet(
                        context,
                        entity: 'encashment',
                        id: enc.id,
                      ),
                      icon: Icon(
                        TablerIcons.history,
                        size: 16,
                        color: colors.brand,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

void _showEncashmentModal(BuildContext context, FinOpsLoaded state) {
  final locale = context.read<LanguageCubit>();
  final textStyles = context.textStyles;
  final cashRepo = context.read<CashRepository>();
  final amountCtrl = TextEditingController();
  CashRegister? selectedRegister;
  ResponsibleOption? selectedResponsible;
  var registers = <CashRegister>[];
  var loaded = false;

  LedgerBottomSheet.show(
    context: context,
    disposables: [amountCtrl],
    title: locale.translate('fin_ops_new_encashment'),
    builder: (context, setSheetState) {
      if (!loaded) {
        loaded = true;
        cashRepo.getRegisters().then((list) {
          setSheetState(() {
            registers = list;
            selectedRegister = list.isNotEmpty ? list.first : null;
          });
        });
        if (state.responsibleOptions.isNotEmpty) {
          selectedResponsible = state.responsibleOptions.first;
        }
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            locale.translate('fin_ops_register'),
            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          ExpansibleWidget<CashRegister?>.selection(
            borderRadius: 8.0,
            title: Text(
              selectedRegister?.name ??
                  locale.translate('fin_ops_select_register'),
              style: textStyles.bodySans,
            ),
            items: registers,
            selectedValue: selectedRegister,
            itemLabelBuilder: (r) => r?.name ?? '',
            onSelected: (val) => setSheetState(() => selectedRegister = val),
            cardPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 2,
            ),
            tilePadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          Text(
            locale.translate('fin_ops_responsible'),
            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          ExpansibleWidget<ResponsibleOption?>.selection(
            borderRadius: 8.0,
            title: Text(
              selectedResponsible?.label ??
                  locale.translate('fin_ops_select_responsible'),
              style: textStyles.bodySans,
            ),
            items: state.responsibleOptions,
            selectedValue: selectedResponsible,
            itemLabelBuilder: (r) => r?.label ?? '',
            onSelected: (val) => setSheetState(() => selectedResponsible = val),
            cardPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 2,
            ),
            tilePadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: locale.translate('fin_ops_encashment_amount'),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              final amt = parseLocalizedNumber(context, amountCtrl.text.trim());
              if (amt == null ||
                  amt <= 0 ||
                  selectedRegister == null ||
                  selectedResponsible == null) {
                return;
              }
              context.read<FinOpsBloc>().add(
                CreateEncashmentRequested(
                  registerId: selectedRegister!.id,
                  responsibleEmployeeId: selectedResponsible!.id,
                  amount: amt,
                ),
              );
              Navigator.pop(context);
            },
            child: Text(locale.translate('save_to_ledger')),
          ),
        ],
      );
    },
  );
}

void _showCreateBankSheet(BuildContext context) {
  final locale = context.read<LanguageCubit>();
  final textStyles = context.textStyles;
  final nameCtrl = TextEditingController();

  LedgerBottomSheet.show(
    context: context,
    disposables: [nameCtrl],
    title: locale.translate('fin_ops_new_bank'),
    builder: (context, setSheetState) => TextField(
      controller: nameCtrl,
      style: textStyles.bodySans,
      decoration: InputDecoration(
        labelText: locale.translate('fin_ops_bank_name'),
      ),
    ),
    footerBuilder: (context, setSheetState) {
      return ElevatedButton(
        onPressed: () {
          final name = nameCtrl.text.trim();
          if (name.isEmpty) return;
          context.read<FinOpsBloc>().add(CreateBankRequested(name));
          Navigator.pop(context);
        },
        child: Text(locale.translate('common_create')),
      );
    },
  );
}

void _showTransferModal(BuildContext context, List<Branch> branches) {
  final locale = context.read<LanguageCubit>();
  final textStyles = context.textStyles;

  Branch? selectedFromBranch = branches.isNotEmpty ? branches.first : null;
  Branch? selectedToBranch = branches.length > 1
      ? branches[1]
      : (branches.isNotEmpty ? branches.first : null);
  final amountCtrl = TextEditingController();

  LedgerBottomSheet.show(
    context: context,
    disposables: [amountCtrl],
    title: locale.translate('fin_ops_new_transfer'),
    builder: (context, setSheetState) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          locale.translate('fin_ops_from_branch'),
          style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        ExpansibleWidget<Branch?>.selection(
          borderRadius: 8.0,
          title: Text(
            selectedFromBranch != null
                ? context.read<LanguageCubit>().translateMessage(
                    selectedFromBranch!.name,
                  )
                : locale.translate('common_select'),
            style: textStyles.bodySans,
          ),
          items: branches,
          selectedValue: selectedFromBranch,
          itemLabelBuilder: (b) =>
              context.read<LanguageCubit>().translateMessage(b?.name ?? ''),
          onSelected: (b) {
            setSheetState(() => selectedFromBranch = b);
          },
          cardPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          tilePadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 16),
        Text(
          locale.translate('fin_ops_to_branch'),
          style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        ExpansibleWidget<Branch?>.selection(
          borderRadius: 8.0,
          title: Text(
            selectedToBranch != null
                ? context.read<LanguageCubit>().translateMessage(
                    selectedToBranch!.name,
                  )
                : locale.translate('common_select'),
            style: textStyles.bodySans,
          ),
          items: branches,
          selectedValue: selectedToBranch,
          itemLabelBuilder: (b) =>
              context.read<LanguageCubit>().translateMessage(b?.name ?? ''),
          onSelected: (b) {
            setSheetState(() => selectedToBranch = b);
          },
          cardPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          tilePadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: amountCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: locale.translate('fin_ops_transfer_amount'),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            final amt = parseLocalizedNumber(context, amountCtrl.text.trim());
            if (amt == null ||
                amt <= 0 ||
                selectedFromBranch == null ||
                selectedToBranch == null) {
              return;
            }
            context.read<FinOpsBloc>().add(
              CreateStoreTransferRequested(
                fromBranch: selectedFromBranch!.id,
                toBranch: selectedToBranch!.id,
                amount: amt,
              ),
            );
            Navigator.pop(context);
          },
          child: Text(locale.translate('save_to_ledger')),
        ),
      ],
    ),
  );
}

void _showAidModal(BuildContext context, FinOpsLoaded state) {
  final locale = context.read<LanguageCubit>();
  final textStyles = context.textStyles;
  final amountCtrl = TextEditingController();
  final hrRepo = context.read<HrRepository>();
  Employee? selectedEmployee;
  var employees = <Employee>[];
  var loaded = false;
  var deduct = true;
  CashRegister? selectedRegister;
  var registers = <CashRegister>[];

  LedgerBottomSheet.show(
    context: context,
    disposables: [amountCtrl],
    title: locale.translate('fin_ops_new_aid'),
    builder: (context, setSheetState) {
      if (!loaded) {
        loaded = true;
        hrRepo.getEmployees().then((list) {
          setSheetState(() {
            employees = list.where((e) => !e.isArchived).toList();
            selectedEmployee = employees.isNotEmpty ? employees.first : null;
          });
        });
        context.read<CashRepository>().getRegisters().then((list) {
          setSheetState(() {
            registers = list;
            selectedRegister = list.isNotEmpty ? list.first : null;
          });
        });
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            locale.translate('fin_ops_select_employee'),
            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          ExpansibleWidget<Employee?>.selection(
            borderRadius: 8.0,
            title: Text(
              selectedEmployee?.fullName ??
                  locale.translate('fin_ops_select_employee'),
              style: textStyles.bodySans,
            ),
            items: employees,
            selectedValue: selectedEmployee,
            itemLabelBuilder: (e) => e?.fullName ?? '',
            onSelected: (val) => setSheetState(() => selectedEmployee = val),
            cardPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 2,
            ),
            tilePadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: locale.translate('fin_ops_aid_amount'),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              locale.translate('fin_ops_aid_deduct'),
              style: textStyles.bodySans,
            ),
            value: deduct,
            onChanged: (v) => setSheetState(() => deduct = v),
          ),
          if (registers.isNotEmpty) ...[
            Text(
              locale.translate('fin_ops_register'),
              style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            ExpansibleWidget<CashRegister?>.selection(
              borderRadius: 8.0,
              title: Text(
                selectedRegister?.name ??
                    locale.translate('fin_ops_select_register'),
                style: textStyles.bodySans,
              ),
              items: registers,
              selectedValue: selectedRegister,
              itemLabelBuilder: (r) => r?.name ?? '',
              onSelected: (val) => setSheetState(() => selectedRegister = val),
              cardPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 2,
              ),
              tilePadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 12),
          ],
          ElevatedButton(
            onPressed: () {
              final amt = parseLocalizedNumber(context, amountCtrl.text.trim());
              if (amt == null || amt <= 0 || selectedEmployee == null) return;
              context.read<FinOpsBloc>().add(
                CreateFinancialAidRequested(
                  employeeId: selectedEmployee!.id,
                  amount: amt,
                  deductFromSalary: deduct,
                  registerId: selectedRegister?.id,
                ),
              );
              Navigator.pop(context);
            },
            child: Text(locale.translate('save_to_ledger')),
          ),
        ],
      );
    },
  );
}
