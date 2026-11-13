import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_number_format.dart';
import '../../../core/theme/theme_extensions.dart';
import '../domain/loyalty_models.dart';
import '../domain/loyalty_repository.dart';
import 'loyalty_format.dart';

class LoyaltyMembersTab extends StatefulWidget {
  const LoyaltyMembersTab({super.key, required this.canManage});

  final bool canManage;

  @override
  State<LoyaltyMembersTab> createState() => _LoyaltyMembersTabState();
}

class _LoyaltyMembersTabState extends State<LoyaltyMembersTab> {
  final _search = TextEditingController();
  Timer? _debounce;
  var _loading = true;
  String? _error;
  LoyaltyMembersPage? _page;
  int? _status;
  String? _segment;
  String? _wholesale;
  bool? _regular;
  var _pageNo = 1;

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

  MemberQuery get _query => MemberQuery(
    q: _search.text,
    status: _status,
    segment: _segment,
    wholesale: _wholesale,
    regular: _regular,
    page: _pageNo,
  );

  Future<void> _load() async {
    setState(() {
      _loading = _page == null;
      _error = null;
    });
    try {
      final page = await context.read<LoyaltyRepository>().members(_query);
      if (!mounted) return;
      setState(() {
        _page = page;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    final page = _page;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          TextField(
            controller: _search,
            decoration: InputDecoration(
              labelText: language.translate('loyalty_members_search'),
            ),
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), () {
                _pageNo = 1;
                _load();
              });
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              for (var level = 1; level <= 5; level++)
                FilterChip(
                  label: Text(loyaltyStatusLabel(language, level)),
                  selected: _status == level,
                  onSelected: (selected) {
                    setState(() => _status = selected ? level : null);
                    _pageNo = 1;
                    _load();
                  },
                ),
              FilterChip(
                label: Text(language.translate('loyalty_wholesale_pending')),
                selected: _wholesale == 'pending',
                onSelected: (selected) {
                  setState(() => _wholesale = selected ? 'pending' : null);
                  _pageNo = 1;
                  _load();
                },
              ),
              FilterChip(
                label: Text(language.translate('loyalty_regular')),
                selected: _regular == true,
                onSelected: (selected) {
                  setState(() => _regular = selected ? true : null);
                  _pageNo = 1;
                  _load();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              for (final code in const [
                'AA',
                'AB',
                'AC',
                'BA',
                'BB',
                'BC',
                'CA',
                'CB',
                'CC',
              ])
                ChoiceChip(
                  label: Text(code),
                  selected: _segment == code,
                  onSelected: (selected) {
                    setState(() => _segment = selected ? code : null);
                    _pageNo = 1;
                    _load();
                  },
                ),
            ],
          ),
          if (widget.canManage)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _broadcast,
                child: Text(language.translate('loyalty_broadcast')),
              ),
            ),
          if (_loading && page == null)
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null && page == null)
            Text(language.resolveMessage(_error!))
          else if (page == null || page.items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(language.translate('loyalty_members_empty')),
            )
          else ...[
            Text('${page.total}'),
            for (final member in page.items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(member.name),
                subtitle: Text(
                  [
                    member.phone,
                    loyaltyStatusLabel(language, member.status),
                    if (member.segment != null) member.segment!,
                    if (member.isRegular) language.translate('loyalty_regular'),
                    if (member.wholesaleFlag != null)
                      loyaltyWholesaleLabel(language, member.wholesaleFlag),
                  ].join(' · '),
                ),
                trailing: Text(
                  formatLocalizedNumber(
                    context,
                    member.balance,
                    minimumFractionDigits: 2,
                    maximumFractionDigits: 2,
                  ),
                  style: context.textStyles.bodyMono,
                ),
                onTap: () => _open(member.id),
              ),
            if (page.total > page.items.length)
              TextButton(
                onPressed: () {
                  _pageNo += 1;
                  _loadMore();
                },
                child: Text(language.translate('loyalty_more')),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _loadMore() async {
    try {
      final next = await context.read<LoyaltyRepository>().members(_query);
      if (!mounted) return;
      setState(() {
        final current = _page?.items ?? const <LoyaltyMember>[];
        _page = LoyaltyMembersPage(
          items: [...current, ...next.items],
          total: next.total,
          byStatus: next.byStatus,
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  Future<void> _open(int id) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _MemberSheet(id: id, canManage: widget.canManage),
    );
    if (changed == true) _load();
  }

  Future<void> _broadcast() async {
    final language = context.read<LanguageCubit>();
    final tj = TextEditingController();
    final ru = TextEditingController();
    final key = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    BroadcastPreview? preview;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) {
          return AlertDialog(
            title: Text(language.translate('loyalty_broadcast')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tj,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: language.translate('loyalty_broadcast_tj'),
                  ),
                ),
                TextField(
                  controller: ru,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: language.translate('loyalty_broadcast_ru'),
                  ),
                ),
                if (preview != null)
                  Text(
                    language.translate(
                      'loyalty_broadcast_preview',
                      params: {'n': preview!.recipients},
                    ),
                  ),
                if (error != null) Text(language.resolveMessage(error!)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(language.translate('common_cancel')),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    final repo = context.read<LoyaltyRepository>();
                    final filters = _query.filters();
                    if (preview == null) {
                      final next = await repo.previewBroadcast(
                        filters: filters,
                        textTj: tj.text,
                        textRu: ru.text,
                      );
                      setDialog(() {
                        preview = next;
                        error = null;
                      });
                    } else {
                      await repo.sendBroadcast(
                        filters: filters,
                        textTj: tj.text,
                        textRu: ru.text,
                        clientKey: key,
                      );
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            language.translate('loyalty_broadcast_sent'),
                          ),
                        ),
                      );
                    }
                  } catch (caught) {
                    setDialog(() => error = caught.toString());
                  }
                },
                child: Text(
                  language.translate(
                    preview == null ? 'loyalty_pos_calc' : 'loyalty_broadcast',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    tj.dispose();
    ru.dispose();
  }
}

class _MemberSheet extends StatefulWidget {
  const _MemberSheet({required this.id, required this.canManage});

  final int id;
  final bool canManage;

  @override
  State<_MemberSheet> createState() => _MemberSheetState();
}

class _MemberSheetState extends State<_MemberSheet> {
  var _loading = true;
  String? _error;
  LoyaltyMemberCard? _card;
  var _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final card = await context.read<LoyaltyRepository>().member(widget.id);
      if (!mounted) return;
      setState(() {
        _card = card;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    final card = _card;
    final member = card?.member;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: _loading
          ? const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            )
          : member == null
          ? Text(language.resolveMessage(_error ?? ''))
          : ListView(
              shrinkWrap: true,
              children: [
                Text(member.name, style: context.textStyles.h2Sans),
                Text(member.phone),
                const SizedBox(height: 8),
                Text(
                  '${loyaltyStatusLabel(language, member.status)} · ${language.translate('loyalty_balance')} ${formatLocalizedNumber(context, member.balance, minimumFractionDigits: 2, maximumFractionDigits: 2)}',
                ),
                if (member.segment != null)
                  Text(
                    '${language.translate('loyalty_segment')}: ${member.segment}',
                  ),
                if (member.wholesaleFlag != null)
                  Text(loyaltyWholesaleLabel(language, member.wholesaleFlag)),
                if (member.birthDate != null)
                  Text(
                    '${language.translate('loyalty_birthday')}: ${member.birthDate}',
                  ),
                const SizedBox(height: 8),
                for (final bill in card!.bills.take(6))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(bill.extId),
                    subtitle: Text(loyaltyModeLabel(language, bill.mode)),
                    trailing: Text(
                      formatLocalizedNumber(
                        context,
                        bill.amount,
                        minimumFractionDigits: 2,
                        maximumFractionDigits: 2,
                      ),
                    ),
                  ),
                if (widget.canManage) ...[
                  TextButton(
                    onPressed: _adjust,
                    child: Text(language.translate('loyalty_adjust')),
                  ),
                  if (member.wholesaleFlag == 'pending') ...[
                    TextButton(
                      onPressed: () => _wholesale('confirm'),
                      child: Text(
                        language.translate('loyalty_wholesale_confirm'),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _wholesale('dismiss'),
                      child: Text(
                        language.translate('loyalty_wholesale_dismiss'),
                      ),
                    ),
                  ],
                ],
                TextButton(
                  onPressed: () => Navigator.pop(context, _changed),
                  child: Text(language.translate('common_cancel')),
                ),
              ],
            ),
    );
  }

  Future<String?> _askReason(String title) async {
    final language = context.read<LanguageCubit>();
    final reason = TextEditingController();
    final amount = TextEditingController();
    final withAmount = title == language.translate('loyalty_adjust');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (withAmount)
              TextField(
                controller: amount,
                decoration: InputDecoration(
                  labelText: language.translate('loyalty_adjust_amount'),
                ),
              ),
            TextField(
              controller: reason,
              decoration: InputDecoration(
                labelText: language.translate('loyalty_reason'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(language.translate('common_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(language.translate('common_save')),
          ),
        ],
      ),
    );
    final text = reason.text.trim();
    final sum = amount.text.trim().replaceAll(',', '.');
    reason.dispose();
    amount.dispose();
    if (ok != true || text.length < 3) return null;
    return withAmount ? '$sum|$text' : text;
  }

  Future<void> _adjust() async {
    final language = context.read<LanguageCubit>();
    final packed = await _askReason(language.translate('loyalty_adjust'));
    if (packed == null || !mounted) return;
    final parts = packed.split('|');
    if (parts.length < 2 || parts[0].isEmpty) return;
    try {
      await context.read<LoyaltyRepository>().adjustMember(
        widget.id,
        amount: parts[0],
        reason: parts.sublist(1).join('|'),
      );
      _changed = true;
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  Future<void> _wholesale(String action) async {
    final language = context.read<LanguageCubit>();
    final reason = await _askReason(
      language.translate(
        action == 'confirm'
            ? 'loyalty_wholesale_confirm'
            : 'loyalty_wholesale_dismiss',
      ),
    );
    if (reason == null || !mounted) return;
    try {
      await context.read<LoyaltyRepository>().setWholesale(
        widget.id,
        action: action,
        reason: reason,
      );
      _changed = true;
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }
}

class LoyaltyBirthdaysTab extends StatefulWidget {
  const LoyaltyBirthdaysTab({super.key});

  @override
  State<LoyaltyBirthdaysTab> createState() => _LoyaltyBirthdaysTabState();
}

class _LoyaltyBirthdaysTabState extends State<LoyaltyBirthdaysTab> {
  var _days = 30;
  var _loading = true;
  String? _error;
  List<LoyaltyBirthday> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await context.read<LoyaltyRepository>().birthdays(
        days: _days,
      );
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final days in const [7, 14, 30])
              ChoiceChip(
                label: Text(
                  language.translate('loyalty_days', params: {'n': days}),
                ),
                selected: _days == days,
                onSelected: (_) {
                  setState(() => _days = days);
                  _load();
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          Text(language.resolveMessage(_error!))
        else if (_rows.isEmpty)
          Text(language.translate('loyalty_birthdays_empty'))
        else
          for (final row in _rows)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(row.name),
              subtitle: Text(
                '${row.dayMonth} · ${row.phone} · ${loyaltyStatusLabel(language, row.status)}',
              ),
              trailing: Text(_when(language, row.daysUntil)),
            ),
      ],
    );
  }

  String _when(LanguageCubit language, int days) {
    if (days <= 0) return language.translate('loyalty_birthdays_today');
    if (days == 1) return language.translate('loyalty_birthdays_tomorrow');
    return language.translate('loyalty_birthdays_in', params: {'n': days});
  }
}

class LoyaltyMessagesTab extends StatefulWidget {
  const LoyaltyMessagesTab({super.key});

  @override
  State<LoyaltyMessagesTab> createState() => _LoyaltyMessagesTabState();
}

class _LoyaltyMessagesTabState extends State<LoyaltyMessagesTab> {
  var _loading = true;
  String? _error;
  LoyaltyMessageSummary? _summary;
  List<LoyaltyMessageRow> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = context.read<LoyaltyRepository>();
      final summary = await repo.messageSummary();
      final rows = await repo.messages();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _rows = rows;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    final summary = _summary;
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && summary == null) {
      return Center(child: Text(language.resolveMessage(_error!)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (summary != null)
            Text(
              '${language.translate('loyalty_msg_fcm')} ${summary.fcm} · ${language.translate('loyalty_msg_telegram')} ${summary.telegram} · ${language.translate('loyalty_msg_sms')} ${summary.smsUsed}/${summary.smsLimit} · ${language.translate('loyalty_msg_app')} ${summary.app}',
            ),
          const SizedBox(height: 8),
          if (_rows.isEmpty)
            Text(language.translate('loyalty_messages_empty'))
          else
            for (final row in _rows)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(row.memberName.isEmpty ? row.kind : row.memberName),
                subtitle: Text(
                  '${row.kind} · ${row.channel} · ${row.state}\n${row.text}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
        ],
      ),
    );
  }
}

class LoyaltyReportsTab extends StatefulWidget {
  const LoyaltyReportsTab({super.key});

