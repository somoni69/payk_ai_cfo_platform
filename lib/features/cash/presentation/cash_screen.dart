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
import '../../../core/network/user_facing_error.dart';
import '../../../core/models/ui_feedback.dart';
import '../../../core/theme/ledger_layout.dart';
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
import '../../../presentation/widgets/ledger_barcode_scanner.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../../../presentation/widgets/ledger_card.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';
import '../../../presentation/widgets/expansible_widget.dart';
import 'cash_transaction_tile.dart';
import 'sales_profit_card.dart';

part 'cash_tabs.dart';
part 'cash_sheets.dart';
part 'cash_pos.dart';

enum CashSection { operations, shifts, summary, pos, onec, edits }

String _cashSectionTitle(LanguageCubit language, CashSection section) {
  return language.translate(switch (section) {
    CashSection.operations => 'cash_tab_operations',
    CashSection.shifts => 'cash_tab_shifts',
    CashSection.summary => 'cash_tab_summary',
    CashSection.pos => 'cash_tab_pos',
    CashSection.onec => 'cash_tab_onec_kkm',
    CashSection.edits => 'cash_tab_edits',
  });
}

bool _seesPosEdits(BuildContext context) {
  final auth = context.read<AuthBloc>().state;
  if (auth is! AuthAuthenticated) return false;
  return auth.role == UserRole.owner || auth.role == UserRole.director;
}

void _openCashSection(BuildContext context, CashSection section) {
  final bloc = context.read<CashBloc>();
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: CashSectionScreen(section: section),
      ),
    ),
  );
}

