import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../core/localization/language_cubit.dart';
import '../../core/localization/locale_number_format.dart';
import '../../core/theme/theme_extensions.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/bloc/auth_state.dart';
import '../../features/auth/domain/app_access.dart';
import '../../features/fin_ops/bloc/fin_ops_bloc.dart';
import '../../features/fin_ops/bloc/fin_ops_event.dart';
import '../../features/fin_ops/bloc/fin_ops_state.dart';
import '../../features/fin_ops/domain/fin_ops_models.dart';
import '../../features/fin_ops/domain/fin_ops_repository.dart';
import '../widgets/ledger_bottom_sheet.dart';
import '../widgets/ledger_card.dart';
import '../widgets/ledger_collapsing_header.dart';
import '../widgets/ledger_pill.dart';
import '../widgets/expansible_widget.dart';

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
    final respCtrl = TextEditingController(text: 'Ответственный менеджер');

    LedgerBottomSheet.show(
      context: context,
      title: locale.translate('fin_ops_new_encashment'),
      builder: (context, setSheetState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Банк зачисления',
            style: textStyles.bodySans.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          ExpansibleWidget<BankAccount>.selection(
            borderRadius: 8.0,
            title: Text(
              selectedBank?.bankName ?? 'Ориёнбанк',
              style: textStyles.bodySans,
            ),
            items: banks,
            selectedValue: selectedBank,
            itemLabelBuilder: (b) => b.bankName,
            onSelected: (val) {
              setSheetState(() => selectedBank = val);
            },
            cardPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            tilePadding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Сумма инкассации (TJS)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: respCtrl,
            decoration: const InputDecoration(labelText: 'Ответственный ликвидтор'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              final amt = double.tryParse(amountCtrl.text.trim());
              if (amt == null || amt <= 0) return;
              context.read<FinOpsBloc>().add(
                    CreateEncashmentRequested(
                      bankName: selectedBank?.bankName ?? 'Ориёнбанк',
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

  void _showTransferModal(BuildContext context) {
    final locale = context.read<LanguageCubit>();
    final fromCtrl = TextEditingController(text: 'Филиал «Центральный»');
    final toCtrl = TextEditingController(text: 'Филиал «Сомони»');
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
            decoration: const InputDecoration(labelText: 'Откуда (Филиал/Касса)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: toCtrl,
            decoration: const InputDecoration(labelText: 'Куда (Филиал/Касса)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Сумма перевода (TJS)'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              final amt = double.tryParse(amountCtrl.text.trim());
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
            decoration: const InputDecoration(labelText: 'ФИО Сотрудника'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Сумма займа/помощи (TJS)'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              final amt = double.tryParse(amountCtrl.text.trim());
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
    final canManage = authState is AuthAuthenticated &&
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
          ? FloatingActionButton.extended(
              onPressed: () => _showEncashmentModal(context, state.bankAccounts),
              backgroundColor: colors.brand,
              foregroundColor: Colors.white,
              icon: const Icon(TablerIcons.cash_banknote),
              label: Text(
                locale.translate('fin_ops_new_encashment'),
                style: textStyles.bodySans.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Банковские счета компании',
            style: textStyles.h2Sans.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...state.bankAccounts.map(
            (bank) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LedgerCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bank.bankName,
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bank.accountNumber,
                          style: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${oCcy.format(bank.balance)} ${bank.currency}',
                      style: textStyles.h2Sans.copyWith(
                        color: colors.brand,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'История инкассаций',
            style: textStyles.h2Sans.copyWith(fontWeight: FontWeight.bold),
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
                          'Инкассация -> ${enc.bankName}',
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          enc.responsiblePerson,
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
                        fontWeight: FontWeight.bold,
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
              foregroundColor: Colors.white,
              icon: const Icon(TablerIcons.arrows_transfer_up),
              label: Text(
                locale.translate('fin_ops_new_transfer'),
                style: textStyles.bodySans.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
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
                        fontWeight: FontWeight.bold,
                        color: colors.brand,
                      ),
                    ),
                    LedgerPill(
                      text: isPending ? 'В пути' : 'Получен',
                      backgroundColor: isPending
                          ? colors.accentAmber.withValues(alpha: 0.1)
                          : colors.accentGreen.withValues(alpha: 0.1),
                      textColor: isPending ? colors.accentAmber : colors.accentGreen,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${tr.fromBranch} ➔ ${tr.toBranch}',
                  style: textStyles.bodySans,
                ),
                if (isPending && canManage) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          context.read<FinOpsBloc>().add(
                                UpdateTransferStatusRequested(
                                  transferId: tr.id,
                                  status: 'received',
                                ),
                              );
                        },
                        child: const Text('Подтвердить прием'),
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
              foregroundColor: Colors.white,
              icon: const Icon(TablerIcons.heart_handshake),
              label: Text(
                locale.translate('fin_ops_new_aid'),
                style: textStyles.bodySans.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
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
                      aid.employeeName,
                      style: textStyles.h2Sans.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    LedgerPill(
                      text: isActive ? 'Активен' : 'Погашен',
                      backgroundColor: isActive
                          ? colors.accentAmber.withValues(alpha: 0.1)
                          : colors.accentGreen.withValues(alpha: 0.1),
                      textColor: isActive ? colors.accentAmber : colors.accentGreen,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Сумма займа: ${oCcy.format(aid.amount)} TJS'),
                    Text(
                      'Погашено: ${oCcy.format(aid.repaidAmount)} TJS',
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
                        child: const Text('Погасить полностью'),
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