  @override
  State<LoyaltyReportsTab> createState() => _LoyaltyReportsTabState();
}

class _LoyaltyReportsTabState extends State<LoyaltyReportsTab> {
  var _loading = true;
  String? _error;
  LoyaltyDashboard? _dashboard;
  List<IdentifiedSlice> _identified = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = context.read<LoyaltyRepository>();
      final dashboard = await repo.dashboard();
      List<IdentifiedSlice> identified = const [];
      try {
        identified = await repo.identified();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _dashboard = dashboard;
        _identified = identified;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    final dash = _dashboard;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (dash == null) {
      return Center(child: Text(language.resolveMessage(_error ?? '')));
    }
    String money(double value) => formatLocalizedNumber(
      context,
      value,
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    );
    final rows = <(String, String)>[
      (language.translate('loyalty_stat_members'), '${dash.membersTotal}'),
      (language.translate('loyalty_reports_new'), '${dash.membersNew}'),
      (language.translate('loyalty_reports_bills'), '${dash.billsCount}'),
      (language.translate('loyalty_reports_amount'), money(dash.billsAmount)),
      (language.translate('loyalty_reports_average'), money(dash.billsAverage)),
      (language.translate('loyalty_reports_accrued'), money(dash.accrued)),
      (language.translate('loyalty_reports_burned'), money(dash.burned)),
      (language.translate('loyalty_reports_liability'), money(dash.balance)),
      (language.translate('loyalty_debt'), money(dash.debt)),
      (language.translate('loyalty_pos_coupon'), money(dash.couponUsed)),
      (language.translate('loyalty_reports_dob'), money(dash.dobBonus)),
    ];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text(row.$1)),
                  Text(row.$2, style: context.textStyles.bodyMono),
                ],
              ),
            ),
          if (dash.segments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              language.translate('loyalty_reports_segments'),
              style: context.textStyles.bodySans.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final code in const [
                  'AA',
                  'AB',
                  'AC',
                  'BA',
                  'BB',
                  'BC',
                  'CA',
                  'CB',
                  'CC',
                ])
                  if (dash.segments.containsKey(code))
                    Chip(label: Text('$code ${dash.segments[code]}')),
              ],
            ),
          ],
          if (_identified.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              language.translate('loyalty_reports_identified'),
              style: context.textStyles.bodySans.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            for (final slice in _identified)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(loyaltyFormatLabel(language, slice.name)),
                subtitle: Text(
                  '${language.translate('loyalty_reports_bills')}: ${slice.bills}',
                ),
                trailing: Text(
                  slice.shareAmount == null
                      ? '—'
                      : '${(slice.shareAmount! * 100).toStringAsFixed(0)}%',
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class LoyaltySettingsTab extends StatefulWidget {
  const LoyaltySettingsTab({
    super.key,
    required this.state,
    required this.canEdit,
    required this.onChanged,
  });

  final LoyaltyProgramState state;
  final bool canEdit;
  final VoidCallback onChanged;

  @override
  State<LoyaltySettingsTab> createState() => _LoyaltySettingsTabState();
}

class _LoyaltySettingsTabState extends State<LoyaltySettingsTab> {
  final _title = TextEditingController();
  final _slug = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title.text = widget.state.program?.title ?? 'ПАЙК';
  }

  @override
  void dispose() {
    _title.dispose();
    _slug.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      widget.onChanged();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    final program = widget.state.program;
    final colors = context.colors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (program == null) ...[
          Text(language.translate('loyalty_no_program')),
          const SizedBox(height: 8),
          TextField(
            controller: _title,
            decoration: InputDecoration(
              labelText: language.translate('loyalty_program_title'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _slug,
            decoration: InputDecoration(
              labelText: language.translate('loyalty_program_slug'),
              helperText: language.translate('loyalty_slug_hint'),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: !widget.canEdit || _busy
                ? null
                : () => _run(() async {
                    await context.read<LoyaltyRepository>().createProgram(
                      title: _title.text,
                      slug: _slug.text,
                    );
                  }),
            child: Text(language.translate('loyalty_create')),
          ),
        ] else ...[
          TextField(
            controller: _title,
            enabled: widget.canEdit,
            decoration: InputDecoration(
              labelText: language.translate('loyalty_program_title'),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              language.translate(
                program.enabled ? 'loyalty_enabled' : 'loyalty_disabled',
              ),
            ),
            value: program.enabled,
            activeTrackColor: colors.brand,
            onChanged: !widget.canEdit || _busy
                ? null
                : (value) => _run(() async {
                    await context.read<LoyaltyRepository>().updateProgram(
                      enabled: value,
                      title: _title.text.trim() == program.title
                          ? null
                          : _title.text,
                    );
                  }),
          ),
          if (widget.state.appLink != null)
            SelectableText(widget.state.appLink!),
          const SizedBox(height: 8),
          Text(
            language.translate('loyalty_stat_terminals'),
            style: context.textStyles.bodySans.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          for (final terminal in widget.state.terminals)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(terminal.name),
              subtitle: Text(loyaltyFormatLabel(language, terminal.formatCode)),
              trailing: widget.canEdit
                  ? Switch.adaptive(
                      value: terminal.isActive,
                      activeTrackColor: colors.brand,
                      onChanged: _busy
                          ? null
                          : (value) => _run(() async {
                              await context
                                  .read<LoyaltyRepository>()
                                  .updateTerminal(terminal.id, isActive: value);
                            }),
                    )
                  : Text(
                      language.translate(
                        terminal.isActive
                            ? 'loyalty_terminal_active'
                            : 'loyalty_disabled',
                      ),
                    ),
            ),
          if (widget.canEdit)
            TextButton(
              onPressed: _busy ? null : _addTerminal,
              child: Text(language.translate('loyalty_terminal_add')),
            ),
        ],
        if (_error != null)
          Text(
            language.resolveMessage(_error!),
            style: TextStyle(color: colors.accentRed),
          ),
      ],
    );
  }

  Future<void> _addTerminal() async {
    final language = context.read<LanguageCubit>();
    final name = TextEditingController();
    var format = 'SM';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(language.translate('loyalty_terminal_add')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: InputDecoration(
                  labelText: language.translate('loyalty_terminal_name'),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButton<String>(
                isExpanded: true,
                value: format,
                items: [
                  DropdownMenuItem(
                    value: 'SM',
                    child: Text(language.translate('loyalty_format_sm')),
                  ),
                  DropdownMenuItem(
                    value: 'CL',
                    child: Text(language.translate('loyalty_format_cl')),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setDialog(() => format = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(language.translate('common_cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(language.translate('common_save')),
            ),
          ],
        ),
      ),
    );
    final title = name.text.trim();
    name.dispose();
    if (ok != true || title.isEmpty || !mounted) return;
    await _run(() async {
      await context.read<LoyaltyRepository>().createTerminal(
        name: title,
        formatCode: format,
      );
    });
  }
}
