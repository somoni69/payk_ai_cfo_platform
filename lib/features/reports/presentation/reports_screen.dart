import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/localization/locale_number_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/auth/bloc/auth_state.dart';
import '../../../features/auth/domain/app_access.dart';
import '../../../features/branches/domain/branch_models.dart';
import '../../../features/branches/domain/branches_repository.dart';
import '../../../features/reports/bloc/reports_bloc.dart';
import '../../../features/reports/bloc/reports_event.dart';
import '../../../features/reports/bloc/reports_state.dart';
import '../../../features/reports/domain/report_models.dart';
import '../../../features/reports/domain/reports_repository.dart';
import '../../../presentation/widgets/expansible_widget.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../../../presentation/widgets/ledger_card.dart';
import '../../../presentation/widgets/ledger_collapsing_header.dart';
import '../../../presentation/widgets/ledger_pill.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';

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

class ReportsView extends StatefulWidget {
  const ReportsView({super.key});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  int? _filterBranchId;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  List<Branch> _branches = const [];
  bool _exporting = false;

  static const _managementRoles = {
    UserRole.director,
    UserRole.manager,
    UserRole.accountant,
  };

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    try {
      final list = await context.read<BranchesRepository>().getBranches();
      if (!mounted) return;
      setState(() => _branches = list.where((b) => b.isActive).toList());
    } catch (_) {}
  }

  UserRole? get _role {
    final auth = context.read<AuthBloc>().state;
    return auth is AuthAuthenticated ? auth.role : null;
  }

  bool get _isManagement {
    final role = _role;
    return role != null && _managementRoles.contains(role);
  }

  bool get _canWrite {
    final role = _role;
    return role != null && role.canWrite(AppCapability.reports);
  }

  bool get _canDelete {
    final role = _role;
    return role != null &&
        role == UserRole.director &&
        role.canDelete(AppCapability.reports);
  }

  DailyReportFilters get _filters => DailyReportFilters(
    branchId: _isManagement ? _filterBranchId : null,
    dateFrom: _dateFrom == null ? null : _fmtDate(_dateFrom!),
    dateTo: _dateTo == null ? null : _fmtDate(_dateTo!),
  );

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  void _reload({bool force = true}) {
    context.read<ReportsBloc>().add(
      LoadReportsData(filters: _filters, forceRefresh: force),
    );
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom
        ? (_dateFrom ?? DateTime.now())
        : (_dateTo ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _dateFrom = picked;
      } else {
        _dateTo = picked;
      }
    });
    _reload();
  }

  Future<void> _export(DailyReport report, String format) async {
    if (_exporting) return;
    final locale = context.read<LanguageCubit>();
    setState(() => _exporting = true);
    try {
      final bytes = await context.read<ReportsRepository>().exportDailyReport(
        report.id,
        format: format,
      );
      final dir = await getTemporaryDirectory();
      final dateStr = _fmtDate(report.reportDate);
      final file = File('${dir.path}/report_$dateStr.$format');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: locale.translate(
            'reports_export_subject',
            params: {'date': dateStr},
          ),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(locale.translate('reports_export_ok'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(locale.translateMessage(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _confirmDelete(DailyReport report) async {
    final locale = context.read<LanguageCubit>();
    final colors = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(locale.translate('reports_delete_title')),
        content: Text(locale.translate('reports_delete_msg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(locale.translate('common_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: colors.accentRed),
            child: Text(locale.translate('common_delete')),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      context.read<ReportsBloc>().add(DeleteDailyReportRequested(report.id));
    }
  }

  Future<void> _showReportForm({DailyReport? editing}) async {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.read<LanguageCubit>();

    final branchItems = _branches
        .map((b) => MapEntry(int.tryParse(b.id) ?? 0, b.name))
        .where((e) => e.key > 0)
        .toList();

    int? selectedBranchId =
        editing?.branchId ??
        (branchItems.isNotEmpty ? branchItems.first.key : null);
    DateTime reportDate = editing?.reportDate ?? DateTime.now();

    final totalCtrl = TextEditingController(
      text: editing == null
          ? ''
          : formatLocalizedNumber(context, editing.totalSales),
    );
    final cashCtrl = TextEditingController(
      text: editing == null
          ? ''
          : formatLocalizedNumber(context, editing.cashAmount),
    );
    final cashlessCtrl = TextEditingController(
      text: editing == null
          ? ''
          : formatLocalizedNumber(context, editing.cashlessAmount),
    );
    final returnsCountCtrl = TextEditingController(
      text: editing == null ? '0' : '${editing.returnsCount}',
    );
    final returnsAmountCtrl = TextEditingController(
      text: editing == null
          ? ''
          : formatLocalizedNumber(context, editing.returnsAmount),
    );
    final productsCtrl = TextEditingController(
      text: editing?.productsSold ?? '',
    );
    final noteCtrl = TextEditingController(text: editing?.note ?? '');
    bool hasInvoices = editing?.hasInvoices ?? false;
    String? formError;

    try {
      await LedgerBottomSheet.show(
        context: context,
        title: locale.translate(
          editing == null ? 'reports_modal_new' : 'reports_modal_edit',
        ),
        builder: (context, setSheetState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (formError != null) ...[
                LedgerCard(
                  backgroundColor: colors.accentRed.withValues(alpha: 0.08),
                  borderColor: colors.accentRed.withValues(alpha: 0.4),
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    formError!,
                    style: textStyles.captionSans.copyWith(
                      color: colors.accentRed,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_isManagement && editing == null) ...[
                Text(
                  locale.translate('reports_field_branch'),
                  style: textStyles.captionSans.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                if (branchItems.isEmpty)
                  Text(
                    locale.translate('reports_no_branches'),
                    style: textStyles.captionSans.copyWith(
                      color: colors.accentAmber,
                    ),
                  )
                else
                  ExpansibleWidget<int>.selection(
                    cardPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 0,
                    ),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: Text(
                      branchItems
                          .firstWhere(
                            (e) => e.key == selectedBranchId,
                            orElse: () => branchItems.first,
                          )
                          .value,
                      style: textStyles.bodySans.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    items: branchItems.map((e) => e.key).toList(),
                    selectedValue: selectedBranchId,
                    itemLabelBuilder: (id) => branchItems
                        .firstWhere(
                          (e) => e.key == id,
                          orElse: () => MapEntry(id, '#$id'),
                        )
                        .value,
                    onSelected: (val) {
                      setSheetState(() => selectedBranchId = val);
                    },
                  ),
                const SizedBox(height: 14),
              ],
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: reportDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (picked != null) {
                    setSheetState(() => reportDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: locale.translate('reports_field_date'),
                    suffixIcon: const Icon(TablerIcons.calendar, size: 18),
                  ),
                  child: Text(
                    formatLocalizedDateTime(
                      context,
                      reportDate,
                      style: LocalizedDateTimeStyle.date,
                    ),
                    style: textStyles.bodySans,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: totalCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: textStyles.bodySans,
                decoration: InputDecoration(
                  labelText: locale.translate('reports_field_total_sales'),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: cashCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: textStyles.bodySans,
                      decoration: InputDecoration(
                        labelText: locale.translate('reports_field_cash'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: cashlessCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: textStyles.bodySans,
                      decoration: InputDecoration(
                        labelText: locale.translate('reports_field_cashless'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: returnsCountCtrl,
                      keyboardType: TextInputType.number,
                      style: textStyles.bodySans,
                      decoration: InputDecoration(
                        labelText: locale.translate(
                          'reports_field_returns_count',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: returnsAmountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: textStyles.bodySans,
                      decoration: InputDecoration(
                        labelText: locale.translate(
                          'reports_field_returns_amount',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  locale.translate('reports_field_invoices'),
                  style: textStyles.bodySans,
                ),
                value: hasInvoices,
                activeTrackColor: colors.brand,
                onChanged: (v) => setSheetState(() => hasInvoices = v),
              ),
              TextField(
                controller: productsCtrl,
                style: textStyles.bodySans,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: locale.translate('reports_field_products'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                style: textStyles.bodySans,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: locale.translate('reports_field_note'),
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
                final total =
                    parseLocalizedNumber(context, totalCtrl.text.trim()) ?? 0;
                final cash =
                    parseLocalizedNumber(context, cashCtrl.text.trim()) ?? 0;
                final cashless =
                    parseLocalizedNumber(context, cashlessCtrl.text.trim()) ??
                    0;
                final returnsAmount =
                    parseLocalizedNumber(
                      context,
                      returnsAmountCtrl.text.trim(),
                    ) ??
                    0;
                final returnsCount =
                    int.tryParse(returnsCountCtrl.text.trim()) ?? 0;

                if (_isManagement &&
                    editing == null &&
                    (selectedBranchId == null || selectedBranchId! <= 0)) {
                  setSheetState(() {
                    formError = locale.translate('reports_error_branch');
                  });
                  return;
                }

                // Backend requires cash + cashless == total_sales
                if ((cash + cashless - total).abs() > 0.009) {
                  setSheetState(() {
                    formError = locale.translate('reports_error_sum_mismatch');
                  });
                  return;
                }

                final input = DailyReportInput(
                  branchId: editing == null ? selectedBranchId : null,
                  reportDate: reportDate,
                  totalSales: total,
                  cashAmount: cash,
                  cashlessAmount: cashless,
                  returnsCount: returnsCount < 0 ? 0 : returnsCount,
                  returnsAmount: returnsAmount,
                  hasInvoices: hasInvoices,
                  productsSold: productsCtrl.text.trim().isEmpty
                      ? null
                      : productsCtrl.text.trim(),
                  note: noteCtrl.text.trim().isEmpty
                      ? null
                      : noteCtrl.text.trim(),
                );

                final bloc = this.context.read<ReportsBloc>();
                if (editing != null) {
                  bloc.add(
                    UpdateDailyReportRequested(id: editing.id, input: input),
                  );
                } else {
                  bloc.add(CreateDailyReportRequested(input));
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.brand,
                foregroundColor: colors.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                locale.translate(
                  editing == null ? 'common_create' : 'common_save',
                ),
                style: textStyles.bodySans.copyWith(
                  color: colors.surface,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ),
          );
        },
      );
    } finally {
      totalCtrl.dispose();
      cashCtrl.dispose();
      cashlessCtrl.dispose();
      returnsCountCtrl.dispose();
      returnsAmountCtrl.dispose();
      productsCtrl.dispose();
      noteCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);

    return Scaffold(
      floatingActionButton: _canWrite
          ? FloatingActionButton.extended(
              onPressed: () => _showReportForm(),
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
                locale.translate('reports_new'),
                style: textStyles.bodySans.copyWith(
                  color: colors.surface,
                  fontWeight: FontWeight.w500,
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
              floating: false,
              snap: false,
            ),
          ];
        },
        body: BlocConsumer<ReportsBloc, ReportsState>(
          listenWhen: (prev, next) {
            if (next is! ReportsLoaded) return false;
            return next.actionError != null || next.actionSuccess != null;
          },
          listener: (context, state) {
            if (state is! ReportsLoaded) return;
            final msg = state.actionError ?? state.actionSuccess;
            if (msg == null) return;
            final text = state.actionError != null
                ? locale.translateMessage(msg)
                : locale.translate(msg);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(text)));
          },
          builder: (context, state) {
            if (state is ReportsLoading || state is ReportsInitial) {
              return const ReportsOverviewShimmer();
            }
            if (state is ReportsError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        locale.translateMessage(state.message),
                        textAlign: TextAlign.center,
                        style: textStyles.bodySans,
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => _reload(),
                        child: Text(locale.translate('common_retry')),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (state is! ReportsLoaded) return const SizedBox();

            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                children: [
                  if (_isManagement) ...[
                    LedgerCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_branches.isNotEmpty)
                            ExpansibleWidget<int?>.selection(
                              cardPadding: EdgeInsets.zero,
                              tilePadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              title: Text(
                                _filterBranchId == null
                                    ? locale.translate('reports_all_branches')
                                    : (_branches
                                              .where(
                                                (b) =>
                                                    int.tryParse(b.id) ==
                                                    _filterBranchId,
                                              )
                                              .map((b) => b.name)
                                              .firstOrNull ??
                                          locale.translate(
                                            'reports_all_branches',
                                          )),
                                style: textStyles.bodySans.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              items: [
                                null,
                                ..._branches
                                    .map((b) => int.tryParse(b.id))
                                    .whereType<int>(),
                              ],
                              selectedValue: _filterBranchId,
                              itemLabelBuilder: (id) {
                                if (id == null) {
                                  return locale.translate(
                                    'reports_all_branches',
                                  );
                                }
                                return _branches
                                        .where((b) => int.tryParse(b.id) == id)
                                        .map((b) => b.name)
                                        .firstOrNull ??
                                    '#$id';
                              },
                              onSelected: (val) {
                                setState(() => _filterBranchId = val);
                                _reload();
                              },
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickDate(isFrom: true),
                                  icon: const Icon(
                                    TablerIcons.calendar,
                                    size: 16,
                                  ),
                                  label: Text(
                                    _dateFrom == null
                                        ? locale.translate('reports_date_from')
                                        : formatLocalizedDateTime(
                                            context,
                                            _dateFrom!,
                                            style: LocalizedDateTimeStyle.date,
                                          ),
                                    style: textStyles.captionSans,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _pickDate(isFrom: false),
                                  icon: const Icon(
                                    TablerIcons.calendar,
                                    size: 16,
                                  ),
                                  label: Text(
                                    _dateTo == null
                                        ? locale.translate('reports_date_to')
                                        : formatLocalizedDateTime(
                                            context,
                                            _dateTo!,
                                            style: LocalizedDateTimeStyle.date,
                                          ),
                                    style: textStyles.captionSans,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              if (_dateFrom != null || _dateTo != null) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _dateFrom = null;
                                      _dateTo = null;
                                    });
                                    _reload();
                                  },
                                  icon: Icon(
                                    TablerIcons.x,
                                    size: 18,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  LedgerCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          locale.translate('reports_total_sales_sum'),
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${oCcy.format(state.totalSales)} TJS',
                          style: textStyles.h2Sans.copyWith(
                            color: colors.brand,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    locale.translate('reports_list_title'),
                    style: textStyles.h2Sans.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (state.dailyReports.isEmpty)
                    LedgerCard(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            Icon(
                              TablerIcons.report_analytics,
                              size: 32,
                              color: colors.textTooltip,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              locale.translate('reports_empty'),
                              style: textStyles.bodySans.copyWith(
                                color: colors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...state.dailyReports.map(
                      (rep) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: LedgerCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          formatLocalizedDateTime(
                                            context,
                                            rep.reportDate,
                                            style: LocalizedDateTimeStyle.date,
                                          ),
                                          style: textStyles.bodySans.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (_isManagement &&
                                            (rep.branchName?.isNotEmpty ??
                                                false)) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            rep.branchName!,
                                            style: textStyles.captionSans
                                                .copyWith(
                                                  color: colors.textSecondary,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  LedgerPill(
                                    text: rep.hasInvoices
                                        ? locale.translate(
                                            'reports_invoices_yes',
                                          )
                                        : locale.translate(
                                            'reports_invoices_no',
                                          ),
                                    backgroundColor: rep.hasInvoices
                                        ? colors.accentGreen.withValues(
                                            alpha: 0.1,
                                          )
                                        : colors.surfaceNested,
                                    textColor: rep.hasInvoices
                                        ? colors.accentGreen
                                        : colors.textSecondary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _metricRow(
                                locale.translate('reports_field_total_sales'),
                                '${oCcy.format(rep.totalSales)} TJS',
                                textStyles,
                                colors,
                                emphasize: true,
                              ),
                              _metricRow(
                                locale.translate('reports_field_cash'),
                                '${oCcy.format(rep.cashAmount)} TJS',
                                textStyles,
                                colors,
                              ),
                              _metricRow(
                                locale.translate('reports_field_cashless'),
                                '${oCcy.format(rep.cashlessAmount)} TJS',
                                textStyles,
                                colors,
                              ),
                              _metricRow(
                                locale.translate('reports_field_returns'),
                                '${rep.returnsCount} · ${oCcy.format(rep.returnsAmount)} TJS',
                                textStyles,
                                colors,
                              ),
                              if (rep.note != null && rep.note!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  rep.note!,
                                  style: textStyles.captionSans.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  if (_canWrite)
                                    IconButton(
                                      tooltip: locale.translate('common_edit'),
                                      onPressed: () =>
                                          _showReportForm(editing: rep),
                                      icon: Icon(
                                        TablerIcons.pencil,
                                        size: 18,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  IconButton(
                                    tooltip: 'PDF',
                                    onPressed: _exporting
                                        ? null
                                        : () => _export(rep, 'pdf'),
                                    icon: Icon(
                                      TablerIcons.file_type_pdf,
                                      size: 18,
                                      color: colors.brand,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Word',
                                    onPressed: _exporting
                                        ? null
                                        : () => _export(rep, 'docx'),
                                    icon: Icon(
                                      TablerIcons.file_type_doc,
                                      size: 18,
                                      color: colors.brand,
                                    ),
                                  ),
                                  if (_canDelete)
                                    IconButton(
                                      tooltip: locale.translate(
                                        'common_delete',
                                      ),
                                      onPressed: () => _confirmDelete(rep),
                                      icon: Icon(
                                        TablerIcons.trash,
                                        size: 18,
                                        color: colors.accentRed,
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
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _metricRow(
    String label,
    String value,
    LedgerTextStyles textStyles,
    LedgerColors colors, {
    bool emphasize = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: textStyles.captionSans.copyWith(color: colors.textSecondary),
          ),
          Text(
            value,
            style: (emphasize ? textStyles.bodyMono : textStyles.smallMono)
                .copyWith(
                  fontWeight: emphasize ? FontWeight.w500 : FontWeight.w400,
                  color: emphasize ? colors.textPrimary : colors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}