mixin _CashViewMixin<T extends StatefulWidget> on State<T> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedType = 'all';
  String _selectedPaymentMethod = 'all';
  String _selectedRegister = 'all';
  String _selectedCashier = 'all';
  List<CashierLookup> _cashiers = const [];
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _exporting = false;

  SearchFilterChanged _filterEvent({String? query}) {
    return SearchFilterChanged(
      query: query ?? _searchController.text,
      filterType: _selectedType,
      paymentMethod: _selectedPaymentMethod,
      registerId: _selectedRegister,
      cashierId: _selectedCashier,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshCash(BuildContext context) {
    final bloc = context.read<CashBloc>();
    bloc.add(const LoadCashData());
    return bloc.stream.firstWhere((state) => state is! CashLoading);
  }

  void _rebuild([VoidCallback? fn]) {
    if (mounted) setState(fn ?? () {});
  }

  CashOperationFilters _exportFilters() {
    final registerId = int.tryParse(_selectedRegister);
    final cashierId = int.tryParse(_selectedCashier);
    return CashOperationFilters(
      registerId: _selectedRegister == 'all' ? null : registerId,
      type: _selectedType == 'all' ? null : _selectedType,
      paymentMethod: _selectedPaymentMethod == 'all'
          ? null
          : _selectedPaymentMethod,
      cashierId: _selectedCashier == 'all' ? null : cashierId,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      query: _searchController.text,
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
}

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

class _CashViewState extends State<CashView> with _CashViewMixin {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bloc = context.read<CashBloc>();
      if (bloc.state is! CashLoaded) {
        bloc.add(const LoadCashData());
      }
    });
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
      listenWhen: (previous, current) =>
          current is CashLoaded &&
          current.feedback != null &&
          (previous is! CashLoaded || previous.feedback != current.feedback),
      buildWhen: (previous, current) {
        if (previous.runtimeType != current.runtimeType) return true;
        if (previous is CashLoaded && current is CashLoaded) {
          return previous.activeShift != current.activeShift ||
              previous.transactions != current.transactions ||
              previous.filteredTransactions != current.filteredTransactions ||
              previous.registers != current.registers ||
              previous.dateFrom != current.dateFrom ||
              previous.dateTo != current.dateTo ||
              previous.registerId != current.registerId ||
              previous.filterType != current.filterType ||
              previous.paymentMethod != current.paymentMethod ||
              previous.query != current.query;
        }
        return true;
      },
      listener: (context, state) {
        if (state is CashLoaded && state.feedback != null) {
          final fb = state.feedback!;
          String text;
          bool isError = false;
          if (fb is ShiftClosedFeedback) {
            isError = fb.diff != 0;
            text = language.translate(
              'cash_shift_closed_diff',
              params: {
                'diff': fb.diffFormatted,
                'expected': fb.expectedFormatted,
              },
            );
          } else if (fb is LocalizedFeedback) {
            isError =
                fb.translationKey.startsWith('cash_err_') ||
                fb.translationKey.startsWith('error_');
            text = language.translate(fb.translationKey, params: fb.params);
          } else {
            isError =
                fb.translationKey.startsWith('cash_err_') ||
                fb.translationKey.startsWith('error_');
            text = language.translateMessage(fb.translationKey);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                text,
                style: textStyles.bodySans.copyWith(color: colors.surface),
              ),
              backgroundColor: isError
                  ? colors.accentRed
                  : (fb.translationKey.startsWith('cash_shift_closed_')
                        ? colors.accentGreen
                        : colors.accentAmber),
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

        return Scaffold(
          backgroundColor: colors.background,
          floatingActionButtonLocation: kLedgerShellFabLocation,
          floatingActionButton: const LedgerAiFloatingButton(),
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  title: Text(
                    language.translate('cash_title'),
                    style: textStyles.h2Sans.copyWith(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  pinned: true,
                  floating: false,
                  backgroundColor: colors.surface,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
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
                    const SizedBox(width: 4),
                  ],
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(1),
                    child: Container(height: 1, color: colors.border),
                  ),
                ),
              ];
            },
            body: loadedState == null
                ? const CashOverviewShimmer()
                : _buildCashOverviewHub(
                    context,
                    loadedState,
                    isViewer,
                    authState,
                  ),
          ),
        );
      },
    );
  }

  Widget _buildCashOverviewHub(
    BuildContext context,
    CashLoaded state,
    bool isViewer,
    AuthState authState,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final shift = state.activeShift;
    final isOpen = shift != null && shift.isOpen;
    final totalOps = state.transactions.length;
    final openShiftsCount = state.shifts.where((s) => s.isOpen).length;
    final totalRegisters = state.summaries.length;

    final recentTransactions = state.transactions.take(5).toList();

    return RefreshIndicator(
      onRefresh: () => _refreshCash(context),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + kLiquidNavClearance,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Shift & Cash Hero Balance Card
            _buildShiftHero(context, state, isViewer),
            const SizedBox(height: 12),

            // 2. Attention Card (Active Shift status)
            InkWell(
              onTap: () => _openCashSection(context, CashSection.shifts),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isOpen
                        ? colors.accentGreen.withValues(alpha: 0.4)
                        : colors.accentAmber.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isOpen
                            ? colors.accentGreen.withValues(alpha: 0.1)
                            : colors.accentAmber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isOpen
                            ? TablerIcons.circle_check
                            : TablerIcons.clock_pause,
                        color: isOpen ? colors.accentGreen : colors.accentAmber,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isOpen
                                ? language.translate('cash_shift_open')
                                : language.translate('cash_shift_closed'),
                            style: textStyles.bodySans.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isOpen
                                ? '${shift.registerName ?? language.translate('cash_default_register')} • ${formatLocalizedDateTime(context, shift.openedAt, style: LocalizedDateTimeStyle.time)}'
                                : language.translate(
                                    'cash_shift_operations_blocked',
                                  ),
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
            const SizedBox(height: 10),

            // 3. Quick Action Button (Full-width)
            // 3. Quick Action Button (Matches Hero shift button style)
            if (!isViewer) ...[
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () => _showAddTransactionBottomSheet(
                    context,
                    authState,
                    state.registers,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.brand,
                    foregroundColor: colors.surface,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(TablerIcons.plus, size: 17),
                  label: Text(
                    language.translate('cash_new_operation_btn'),
                    style: textStyles.bodySans.copyWith(
                      color: colors.surface,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            if (!isViewer) ...[
              _buildHubSectionCard(
                context: context,
                icon: TablerIcons.scan,
                title: language.translate('cash_tab_pos'),
                subtitle: language.translate('cash_tab_pos_hint'),
                onTap: () => _openCashSection(context, CashSection.pos),
              ),
              const SizedBox(height: 10),
            ],

            LedgerPairRow(
              left: _buildHubSectionCard(
                context: context,
                icon: TablerIcons.receipt,
                title: language.translate('cash_tab_operations'),
                subtitle: '$totalOps операций',
                onTap: () => _openCashSection(context, CashSection.operations),
              ),
              right: _buildHubSectionCard(
                context: context,
                icon: TablerIcons.clock_hour_4,
                title: language.translate('cash_tab_shifts'),
                subtitle: isOpen
                    ? 'Смена открыта'
                    : '$openShiftsCount акт. смен',
                onTap: () => _openCashSection(context, CashSection.shifts),
              ),
            ),
            const SizedBox(height: 10),
            LedgerPairRow(
              left: _buildHubSectionCard(
                context: context,
                icon: TablerIcons.building_bank,
                title: language.translate('cash_tab_summary'),
                subtitle: '$totalRegisters касс',
                onTap: () => _openCashSection(context, CashSection.summary),
              ),
              right: _buildHubSectionCard(
                context: context,
                icon: TablerIcons.device_desktop_analytics,
                title: language.translate('cash_tab_onec_kkm'),
                subtitle: language.translate('cash_tab_onec_kkm_hint'),
                onTap: () => _openCashSection(context, CashSection.onec),
              ),
            ),
            if (_seesPosEdits(context)) ...[
              const SizedBox(height: 10),
              _buildHubSectionCard(
                context: context,
                icon: TablerIcons.receipt_off,
                title: language.translate('cash_tab_edits'),
                subtitle: language.translate('cash_tab_edits_hint'),
                onTap: () => _openCashSection(context, CashSection.edits),
              ),
            ],
            const SizedBox(height: 10),

            // 5. Recent Activity Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  language.translate('cash_tab_operations'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: colors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      _openCashSection(context, CashSection.operations),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    children: [
                      Text(
                        language.translate('common_view_all'),
                        style: textStyles.captionSans.copyWith(
                          color: colors.brand,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        TablerIcons.arrow_right,
                        size: 14,
                        color: colors.brand,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // 6. Recent Activity List
            if (recentTransactions.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 28,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Center(
                  child: Text(
                    language.translate('cash_operations_empty'),
                    style: textStyles.captionSans.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              )
            else
              ...recentTransactions.map(
                (tx) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: CashTransactionTile(
                    transaction: tx,
                    onEdit: null,
                    onDelete: null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHubSectionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
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
          width: double.infinity,
          constraints: BoxConstraints(
            minHeight: context.layout.hubTileMinHeight,
          ),
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

class CashSectionScreen extends StatefulWidget {
  final CashSection section;
  const CashSectionScreen({super.key, required this.section});

  @override
  State<CashSectionScreen> createState() => _CashSectionScreenState();
}

class _CashSectionScreenState extends State<CashSectionScreen>
    with _CashViewMixin {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final authState = context.watch<AuthBloc>().state;
    final isViewer =
        authState is! AuthAuthenticated ||
        !authState.role.canManage(AppCapability.cash);

    return BlocBuilder<CashBloc, CashState>(
      buildWhen: (previous, current) {
        if (previous.runtimeType != current.runtimeType) return true;
        if (previous is CashLoaded && current is CashLoaded) {
          return switch (widget.section) {
            CashSection.operations =>
              previous.filteredTransactions != current.filteredTransactions ||
                  previous.dateFrom != current.dateFrom ||
                  previous.dateTo != current.dateTo ||
                  previous.filterType != current.filterType ||
                  previous.paymentMethod != current.paymentMethod ||
                  previous.query != current.query,
            CashSection.shifts =>
              previous.activeShift != current.activeShift ||
                  previous.shifts != current.shifts ||
                  previous.registers != current.registers,
            CashSection.summary => previous.summaries != current.summaries,
            CashSection.pos => previous.registers != current.registers,
            CashSection.onec => previous.transactions != current.transactions,
            CashSection.edits => false,
          };
        }
        return true;
      },
      builder: (context, state) {
        if (state is! CashLoaded) {
          return Scaffold(
            backgroundColor: colors.background,
            appBar: AppBar(
              backgroundColor: colors.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: const BackButton(),
              title: Text(
                _cashSectionTitle(language, widget.section),
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
            body: switch (widget.section) {
              CashSection.pos => const CashPosShimmer(),
              CashSection.onec => const CashOnecShimmer(),
              CashSection.shifts => const CashShiftsShimmer(),
              CashSection.summary => const CashSummaryShimmer(),
              CashSection.edits => const LedgerListShimmer(itemCount: 6),
              CashSection.operations => const LedgerListShimmer(itemCount: 6),
            },
          );
        }

        Widget? fab;
        if (!isViewer) {
          if (widget.section == CashSection.operations) {
            fab = FloatingActionButton.extended(
              heroTag: 'cash_op_fab',
              onPressed: () => _showAddTransactionBottomSheet(
                context,
                authState,
                state.registers,
              ),
              backgroundColor: colors.brand,
              foregroundColor: colors.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
          } else if (widget.section == CashSection.shifts) {
            fab = FloatingActionButton.extended(
              heroTag: 'cash_shift_fab',
              onPressed: () =>
                  _showOpenShiftBottomSheet(context, state.registers),
              backgroundColor: colors.brand,
              foregroundColor: colors.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
        }

        return Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            backgroundColor: colors.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: const BackButton(),
            title: Text(
              _cashSectionTitle(language, widget.section),
              style: textStyles.h2Sans.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            actions: [
              if (widget.section == CashSection.operations)
                IconButton(
                  tooltip: language.translate('cash_filters'),
                  onPressed: () => _showFiltersSheet(context, state),
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
              if (widget.section != CashSection.pos &&
                  widget.section != CashSection.onec &&
                  widget.section != CashSection.edits)
                IconButton(
                  tooltip: language.translate('cash_download_report'),
                  onPressed: () => _showReportDownloadBottomSheet(context),
                  icon: Icon(TablerIcons.download, color: colors.brand),
                ),
              const SizedBox(width: 4),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: colors.border),
            ),
          ),
          floatingActionButton: fab,
          body: switch (widget.section) {
            CashSection.operations => _buildOperationsTab(
              context,
              state,
              isViewer,
            ),
            CashSection.shifts => _buildShiftsTab(context, state, isViewer),
            CashSection.summary => _buildSummaryTab(context, state.summaries),
            CashSection.pos => CashPosView(state: state, isViewer: isViewer),
            CashSection.onec => const CashOneCKkmView(),
            CashSection.edits => const CashEditsView(),
          },
        );
      },
    );
  }
}
