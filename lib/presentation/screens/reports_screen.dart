import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../core/localization/language_cubit.dart';
import '../../core/localization/locale_number_format.dart';
import '../../core/theme/theme_extensions.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/bloc/auth_state.dart';
import '../../features/auth/domain/app_access.dart';
import '../../features/branches/domain/branches_repository.dart';
import '../../features/reports/bloc/reports_bloc.dart';
import '../../features/reports/bloc/reports_event.dart';
import '../../features/reports/bloc/reports_state.dart';
import '../../features/reports/domain/reports_repository.dart';
import '../widgets/expansible_widget.dart';
import '../widgets/ledger_bottom_sheet.dart';
import '../widgets/ledger_card.dart';
import '../widgets/ledger_collapsing_header.dart';
import '../widgets/ledger_pill.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ReportsBloc>(
      create: (context) =>
          ReportsBloc(context.read<ReportsRepository>())
            ..add(const LoadReportsData()),
      child: const ReportsView(),
    );
  }
}

class ReportsView extends StatelessWidget {
  const ReportsView({super.key});

  Future<void> _showReportModal(BuildContext context) async {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.read<LanguageCubit>();
    final branchesRepo = context.read<BranchesRepository>();

    List<String> branchNames = [
      'Филиал «Центральный»',
      'Филиал «Сомони»',
      'Точка «Худжанд»',
    ];

    try {
      final branches = await branchesRepo.getBranches();
      if (branches.isNotEmpty) {
        final activeNames = branches
            .where((b) => b.isActive)
            .map((b) => b.name)
            .toList();
        if (activeNames.isNotEmpty) {
          branchNames = activeNames;
        } else {
          branchNames = branches.map((b) => b.name).toList();
        }
      }
    } catch (_) {}

    if (!context.mounted) return;

    String selectedBranch = branchNames.first;
    final revCtrl = TextEditingController();
    final expCtrl = TextEditingController();
    final cashCtrl = TextEditingController();
    final bankCtrl = TextEditingController();
    final commCtrl = TextEditingController();

    try {
      await LedgerBottomSheet.show(
        context: context,
        title: locale.translate('reports_new'),
        builder: (context, setSheetState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Филиал / Точка',
              style: textStyles.captionSans.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            ExpansibleWidget<String>.selection(
              cardPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 0,
              ),
              tilePadding: const EdgeInsets.symmetric(horizontal: 8),
              title: Text(
                selectedBranch,
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              items: branchNames,
              selectedValue: selectedBranch,
              itemLabelBuilder: (b) => b,
              onSelected: (val) {
                setSheetState(() => selectedBranch = val);
              },
            ),
            const SizedBox(height: 14),

            TextField(
              controller: revCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: textStyles.bodySans,
              decoration: const InputDecoration(
                labelText: 'Выручка за день (TJS)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: expCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: textStyles.bodySans,
              decoration: const InputDecoration(
                labelText: 'Расходы за день (TJS)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: cashCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: textStyles.bodySans,
              decoration: const InputDecoration(
                labelText: 'Остаток в кассе (TJS)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bankCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: textStyles.bodySans,
              decoration: const InputDecoration(
                labelText: 'Остаток в банке (TJS)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: commCtrl,
              style: textStyles.bodySans,
              decoration: const InputDecoration(
                labelText: 'Комментарии / Замечания',
              ),
            ),
          ],
        ),
        footerBuilder: (context, setSheetState) {
          return SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                final rev =
                    parseLocalizedNumber(context, revCtrl.text.trim()) ?? 0.0;
                final exp =
                    parseLocalizedNumber(context, expCtrl.text.trim()) ?? 0.0;
                final cash =
                    parseLocalizedNumber(context, cashCtrl.text.trim()) ?? 0.0;
                final bank =
                    parseLocalizedNumber(context, bankCtrl.text.trim()) ?? 0.0;

                if (rev <= 0) return;

                context.read<ReportsBloc>().add(
                  CreateDailyReportRequested(
                    branchName: selectedBranch,
                    revenue: rev,
                    expenses: exp,
                    cashEndBalance: cash,
                    bankEndBalance: bank,
                    comments: commCtrl.text.trim(),
                  ),
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.brand,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                locale.translate('save_to_ledger'),
                style: textStyles.bodySans.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          );
        },
      );
    } finally {
      revCtrl.dispose();
      expCtrl.dispose();
      cashCtrl.dispose();
      bankCtrl.dispose();
      commCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();
    final authState = context.watch<AuthBloc>().state;
    final canManage =
        authState is AuthAuthenticated &&
        authState.role.canManage(AppCapability.reports);
    final oCcy = localizedDecimalFormat(context);

    return Scaffold(
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showReportModal(context),
              backgroundColor: colors.brand,
              foregroundColor: Colors.white,
              icon: const Icon(TablerIcons.report_analytics),
              label: Text(
                locale.translate('reports_new'),
                style: textStyles.bodySans.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            LedgerCollapsingHeader(
              title: locale.translate('reports_title'),
              pinned: true,
              floating: true,
              snap: true,
            ),
          ];
        },
        body: BlocBuilder<ReportsBloc, ReportsState>(
          builder: (context, state) {
            if (state is ReportsLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is ReportsError) {
              return Center(child: Text(state.message));
            }
            if (state is ReportsLoaded) {
              return RefreshIndicator(
                onRefresh: () async {
                  context.read<ReportsBloc>().add(
                    const LoadReportsData(forceRefresh: true),
                  );
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Сводные метрики P&L
                    Row(
                      children: [
                        Expanded(
                          child: LedgerCard(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  locale.translate('reports_revenue'),
                                  style: textStyles.captionSans.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${oCcy.format(state.totalRevenue)} TJS',
                                  style: textStyles.h2Sans.copyWith(
                                    color: colors.accentGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: LedgerCard(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  locale.translate('reports_expenses'),
                                  style: textStyles.captionSans.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${oCcy.format(state.totalExpenses)} TJS',
                                  style: textStyles.h2Sans.copyWith(
                                    color: colors.accentRed,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LedgerCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            locale.translate('reports_net_profit'),
                            style: textStyles.bodySans.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${oCcy.format(state.totalNetProfit)} TJS',
                            style: textStyles.h1Sans.copyWith(
                              color: colors.brand,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Ежедневные отчеты смен',
                      style: textStyles.h2Sans.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...state.dailyReports.map(
                      (rep) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: LedgerCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      rep.branchName,
                                      style: textStyles.h2Sans.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  LedgerPill(
                                    text: rep.status == 'verified'
                                        ? 'Проверен'
                                        : 'Отправлен',
                                    backgroundColor: rep.status == 'verified'
                                        ? colors.accentGreen.withValues(
                                            alpha: 0.1,
                                          )
                                        : colors.accentAmber.withValues(
                                            alpha: 0.1,
                                          ),
                                    textColor: rep.status == 'verified'
                                        ? colors.accentGreen
                                        : colors.accentAmber,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 12,
                                runSpacing: 4,
                                alignment: WrapAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${locale.translate('reports_revenue')}: ${oCcy.format(rep.revenue)} TJS',
                                    style: textStyles.bodySans.copyWith(
                                      color: colors.accentGreen,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '${locale.translate('reports_expenses')}: ${oCcy.format(rep.expenses)} TJS',
                                    style: textStyles.bodySans.copyWith(
                                      color: colors.accentRed,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Чистая прибыль: ${oCcy.format(rep.netProfit)} TJS',
                                style: textStyles.bodySans.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (rep.comments.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  rep.comments,
                                  style: textStyles.captionSans.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox();
          },
        ),
      ),
    );
  }
}
