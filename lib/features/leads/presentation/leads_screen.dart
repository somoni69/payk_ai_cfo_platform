import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_extensions.dart';
import '../domain/lead_models.dart';
import '../domain/leads_repository.dart';
import 'lead_sheet.dart';

class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  var _loading = true;
  String? _error;
  var _query = '';
  String? _status;
  LeadSummary _summary = LeadSummary.empty;
  DemoBank _bank = DemoBank.empty;
  List<LeadRow> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  LeadsRepository get _repo => context.read<LeadsRepository>();

  Future<void> _load() async {
    try {
      final summary = await _repo.getSummary();
      final rows = await _repo.listLeads(query: _query, status: _status);
      DemoBank bank = _bank;
      try {
        bank = await _repo.getBank();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _rows = rows;
        _bank = bank;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _errorText(context, error);
      });
    }
  }

  Future<void> _export() async {
    final language = context.read<LanguageCubit>();
    try {
      final bytes = await _repo.exportXlsx(query: _query, status: _status);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/payk-leads.xlsx');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              file.path,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _snack(language.resolveMessage(_errorText(context, error)));
    }
  }

  void _copyLink() {
    final language = context.read<LanguageCubit>();
    Clipboard.setData(const ClipboardData(text: kPaykDemoUrl));
    _snack(language.translate('leads_link_copied'));
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final lang = language.state.languageCode;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          language.translate('leads_title'),
          style: textStyles.h2Sans.copyWith(
            fontSize: 19,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            tooltip: language.translate('leads_copy_link'),
            onPressed: _copyLink,
            icon: const Icon(TablerIcons.link),
          ),
          IconButton(
            tooltip: language.translate('leads_export'),
            onPressed: _export,
            icon: const Icon(TablerIcons.file_spreadsheet),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: colors.border),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                language.translate('leads_description'),
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _LeadStats(summary: _summary, language: language),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              children: [
                _StatusChip(
                  label: language.translate('leads_all'),
                  selected: _status == null,
                  onTap: () {
                    setState(() => _status = null);
                    _load();
                  },
                ),
                for (final status in LeadStatus.valuesInOrder)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _StatusChip(
                      label:
                          '${language.translate(status.labelKey)} ${_summary.countOf(status)}',
                      selected: _status == status.apiValue,
                      onTap: () {
                        setState(() => _status = status.apiValue);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (value) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  if (!mounted) return;
                  setState(() => _query = value.trim());
                  _load();
                });
              },
              decoration: InputDecoration(
                isDense: true,
                hintText: language.translate('leads_search'),
                prefixIcon: const Icon(TablerIcons.search, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _error!,
                style: textStyles.captionSans.copyWith(color: colors.accentRed),
              ),
            ),
          Expanded(
            child: _loading && _rows.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _rows.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 48),
                              Icon(TablerIcons.inbox, color: colors.textSecondary),
                              const SizedBox(height: 8),
                              Text(
                                _query.isEmpty && _status == null
                                    ? language.translate('leads_empty')
                                    : language.translate('leads_empty_filtered'),
                                textAlign: TextAlign.center,
                                style: textStyles.bodySans,
                              ),
                              if (_query.isEmpty && _status == null)
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    language.translate('leads_empty_hint'),
                                    textAlign: TextAlign.center,
                                    style: textStyles.captionSans.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: _rows.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final row = _rows[index];
                              return _LeadCard(
                                row: row,
                                bank: _bank,
                                lang: lang,
                                onTap: () async {
                                  final changed = await showLeadSheet(
                                    context,
                                    leadId: row.id,
                                    bank: _bank,
                                  );
                                  if (changed == true) await _load();
                                },
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LeadStats extends StatelessWidget {
  const _LeadStats({required this.summary, required this.language});

  final LeadSummary summary;
  final LanguageCubit language;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final items = [
      (language.translate('leads_stats_total'), '${summary.total}'),
      (language.translate('leads_stats_today'), '${summary.today}'),
      (
        language.translate('leads_stats_new'),
        '${summary.countOf(LeadStatus.incoming)}',
      ),
      (
        language.translate('leads_stats_won'),
        '${summary.countOf(LeadStatus.won)}',
      ),
    ];
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.9,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.$1,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                Text(
                  item.$2,
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: colors.brand.withValues(alpha: 0.16),
      checkmarkColor: colors.brand,
      labelStyle: context.textStyles.captionSans.copyWith(
        color: selected ? colors.brand : colors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _LeadCard extends StatelessWidget {
  const _LeadCard({
    required this.row,
    required this.bank,
    required this.lang,
    required this.onTap,
  });

  final LeadRow row;
  final DemoBank bank;
  final String lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final price = formatLeadPrice(row.price);
    final spheres = [
      for (final key in row.spheres) bank.labelOf(bank.spheres, key, lang),
    ].join(', ');
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.name,
                      style: textStyles.bodySans.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _LeadStatusBadge(status: row.status),
                ],
              ),
              if (row.company.isNotEmpty)
                Text(
                  row.company,
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              Text(row.phone, style: textStyles.bodySans),
              if (spheres.isNotEmpty)
                Text(
                  spheres,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    formatLeadDate(row.createdAt),
                    style: textStyles.captionSans.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (row.overallLevel != null)
                    Text(
                      '${row.overallLevel}/100',
                      style: textStyles.captionSans.copyWith(
                        color: _levelColor(colors, row.overallLevel),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (price != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '$price ${language.translate('leads_per_month')}',
                      style: textStyles.captionSans.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              if (row.repeats > 0)
                Text(
                  language.translate(
                    'leads_repeats',
                    params: {'n': '${row.repeats}'},
                  ),
                  style: textStyles.captionSans.copyWith(color: colors.accentAmber),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeadStatusBadge extends StatelessWidget {
  const _LeadStatusBadge({required this.status});

  final LeadStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = switch (status) {
      LeadStatus.incoming => colors.brand,
      LeadStatus.contacted => colors.brand,
      LeadStatus.meeting => colors.accentAmber,
      LeadStatus.won => colors.accentGreen,
      LeadStatus.lost => colors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        context.watch<LanguageCubit>().translate(status.labelKey),
        style: context.textStyles.captionSans.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

Color _levelColor(LedgerColors colors, int? level) {
  if (level == null) return colors.textSecondary;
  if (level >= 75) return colors.accentGreen;
  if (level >= 45) return colors.accentAmber;
  return colors.accentRed;
}

String _errorText(BuildContext context, Object error) {
  final raw = error.toString();
  const prefix = 'Exception: ';
  final key = raw.startsWith(prefix) ? raw.substring(prefix.length) : raw;
  return context.read<LanguageCubit>().resolveMessage(key);
}
