import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/localization/locale_number_format.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/auth/bloc/auth_state.dart';
import '../../../features/auth/domain/app_access.dart';
import '../../../features/cash/bloc/cash_bloc.dart';
import '../../../features/cash/bloc/cash_event.dart';
import '../../../features/cash/bloc/cash_state.dart';
import '../../../features/cash/domain/transaction_model.dart';
import '../../../features/cash/domain/cash_repository.dart';
import '../../../presentation/widgets/ledger_card.dart';
import '../../../presentation/widgets/ledger_pill.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../../../presentation/widgets/ledger_collapsing_header.dart';
import '../../../presentation/widgets/expansible_widget.dart';
import 'cash_transaction_tile.dart';

part 'cash_tabs.dart';
part 'cash_sheets.dart';

/// Точка входа в кассовый модуль с внедрением CashBloc.
class CashScreen extends StatelessWidget {
  const CashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageCubit>();

    return BlocProvider<CashBloc>(
      create: (context) =>
          CashBloc(context.read<CashRepository>())..add(LoadCashData()),
      child: const CashView(),
    );
  }
}

class CashView extends StatefulWidget {
  const CashView({super.key});

  @override
  State<CashView> createState() => _CashViewState();
}

class _CashViewState extends State<CashView>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late final TabController _tabController;

  String _selectedType = 'all';
  String _selectedPaymentMethod = 'all';
  String _selectedRegister = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshCash(BuildContext context) {
    final completion = Completer<void>();
    context.read<CashBloc>().add(LoadCashData(completion: completion));
    return completion.future;
  }

  void _rebuild([VoidCallback? fn]) => setState(fn ?? () {});

  void _showReportDownloadBottomSheet(BuildContext context) {
    final language = context.read<LanguageCubit>();
    final colors = context.colors;
    final textStyles = context.textStyles;

    LedgerBottomSheet.show(
      context: context,
      title: language.translate('cash_download_report'),
      builder: (context, setSheetState) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                language.translate('cash_export_choose_format'),
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              language.translate('cash_export_excel_ok'),
                            ),
                          ),
                        );
                      },
                      icon: Icon(
                        TablerIcons.file_spreadsheet,
                        color: colors.accentGreen,
                        size: 18,
                      ),
                      label: Text(language.translate('cash_export_excel')),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              language.translate('cash_export_pdf_ok'),
                            ),
                          ),
                        );
                      },
                      icon: Icon(
                        TablerIcons.file_text,
                        color: colors.accentRed,
                        size: 18,
                      ),
                      label: Text(language.translate('cash_export_pdf')),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              language.translate('cash_import_started'),
                            ),
                          ),
                        );
                      },
                      icon: Icon(
                        TablerIcons.upload,
                        color: colors.brand,
                        size: 18,
                      ),
                      label: Text(language.translate('cash_import')),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    final authState = context.watch<AuthBloc>().state;
    final isViewer =
        authState is! AuthAuthenticated ||
        !authState.role.canManage(AppCapability.cash);

    return BlocConsumer<CashBloc, CashState>(
      listener: (context, state) {
        if (state is CashLoaded && state.errorMessage != null) {
          final raw = state.errorMessage!;
          final isError =
              raw.startsWith('cash_err_') ||
              raw.startsWith('error_') ||
              raw.startsWith('cash_shift_closed_diff');
          final isSuccess =
              raw.startsWith('cash_shift_closed_') &&
              !raw.startsWith('cash_shift_closed_diff');
          String text;
          if (raw.startsWith('cash_shift_closed_diff::')) {
            final parts = raw.split('::');
            text = language.translate(
              'cash_shift_closed_diff',
              params: {
                'diff': parts.length > 1 ? parts[1] : '',
                'expected': parts.length > 2 ? parts[2] : '',
              },
            );
          } else {
            text = language.translateMessage(raw);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                text,
                style: textStyles.bodySans.copyWith(color: colors.surface),
              ),
              backgroundColor: isError
                  ? colors.accentRed
                  : (isSuccess ? colors.accentGreen : colors.textPrimary),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is CashLoading) {
          return Scaffold(
            backgroundColor: colors.background,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (state is CashError) {
          return Scaffold(
            backgroundColor: colors.background,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      TablerIcons.alert_triangle,
                      color: colors.accentRed,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      language.translateMessage(state.message),
                      style: textStyles.bodySans,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.read<CashBloc>().add(LoadCashData());
                      },
                      child: Text(language.translate('common_retry')),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (state is CashLoaded) {
          return Scaffold(
            floatingActionButton: !isViewer && _tabController.index == 0
                ? FloatingActionButton.extended(
                    onPressed: () => _showAddTransactionBottomSheet(
                      context,
                      authState,
                      state.registers,
                    ),
                    backgroundColor: colors.brand,
                    foregroundColor: Colors.white,
                    icon: const Icon(TablerIcons.plus),
                    label: Text(
                      language.translate('cash_new_operation_btn'),
                      style: textStyles.bodySans.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : (!isViewer && _tabController.index == 1
                      ? FloatingActionButton.extended(
                          onPressed: () => _showOpenShiftBottomSheet(
                            context,
                            state.registers,
                          ),
                          backgroundColor: colors.brand,
                          foregroundColor: Colors.white,
                          icon: const Icon(TablerIcons.plus),
                          label: Text(
                            language.translate('cash_open_shift_btn'),
                            style: textStyles.bodySans.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      : null),
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  LedgerCollapsingHeader(
                    title: language.translate('cash_title'),
                    pinned: true,
                    floating: true,
                    snap: true,
                    actions: [
                      OutlinedButton.icon(
                        onPressed: () =>
                            _showReportDownloadBottomSheet(context),
                        icon: const Icon(TablerIcons.download, size: 16),
                        label: Text(
                          language.translate('cash_download_report'),
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                    bottom: TabBar(
                      controller: _tabController,
                      labelColor: colors.brand,
                      unselectedLabelColor: colors.textSecondary,
                      indicatorColor: colors.brand,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: colors.border,
                      labelStyle: textStyles.bodySans.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      unselectedLabelStyle: textStyles.bodySans.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                      tabs: [
                        Tab(text: language.translate('cash_tab_operations')),
                        Tab(text: language.translate('cash_tab_shifts')),
                        Tab(text: language.translate('cash_tab_summary')),
                      ],
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildOperationsTab(context, state),
                  _buildShiftsTab(context, state, isViewer),
                  _buildSummaryTab(context, state.summaries),
                ],
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
