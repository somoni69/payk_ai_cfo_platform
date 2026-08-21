import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
import '../../../features/fin_ops/domain/fin_ops_models.dart';
import '../../../features/fin_ops/domain/fin_ops_repository.dart';
import '../../../features/permissions/cubit/permissions_cubit.dart';
import '../../../features/permissions/domain/my_permissions.dart';
import '../../assistant/presentation/ledger_ai_assistant.dart';
import '../../../features/assistant/presentation/ledger_advice_panel.dart';
import '../../../presentation/widgets/ledger_card.dart';
import '../../../presentation/widgets/ledger_pill.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../../../presentation/widgets/ledger_collapsing_header.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';
import '../../../presentation/widgets/ledger_spotlight.dart';
import '../../../presentation/widgets/expansible_widget.dart';
import 'cash_transaction_tile.dart';
import 'sales_profit_card.dart';

part 'cash_tabs.dart';
part 'cash_sheets.dart';

/// Точка входа в кассовый модуль с внедрением CashBloc.
class CashScreen extends StatelessWidget {
  const CashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageCubit>();
    try {
      context.read<CashBloc>();
      return const CashView();
    } catch (_) {
      return BlocProvider<CashBloc>(
        create: (context) =>
            CashBloc(context.read<CashRepository>())..add(const LoadCashData()),
        child: const CashView(),
      );
    }
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
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bloc = context.read<CashBloc>();
      if (bloc.state is! CashLoaded) {
        bloc.add(const LoadCashData());
      }
    });
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

  CashOperationFilters _exportFilters() {
    final registerId = int.tryParse(_selectedRegister);
    return CashOperationFilters(
      registerId: _selectedRegister == 'all' ? null : registerId,
      type: _selectedType == 'all' ? null : _selectedType,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
    );
  }

  Future<void> _exportCash(String format) async {
    if (_exporting) return;
    final language = context.read<LanguageCubit>();
    final repo = context.read<CashRepository>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _exporting = true);
    try {
      final bytes = await repo.exportOperations(
        format: format,
        filters: _exportFilters(),
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/cash_operations.$format');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            language.translate(
              format == 'pdf' ? 'cash_export_pdf_ok' : 'cash_export_excel_ok',
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(language.translateMessage(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _importCash() async {
    final language = context.read<LanguageCubit>();
    final repo = context.read<CashRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final cashBloc = context.read<CashBloc>();
    final registers = cashBloc.state is CashLoaded
        ? (cashBloc.state as CashLoaded).registers
        : const <CashRegister>[];
    final registerId =
        int.tryParse(
          _selectedRegister == 'all'
              ? (registers.isNotEmpty ? registers.first.id : '')
              : _selectedRegister,
        ) ??
        0;
    if (registerId <= 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(language.translate('cash_import_need_register')),
        ),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'xls', 'csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(language.translate('cash_import_empty_file'))),
      );
      return;
    }

    try {
      final imported = await repo.importOperations(
        registerId: registerId,
        filename: file.name,
        bytes: bytes,
      );
      if (!mounted) return;
      cashBloc.add(LoadCashData());
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            language.translate('cash_import_ok', params: {'count': imported}),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(language.translateMessage(e.toString()))),
      );
    }
  }

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
                      onPressed: _exporting
                          ? null
                          : () {
                              Navigator.pop(context);
                              _exportCash('xlsx');
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
                      onPressed: _exporting
                          ? null
                          : () {
                              Navigator.pop(context);
                              _exportCash('pdf');
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
                        _importCash();
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

        final loadedState = state is CashLoaded ? state : null;

        Widget? mainFab;
        if (!isViewer && _tabController.index == 0 && loadedState != null) {
          mainFab = FloatingActionButton.extended(
            heroTag: null,
            onPressed: () => _showAddTransactionBottomSheet(
              context,
              authState,
              loadedState.registers,
            ),
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
            icon: const Icon(TablerIcons.plus),
            label: Text(
              language.translate('cash_new_operation_btn'),
              style: textStyles.bodySans.copyWith(
                color: colors.surface,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        } else if (!isViewer &&
            _tabController.index == 1 &&
            loadedState != null) {
          mainFab = FloatingActionButton.extended(
            heroTag: null,
            onPressed: () => _showOpenShiftBottomSheet(
              context,
              loadedState.registers,
            ),
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
            icon: const Icon(TablerIcons.plus),
            label: Text(
              language.translate('cash_open_shift_btn'),
              style: textStyles.bodySans.copyWith(
                color: colors.surface,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }

        return Scaffold(
          floatingActionButtonLocation: kLedgerShellFabLocation,
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const LedgerAiFloatingButton(),
              if (mainFab != null) ...[
                const SizedBox(height: 10),
                mainFab,
              ],
            ],
          ),
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                LedgerCollapsingHeader(
                  title: language.translate('cash_title'),
                  pinned: true,
                  floating: false,
                  snap: false,
                  actions: [
                    IconButton(
                      tooltip: language.translate('cash_filters'),
                      onPressed: loadedState == null
                          ? null
                          : () => _showFiltersSheet(context, loadedState),
                      icon: Badge(
                        isLabelVisible: _hasActiveFilters,
                        smallSize: 8,
                        backgroundColor: colors.brand,
                        child: Icon(
                          TablerIcons.adjustments_horizontal,
                          color: colors.brand,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: language.translate('cash_download_report'),
                      onPressed: () => _showReportDownloadBottomSheet(context),
                      icon: Icon(TablerIcons.download, color: colors.brand),
                    ),
                  ],
                  bottom: LedgerTabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(text: language.translate('cash_tab_operations')),
                      Tab(text: language.translate('cash_tab_shifts')),
                      Tab(text: language.translate('cash_tab_summary')),
                    ],
                  ),
                ),
              ];
            },
            body: loadedState == null
                ? const CashOverviewShimmer()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOperationsTab(context, loadedState, isViewer),
                      _buildShiftsTab(context, loadedState, isViewer),
                      _buildSummaryTab(context, loadedState.summaries),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
