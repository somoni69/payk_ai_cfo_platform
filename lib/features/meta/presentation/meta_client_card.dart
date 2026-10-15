import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/localization/locale_number_format.dart';
import '../../../core/network/user_facing_error.dart';
import '../../../core/theme/theme_extensions.dart';
import '../domain/meta_models.dart';
import '../domain/meta_repository.dart';
import 'meta_attachments.dart';

const _dealStages = [
  'lead',
  'contact',
  'proposal',
  'negotiation',
  'won',
  'lost',
];

const _rejectReasons = ['price', 'stock', 'elsewhere', 'silent', 'changed'];

/// Client card opened from a funnel card, the same job as the web ShamCRM card.
class MetaClientCardScreen extends StatefulWidget {
  const MetaClientCardScreen({
    super.key,
    required this.thread,
    required this.onOpenChat,
    this.initialTab = 0,
  });

  final MetaThread thread;
  final VoidCallback onOpenChat;
  final int initialTab;

  @override
  State<MetaClientCardScreen> createState() => _MetaClientCardScreenState();
}

class _MetaClientCardScreenState extends State<MetaClientCardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _region = TextEditingController();
  final _taskTitle = TextEditingController();

  var _loading = true;
  var _saving = false;
  String? _error;
  ThreadCard? _card;
  List<CardHistoryEntry> _history = const [];
  List<ThreadTask> _tasks = const [];
  List<MetaStaff> _staff = const [];
  List<CardContact> _contacts = const [];
  DateTime? _birthday;
  String? _taskDue;
  int? _taskAssignee;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _taskDue =
        '${tomorrow.year.toString().padLeft(4, '0')}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _name.dispose();
    _phone.dispose();
    _region.dispose();
    _taskTitle.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = context.read<MetaRepository>();
    try {
      final card = await repo.getThreadCard(widget.thread.id);
      final history = await repo.getThreadHistory(widget.thread.id);
      final tasks = await repo.getThreadTasks(widget.thread.id);
      final staff = await repo.getStaff();
      if (!mounted) return;
      _apply(card);
      setState(() {
        _history = history;
        _tasks = tasks;
        _staff = staff;
        _taskAssignee ??= widget.thread.assigneeId ??
            (staff.isEmpty ? null : staff.first.id);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _caughtKey(e);
        _loading = false;
      });
    }
  }

  void _apply(ThreadCard card) {
    final client = card.client;
    _name.text = client?.fullName ?? widget.thread.titleOr('');
    _phone.text = client?.phone ?? widget.thread.peerPhone ?? '';
    _region.text = client?.region ?? '';
    _birthday = DateTime.tryParse(client?.birthDate ?? '');
    _contacts = [...?client?.contacts];
    _card = card;
    if (_taskTitle.text.trim().isEmpty) {
      _taskTitle.text = '';
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final card = await context.read<MetaRepository>().updateCardClient(
        widget.thread.id,
        CardClientInput(
          fullName: name,
          phone: _phone.text.trim(),
          region: _region.text.trim(),
          birthDate: _birthday == null
              ? null
              : '${_birthday!.year.toString().padLeft(4, '0')}-${_birthday!.month.toString().padLeft(2, '0')}-${_birthday!.day.toString().padLeft(2, '0')}',
          contacts: _contacts,
        ),
      );
      if (!mounted) return;
      setState(() {
        _apply(card);
        _saving = false;
      });
      _snack('meta_card_saved');
      await _reloadHistory();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(_caughtKey(e));
    }
  }

  Future<void> _reloadHistory() async {
    try {
      final history = await context.read<MetaRepository>().getThreadHistory(
        widget.thread.id,
      );
      if (!mounted) return;
      setState(() => _history = history);
    } catch (_) {}
  }

  void _snack(String key) {
    final language = context.read<LanguageCubit>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(language.translate(key))),
    );
  }

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(1995),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() => _birthday = picked);
  }

  Future<void> _reject() async {
    final language = context.read<LanguageCubit>();
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(language.translate('meta_card_reject_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(language.translate('meta_card_reject_hint')),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final key in _rejectReasons)
                  ActionChip(
                    label: Text(language.translate('meta_reason_$key')),
                    onPressed: () => reason.text = language.translate(
                      'meta_reason_$key',
                    ),
                  ),
              ],
            ),
            TextField(
              controller: reason,
              decoration: InputDecoration(
                labelText: language.translate('meta_card_reject_reason'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(language.translate('meta_comments_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(language.translate('meta_card_reject')),
          ),
        ],
      ),
    );
    final text = reason.text.trim();
    reason.dispose();
    if (confirmed != true || !mounted) return;
    try {
      final card = await context.read<MetaRepository>().rejectThread(
        widget.thread.id,
        text.isEmpty ? null : text,
      );
      if (!mounted) return;
      setState(() => _apply(card));
      await _reloadHistory();
    } catch (e) {
      if (!mounted) return;
      _snack(_caughtKey(e));
    }
  }

  Future<void> _createDeal() async {
    final language = context.read<LanguageCubit>();
    final title = TextEditingController();
    final amount = TextEditingController();
    var stage = 'lead';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(language.translate('meta_card_deal_create')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: InputDecoration(
                  labelText: language.translate('meta_card_deal_title'),
                ),
              ),
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: language.translate('meta_card_deal_amount'),
                ),
              ),
              DropdownButton<String>(
                isExpanded: true,
                value: stage,
                items: [
                  for (final item in _dealStages)
                    DropdownMenuItem(
                      value: item,
                      child: Text(language.translate('meta_deal_$item')),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setLocal(() => stage = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(language.translate('meta_comments_cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(language.translate('meta_card_deal_create')),
            ),
          ],
        ),
      ),
    );
    final dealTitle = title.text.trim();
    final dealAmount = amount.text.trim();
    title.dispose();
    amount.dispose();
    if (ok != true || dealTitle.isEmpty || !mounted) return;
    try {
      final card = await context.read<MetaRepository>().createCardDeal(
        widget.thread.id,
        title: dealTitle,
        amount: dealAmount.isEmpty ? '0' : dealAmount.replaceAll(',', '.'),
        stage: stage,
      );
      if (!mounted) return;
      setState(() => _apply(card));
      await _reloadHistory();
    } catch (e) {
      if (!mounted) return;
      _snack(_caughtKey(e));
    }
  }

  Future<void> _setDealStage(CardDeal deal, String stage) async {
    try {
      final card = await context.read<MetaRepository>().updateCardDeal(
        widget.thread.id,
        deal.id,
        stage,
      );
      if (!mounted) return;
      setState(() => _apply(card));
    } catch (e) {
      if (!mounted) return;
      _snack(_caughtKey(e));
    }
  }

  Future<void> _addTask() async {
    final title = _taskTitle.text.trim();
    if (title.isEmpty) return;
    final repo = context.read<MetaRepository>();
    try {
      await repo.createThreadTask(
        widget.thread.id,
        title: title,
        dueDate: _taskDue,
        assigneeId: _taskAssignee,
      );
      _taskTitle.clear();
      final tasks = await repo.getThreadTasks(widget.thread.id);
      if (!mounted) return;
      setState(() => _tasks = tasks);
      await _reloadHistory();
    } catch (e) {
      if (!mounted) return;
      _snack(_caughtKey(e));
    }
  }

  Future<void> _finishTask(ThreadTask task) async {
    final repo = context.read<MetaRepository>();
    try {
      await repo.finishThreadTask(widget.thread.id, task.id);
      final tasks = await repo.getThreadTasks(widget.thread.id);
      if (!mounted) return;
      setState(() => _tasks = tasks);
    } catch (e) {
      if (!mounted) return;
      _snack(_caughtKey(e));
    }
  }

  void _call() {
    final raw = _phone.text.trim().isNotEmpty
        ? _phone.text
        : widget.thread.peerPhone;
    final href = phoneHref(raw);
    if (href == null) return;
    launchUrl(Uri.parse(href));
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    final colors = context.colors;
    final title = _name.text.trim().isNotEmpty
        ? _name.text.trim()
        : widget.thread.titleOr(language.translate('meta_unnamed'));
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textStyles.h2Sans.copyWith(fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: language.translate('meta_funnel_call'),
            onPressed: _call,
            icon: const Icon(TablerIcons.phone),
          ),
          IconButton(
            tooltip: language.translate('meta_funnel_open'),
            onPressed: widget.onOpenChat,
            icon: const Icon(TablerIcons.message),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: [
            Tab(text: language.translate('meta_card_info')),
            Tab(text: language.translate('meta_card_events')),
            Tab(text: language.translate('meta_card_deals')),
            Tab(text: language.translate('meta_card_files')),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _card == null
          ? Center(child: Text(language.translate(_error!)))
          : TabBarView(
              controller: _tabs,
              children: [
                _info(language),
                _events(language),
                _deals(language),
                _files(language),
              ],
            ),
    );
  }

  Widget _info(LanguageCubit language) {
    final card = _card;
    final birthday = _birthday == null
        ? language.translate('meta_funnel_none')
        : formatLocalizedDateTime(
            context,
            _birthday!,
            style: LocalizedDateTimeStyle.date,
          );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if ((card?.lostReason ?? '').isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.accentRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${language.translate('meta_card_lost')}: ${card!.lostReason}',
              style: context.textStyles.bodySans,
            ),
          ),
        if (card?.client == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              language.translate('meta_card_not_in_crm'),
              style: context.textStyles.captionSans.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ),
        TextField(
          controller: _name,
          decoration: InputDecoration(
            labelText: language.translate('meta_card_name'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: language.translate('meta_card_phone'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _region,
          decoration: InputDecoration(
            labelText: language.translate('meta_card_region'),
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(language.translate('meta_card_birthday')),
          subtitle: Text(birthday),
          trailing: const Icon(TablerIcons.calendar),
          onTap: _pickBirthday,
        ),
        const SizedBox(height: 8),
        Text(
          language.translate('meta_card_contacts'),
          style: context.textStyles.bodySans.copyWith(fontWeight: FontWeight.w700),
        ),
        if (_contacts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              language.translate('meta_card_no_contacts'),
              style: context.textStyles.captionSans.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ),
        for (var i = 0; i < _contacts.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_contacts[i].name),
            subtitle: Text(
              [
                if ((_contacts[i].phone ?? '').trim().isNotEmpty)
                  displayPhone(_contacts[i].phone),
                if ((_contacts[i].note ?? '').isNotEmpty) _contacts[i].note,
              ].join(' · '),
            ),
            trailing: IconButton(
              icon: const Icon(TablerIcons.trash),
              onPressed: () => setState(() {
                _contacts = [..._contacts]..removeAt(i);
              }),
            ),
          ),
        TextButton.icon(
          onPressed: _addContact,
          icon: const Icon(TablerIcons.plus),
          label: Text(language.translate('meta_card_new_contact')),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(language.translate('meta_card_save')),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _reject,
              child: Text(language.translate('meta_card_reject')),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          language.translate('meta_card_history'),
          style: context.textStyles.bodySans.copyWith(fontWeight: FontWeight.w700),
        ),
        if (_history.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              language.translate('meta_card_history_empty'),
              style: context.textStyles.captionSans.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          )
        else
          for (final entry in _history)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_historyText(language, entry)),
              subtitle: Text(
                [
                  if (entry.user != null && entry.user!.isNotEmpty) entry.user!,
                  if (entry.at != null)
                    formatLocalizedDateTime(
                      context,
                      entry.at!,
                      style: LocalizedDateTimeStyle.dateTime,
                    ),
                ].join(' · '),
              ),
            ),
      ],
    );
  }

  Future<void> _addContact() async {
    final language = context.read<LanguageCubit>();
    final name = TextEditingController();
    final phone = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(language.translate('meta_card_new_contact')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: InputDecoration(
                labelText: language.translate('meta_card_contact_name'),
              ),
            ),
            TextField(
              controller: phone,
              decoration: InputDecoration(
                labelText: language.translate('meta_card_contact_phone'),
              ),
            ),
            TextField(
              controller: note,
              decoration: InputDecoration(
                labelText: language.translate('meta_card_contact_note'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(language.translate('meta_comments_cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(language.translate('meta_card_save')),
          ),
        ],
      ),
    );
    final contactName = name.text.trim();
    final contact = CardContact(
      name: contactName,
      phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
      note: note.text.trim().isEmpty ? null : note.text.trim(),
    );
    name.dispose();
    phone.dispose();
    note.dispose();
    if (ok != true || contactName.isEmpty || !mounted) return;
    setState(() => _contacts = [..._contacts, contact]);
  }

  Widget _events(LanguageCubit language) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (_tasks.isEmpty)
          Text(
            language.translate('meta_tasks_none'),
            style: context.textStyles.bodySans.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        for (final task in _tasks)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(task.title),
            subtitle: Text(
              [
                if ((task.dueDate ?? '').isNotEmpty) _dueLabel(task.dueDate!),
                if ((task.assigneeName ?? '').isNotEmpty) task.assigneeName!,
              ].join(' · '),
            ),
            trailing: TextButton(
              onPressed: () => _finishTask(task),
              child: Text(language.translate('meta_tasks_done')),
            ),
          ),
        const Divider(),
        Text(
          language.translate('meta_tasks_new'),
          style: context.textStyles.bodySans.copyWith(fontWeight: FontWeight.w700),
        ),
        TextField(
          controller: _taskTitle,
          decoration: InputDecoration(
            labelText: language.translate('meta_tasks_title_ph'),
          ),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(language.translate('meta_tasks_due')),
          subtitle: Text(_taskDue == null ? '' : _dueLabel(_taskDue!)),
          onTap: _pickDue,
        ),
        DropdownButton<int?>(
          isExpanded: true,
          value: _staff.any((person) => person.id == _taskAssignee)
              ? _taskAssignee
              : null,
          hint: Text(language.translate('meta_funnel_none')),
          items: [
            for (final person in _staff)
              DropdownMenuItem(value: person.id, child: Text(person.fullName)),
          ],
          onChanged: (value) => setState(() => _taskAssignee = value),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _addTask,
          child: Text(language.translate('meta_tasks_create')),
        ),
      ],
    );
  }

  Future<void> _pickDue() async {
    final initial = DateTime.tryParse(_taskDue ?? '') ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _taskDue =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  Widget _deals(LanguageCubit language) {
    final deals = _card?.deals ?? const <CardDeal>[];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (deals.isEmpty)
          Text(
            language.translate('meta_card_no_deals'),
            style: context.textStyles.bodySans.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        for (final deal in deals)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(deal.title),
            subtitle: Text(
              formatLocalizedNumber(context, deal.amount, maximumFractionDigits: 0),
            ),
            trailing: DropdownButton<String>(
              value: _dealStages.contains(deal.stage) ? deal.stage : 'lead',
              items: [
                for (final stage in _dealStages)
                  DropdownMenuItem(
                    value: stage,
                    child: Text(language.translate('meta_deal_$stage')),
                  ),
              ],
              onChanged: (value) {
                if (value == null || value == deal.stage) return;
                _setDealStage(deal, value);
              },
            ),
          ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _createDeal,
          child: Text(language.translate('meta_card_deal_create')),
        ),
      ],
    );
  }

  Widget _files(LanguageCubit language) {
    final files = _card?.files ?? const <CardFile>[];
    if (files.isEmpty) {
      return Center(child: Text(language.translate('meta_card_no_files')));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        for (final file in files) ...[
          Text(
            file.outgoing
                ? language.translate('meta_card_from_us')
                : language.translate('meta_card_from_client'),
            style: context.textStyles.captionSans.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          MetaAttachments(items: file.attachments, outgoing: file.outgoing, text: file.text),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  String _historyText(LanguageCubit language, CardHistoryEntry entry) {
    final changes = entry.changes;
    final key = switch (entry.action) {
      'thread_stage' => 'meta_history_stage',
      'thread_assign' => 'meta_history_assign',
      'reply' => 'meta_history_reply',
      'link' => 'meta_history_link',
      'client_info' => changes['created'] == true
          ? 'meta_history_client_created'
          : 'meta_history_client_info',
      'deal_create' => 'meta_history_deal_create',
      'deal_stage' => 'meta_history_deal_stage',
      'thread_reject' => 'meta_history_reject',
      'task_create' => 'meta_history_task_create',
      'task_done' => 'meta_history_task_done',
      _ => '',
    };
    if (key.isEmpty) return entry.action;
    return language.translate(
      key,
      params: {
        'from': '${changes['from'] ?? ''}',
        'to': '${changes['to'] ?? language.translate('meta_funnel_none')}',
        'client': '${changes['client'] ?? ''}',
        'title': '${changes['title'] ?? ''}',
        'amount': '${changes['amount'] ?? ''}',
        'stage': '${changes['stage'] ?? ''}',
      },
    );
  }

  String _dueLabel(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) return iso;
    return '${parts[2]}.${parts[1]}.${parts[0]}';
  }
}

String _caughtKey(Object error) {
  final text = error.toString();
  final key = text.startsWith('Exception: ') ? text.substring(11) : text;
  if (key.startsWith('error_') || key.startsWith('meta_')) return key;
  return ErrorKeys.loadFailed;
}
