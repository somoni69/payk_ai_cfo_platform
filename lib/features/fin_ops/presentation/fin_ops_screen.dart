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
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../../../presentation/widgets/ledger_card.dart';
import '../../../presentation/widgets/ledger_collapsing_header.dart';
import '../../../presentation/widgets/ledger_pill.dart';
import '../../../presentation/widgets/expansible_widget.dart';

class FinOpsScreen extends StatelessWidget {
  const FinOpsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FinOpsBloc>(
      create: (context) =>
          FinOpsBloc(context.read<FinOpsRepository>())
            ..add(const LoadFinOpsData()),
      child: const FinOpsView(),
    );
  }
}

class FinOpsView extends StatefulWidget {
  const FinOpsView({super.key});

  @override
  State<FinOpsView> createState() => _FinOpsViewState();
}

class _FinOpsViewState extends State<FinOpsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showEncashmentModal(BuildContext context, List<BankAccount> banks) {
    final locale = context.read<LanguageCubit>();
    final textStyles = context.textStyles;

    BankAccount? selectedBank = banks.isNotEmpty ? banks.first : null;
    final amountCtrl = TextEditingController();
    final respCtrl = TextEditingController();

    LedgerBottomSheet.show(
      context: context,
      title: locale.translate('fin_ops_new_encashment'),
      builder: (context, setSheetState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            locale.translate('fin_ops_bank_credit'),
            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          ExpansibleWidget<BankAccount>.selection(
            borderRadius: 8.0,
            title: Text(
              locale.translateMessage(
                selectedBank?.bankName ?? 'mock_bank_oriyon',
              ),
              style: textStyles.bodySans,
            ),
            items: banks,
            selectedValue: selectedBank,
            itemLabelBuilder: (b) => locale.translateMessage(b.bankName),
            onSelected: (val) {
              setSheetState(() => selectedBank = val);
            },
            cardPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
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
          const SizedBox(height: 12),
          TextField(
            controller: respCtrl,
            decoration: InputDecoration(
              labelText: locale.translate('fin_ops_responsible'),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              final amt = parseLocalizedNumber(context, amountCtrl.text.trim());
              if (amt == null || amt <= 0) return;
              context.read<FinOpsBloc>().add(
                CreateEncashmentRequested(
                  bankName: selectedBank?.bankName ?? 'mock_bank_oriyon',
                  amount: amt,
                  responsiblePerson: respCtrl.text.trim(),
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

  void _showCreateBankSheet(BuildContext context) {
    final locale = context.read<LanguageCubit>();
    final colors = context.colors;
    final textStyles = context.textStyles;
    final nameCtrl = TextEditingController();

    LedgerBottomSheet.show(
      context: context,
      title: locale.translate('fin_ops_new_bank'),
      builder: (context, setSheetState) => TextField(
        controller: nameCtrl,
        style: textStyles.bodySans,
        decoration: InputDecoration(
          labelText: locale.translate('fin_ops_bank_name'),
        ),
      ),
      footerBuilder: (context, setSheetState) {
        return SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              this.context.read<FinOpsBloc>().add(CreateBankRequested(name));
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.brand,
              foregroundColor: colors.surface,
              elevation: 0,
            ),
            child: Text(locale.translate('common_create')),
          ),
        );
      },
    );
  }

  void _showTransferModal(BuildContext context) {
    final locale = context.read<LanguageCubit>();
    final fromCtrl = TextEditingController(
      text: locale.translate('mock_branch_central'),
    );
    final toCtrl = TextEditingController(
      text: locale.translate('mock_branch_somoni'),
    );
    final amountCtrl = TextEditingController();

    LedgerBottomSheet.show(
      context: context,
      title: locale.translate('fin_ops_new_transfer'),
      builder: (context, setSheetState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: fromCtrl,
            decoration: InputDecoration(
              labelText: locale.translate('fin_ops_from_branch'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: toCtrl,
            decoration: InputDecoration(
              labelText: locale.translate('fin_ops_to_branch'),
            ),
          ),
          const SizedBox(height: 12),
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
              if (amt == null || amt <= 0) return;
              context.read<FinOpsBloc>().add(
                CreateStoreTransferRequested(
                  fromBranch: fromCtrl.text.trim(),
                  toBranch: toCtrl.text.trim(),
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

  void _showAidModal(BuildContext context) {
    final locale = context.read<LanguageCubit>();
    final empCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    LedgerBottomSheet.show(
      context: context,
      title: locale.translate('fin_ops_new_aid'),
      builder: (context, setSheetState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: empCtrl,
            decoration: InputDecoration(
              labelText: locale.translate('fin_ops_employee_name'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: locale.translate('fin_ops_aid_amount'),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              final amt = parseLocalizedNumber(context, amountCtrl.text.trim());
              if (amt == null || amt <= 0 || empCtrl.text.trim().isEmpty) {
                return;
              }
              context.read<FinOpsBloc>().add(
                CreateFinancialAidRequested(
                  employeeName: empCtrl.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final locale = context.watch<LanguageCubit>();
    final authState = context.watch<AuthBloc>().state;
    final canManage =
        authState is AuthAuthenticated &&
        authState.role.canManage(AppCapability.finOps);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            LedgerCollapsingHeader(
              title: locale.translate('fin_ops_title'),
              pinned: true,
              floating: true,
              snap: true,
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: colors.brand,
                labelColor: colors.brand,
                unselectedLabelColor: colors.textSecondary,
                tabs: [
                  Tab(text: locale.translate('fin_ops_tab_banks')),
                  Tab(text: locale.translate('fin_ops_tab_transfers')),
                  Tab(text: locale.translate('fin_ops_tab_aid')),
                ],
              ),
            ),
          ];
        },
        body: BlocBuilder<FinOpsBloc, FinOpsState>(
          builder: (context, state) {
            if (state is FinOpsLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is FinOpsError) {
              return Center(child: Text(state.message));
            }
            if (state is FinOpsLoaded) {
              return TabBarView(
                controller: _tabController,
                children: [
                  _buildBanksTab(context, state, canManage),
                  _buildTransfersTab(context, state, canManage),
                  _buildAidTab(context, state, canManage),
                ],
              );
            }
            return const SizedBox();
          },
        ),
      ),
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

    return Scaffold(
      floatingActionButton: canManage
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'fin_ops_add_bank',
                  onPressed: () => _showCreateBankSheet(context),
                  backgroundColor: colors.surface,
                  foregroundColor: colors.brand,
                  elevation: 0,
                  highlightElevation: 0,
                  focusElevation: 0,
                  hoverElevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colors.border),
                  ),
                  icon: const Icon(TablerIcons.building_bank),
                  label: Text(
                    locale.translate('fin_ops_new_bank'),
                    style: textStyles.bodySans.copyWith(
                      color: colors.brand,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.extended(
                  heroTag: 'fin_ops_encashment',
                  onPressed: () =>
                      _showEncashmentModal(context, state.bankAccounts),
                  backgroundColor: colors.brand,
                  foregroundColor: colors.surface,
                  elevation: 0,
                  highlightElevation: 0,
                  focusElevation: 0,
                  hoverElevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colors.brand),
                  ),
                  icon: const Icon(TablerIcons.cash_banknote),
                  label: Text(
                    locale.translate('fin_ops_new_encashment'),
                    style: textStyles.bodySans.copyWith(
                      color: colors.surface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            locale.translate('fin_ops_bank_balances'),
            style: textStyles.h2Sans.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          ...state.bankAccounts.map(
            (bank) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LedgerCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.read<LanguageCubit>().translateMessage(
                              bank.bankName,
                            ),
                            style: textStyles.bodySans.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          LedgerPill(
                            text: bank.isActive
                                ? locale.translate('status_active')
                                : locale.translate('hr_status_inactive'),
                            backgroundColor: bank.isActive
                                ? colors.accentGreen.withValues(alpha: 0.1)
                                : colors.surfaceNested,
                            textColor: bank.isActive
                                ? colors.accentGreen
                                : colors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                    if (canManage && bank.isActive)
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
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            locale.translate('fin_ops_encashment_history'),
            style: textStyles.h2Sans.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          ...state.encashments.map(
            (enc) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LedgerCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.read<LanguageCubit>().translate(
                            'fin_ops_encashment_to',
                            params: {
                              'bank': context
                                  .read<LanguageCubit>()
                                  .translateMessage(enc.bankName),
                            },
                          ),
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          context.read<LanguageCubit>().translateMessage(
                            enc.responsiblePerson,
                          ),
                          style: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '+${oCcy.format(enc.amount)} TJS',
                      style: textStyles.bodySans.copyWith(
                        color: colors.accentGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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

    return Scaffold(
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showTransferModal(context),
              backgroundColor: colors.brand,
              foregroundColor: colors.surface,
              elevation: 0,
              highlightElevation: 0,
              focusElevation: 0,
              hoverElevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: colors.brand),
              ),
              icon: const Icon(TablerIcons.arrows_transfer_up),
              label: Text(
                locale.translate('fin_ops_new_transfer'),
                style: textStyles.bodySans.copyWith(
                  color: colors.surface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          : null,
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: state.storeTransfers.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final tr = state.storeTransfers[index];
          final isPending = tr.status == 'pending';

          return LedgerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${oCcy.format(tr.amount)} TJS',
                      style: textStyles.h2Sans.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colors.brand,
                      ),
                    ),
                    LedgerPill(
                      text: isPending
                          ? context.read<LanguageCubit>().translate(
                              'fin_ops_status_pending',
                            )
                          : context.read<LanguageCubit>().translate(
                              'fin_ops_status_received',
                            ),
                      backgroundColor: isPending
                          ? colors.accentAmber.withValues(alpha: 0.1)
                          : colors.accentGreen.withValues(alpha: 0.1),
                      textColor: isPending
                          ? colors.accentAmber
                          : colors.accentGreen,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${context.read<LanguageCubit>().translateMessage(tr.fromBranch)} ➔ ${context.read<LanguageCubit>().translateMessage(tr.toBranch)}',
                  style: textStyles.bodySans,
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
                      OutlinedButton(
                        onPressed: () {
                          context.read<FinOpsBloc>().add(
                            UpdateTransferStatusRequested(
                              transferId: tr.id,
                              status: 'received',
                            ),
                          );
                        },
                        child: Text(
                          context.read<LanguageCubit>().translate(
                            'fin_ops_confirm_receive',
                          ),
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

    return Scaffold(
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showAidModal(context),
              backgroundColor: colors.brand,
              foregroundColor: colors.surface,
              elevation: 0,
              highlightElevation: 0,
              focusElevation: 0,
              hoverElevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: colors.brand),
              ),
              icon: const Icon(TablerIcons.heart_handshake),
              label: Text(
                locale.translate('fin_ops_new_aid'),
                style: textStyles.bodySans.copyWith(
                  color: colors.surface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          : null,
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: state.financialAids.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final aid = state.financialAids[index];
          final isActive = aid.status == 'active';

          return LedgerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.read<LanguageCubit>().translateMessage(
                        aid.employeeName,
                      ),
                      style: textStyles.h2Sans.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    LedgerPill(
                      text: isActive
                          ? locale.translate('fin_ops_status_active')
                          : locale.translate('fin_ops_status_repaid'),
                      backgroundColor: isActive
                          ? colors.accentAmber.withValues(alpha: 0.1)
                          : colors.accentGreen.withValues(alpha: 0.1),
                      textColor: isActive
                          ? colors.accentAmber
                          : colors.accentGreen,
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
                    ),
                    Text(
                      locale.translate(
                        'fin_ops_repaid_amount',
                        params: {'amount': oCcy.format(aid.repaidAmount)},
                      ),
                      style: textStyles.captionSans.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (isActive && canManage) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          context.read<FinOpsBloc>().add(
                            RepayFinancialAidRequested(
                              aidId: aid.id,
                              amount: aid.remainingAmount,
                            ),
                          );
                        },
                        child: Text(locale.translate('fin_ops_repay_action')),
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
}
