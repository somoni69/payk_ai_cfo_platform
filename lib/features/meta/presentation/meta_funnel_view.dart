import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/network/user_facing_error.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../domain/meta_models.dart';
import '../domain/meta_repository.dart';

/// One funnel column at a time. Horizontal kanban does not fit a phone;
/// stage chips plus a vertical list do, and the side buttons move a dialog
/// to the neighbouring stage without a drag gesture.
Color metaStageColor(String hex, Color fallback) {
  var raw = hex.trim();
  if (raw.startsWith('#')) raw = raw.substring(1);
  if (raw.length == 6) raw = 'FF$raw';
  if (raw.length != 8) return fallback;
  final value = int.tryParse(raw, radix: 16);
  if (value == null) return fallback;
  return Color(value);
}

/// Dialogs grouped by funnel stage. Tapping a card opens the client card.
class MetaFunnelView extends StatefulWidget {
  const MetaFunnelView({
    super.key,
    required this.threads,
    required this.onOpen,
    required this.onCard,
    required this.onMoved,
  });

  final List<MetaThread> threads;
  final ValueChanged<MetaThread> onOpen;

  /// Funnel card tap: [tab] 0 is the client profile, 1 is events.
  final void Function(MetaThread thread, int tab) onCard;

  /// Inbox should reload after a stage change so both panes stay in sync.
  final Future<void> Function() onMoved;

  @override
  State<MetaFunnelView> createState() => _MetaFunnelViewState();
}

class _MetaFunnelViewState extends State<MetaFunnelView> {
  static const _channels = ['', 'instagram', 'whatsapp', 'facebook'];

  var _loading = true;
  String? _error;
  List<MetaStage> _stages = const [];
  List<MetaStaff> _staff = const [];
  List<MetaThread> _threads = const [];
  int? _stageId;
  String _channel = '';
  String _query = '';
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _threads = widget.threads;
    _load();
  }

  @override
  void didUpdateWidget(covariant MetaFunnelView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_loading && widget.threads != oldWidget.threads) {
      _threads = widget.threads;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = context.read<MetaRepository>();
    try {
      final stages = await repo.getStages();
      final staff = await repo.getStaff();
      final threads = await repo.getThreads();
      if (!mounted) return;
      setState(() {
        _stages = stages;
        _staff = staff;
        _threads = threads;
        _stageId ??= stages.isEmpty ? null : stages.first.id;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userFacingError(e);
        _loading = false;
      });
    }
  }

  Future<void> _move(MetaThread thread, int stageId) async {
    try {
      await context.read<MetaRepository>().setThreadStage(thread.id, stageId);
      if (!mounted) return;
      await _load();
      await widget.onMoved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
    }
  }

  String _assigneeName(int? id, LanguageCubit language) {
    if (id == null) return language.translate('meta_funnel_none');
    for (final person in _staff) {
      if (person.id == id) return person.fullName;
    }
    return language.translate('meta_funnel_none');
  }

  int _stageIndex(MetaThread thread) {
    final id = thread.stageId;
    final index = _stages.indexWhere((stage) => stage.id == id);
    return index < 0 ? 0 : index;
  }

  List<MetaThread> _visible(String unnamed) {
    final query = _query.trim().toLowerCase();
    final selected = _stageId;
    return [
      for (final thread in _threads)
        if (_channel.isEmpty || thread.channel == _channel)
          if (query.isNotEmpty ||
              selected == null ||
              _stageIndex(thread) ==
                  _stages.indexWhere((stage) => stage.id == selected))
            if (query.isEmpty ||
                thread.titleOr(unnamed).toLowerCase().contains(query) ||
                (thread.lastText ?? '').toLowerCase().contains(query) ||
                (thread.peerPhone ?? '').toLowerCase().contains(query))
              thread,
    ];
  }

  int _count(MetaStage stage) {
    final index = _stages.indexWhere((item) => item.id == stage.id);
    var count = 0;
    for (final thread in _threads) {
      if (_channel.isNotEmpty && thread.channel != _channel) continue;
      if (_stageIndex(thread) == index) count++;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    final colors = context.colors;
    final textStyles = context.textStyles;
    if (_loading && _threads.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _stages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                language.resolveMessage(_error!),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _load,
                child: Text(language.translate('common_retry')),
              ),
            ],
          ),
        ),
      );
    }

    final unnamed = language.translate('meta_unnamed');
    final cards = _visible(unnamed);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _search,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              isDense: true,
              hintText: language.translate('meta_funnel_search'),
              prefixIcon: Icon(
                TablerIcons.search,
                size: 18,
                color: colors.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _channels.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final channel = _channels[index];
              final selected = channel == _channel;
              final label = channel.isEmpty
                  ? language.translate('meta_channel_all')
                  : language.translate('meta_channel_$channel');
              return _ChoiceChip(
                label: label,
                selected: selected,
                onTap: () {
                  setState(() => _channel = channel);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _stages.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final stage = _stages[index];
              final selected = stage.id == _stageId && _query.trim().isEmpty;
              final color = metaStageColor(stage.color, colors.brand);
              return _ChoiceChip(
                label: '${stage.name} ${_count(stage)}',
                selected: selected,
                dot: color,
                onTap: () {
                  _search.clear();
                  setState(() {
                    _query = '';
                    _stageId = stage.id;
                  });
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: cards.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Text(
                            language.translate('meta_funnel_empty'),
                            style: textStyles.bodySans.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: cards.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final thread = cards[index];
                      final stageIndex = _stageIndex(thread);
                      final stage = _stages.isEmpty
                          ? null
                          : _stages[stageIndex];
                      return _FunnelCard(
                        thread: thread,
                        title: thread.titleOr(unnamed),
                        assignee: _assigneeName(thread.assigneeId, language),
                        stage: stage,
                        channelLabel: language.translate(
                          'meta_channel_${thread.channel}',
                        ),
                        canPrev: stageIndex > 0,
                        canNext:
                            _stages.isNotEmpty &&
                            stageIndex < _stages.length - 1,
                        onOpen: () => widget.onOpen(thread),
                        onCard: () => widget.onCard(thread, 0),
                        onEvents: thread.tasksOpen > 0
                            ? () => widget.onCard(thread, 1)
                            : null,
                        onPrev: stageIndex > 0
                            ? () => _move(thread, _stages[stageIndex - 1].id)
                            : null,
                        onNext:
                            _stages.isNotEmpty &&
                                stageIndex < _stages.length - 1
                            ? () => _move(thread, _stages[stageIndex + 1].id)
                            : null,
                        onCall: _call(thread.peerPhone),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  VoidCallback? _call(String? phone) {
    final href = phoneHref(phone);
    if (href == null) return null;
    return () {
      launchUrl(Uri.parse(href));
    };
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.dot,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: selected ? colors.brand.withValues(alpha: 0.12) : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: selected ? colors.brand : colors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dot != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: context.textStyles.captionSans.copyWith(
                  color: selected ? colors.brand : colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FunnelCard extends StatelessWidget {
  const _FunnelCard({
    required this.thread,
    required this.title,
    required this.assignee,
    required this.stage,
    required this.channelLabel,
    required this.canPrev,
    required this.canNext,
    required this.onOpen,
    required this.onCard,
    this.onEvents,
    this.onPrev,
    this.onNext,
    this.onCall,
  });

  final MetaThread thread;
  final String title;
  final String assignee;
  final MetaStage? stage;
  final String channelLabel;
  final bool canPrev;
  final bool canNext;
  final VoidCallback onOpen;
  final VoidCallback onCard;
  final VoidCallback? onEvents;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    final colors = context.colors;
    final textStyles = context.textStyles;
    final accent = stage == null
        ? colors.brand
        : metaStageColor(stage!.color, colors.brand);
    final when = thread.lastMessageAt == null
        ? ''
        : formatLocalizedDateTime(
            context,
            thread.lastMessageAt!,
            style: LocalizedDateTimeStyle.dayMonthTime,
          );
    final initial = title.isEmpty ? '?' : title.characters.first.toUpperCase();

    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.border),
      ),
      child: InkWell(
        onTap: onCard,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: accent.withValues(alpha: 0.16),
                    foregroundColor: accent,
                    child: Text(
                      initial,
                      style: textStyles.captionSans.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          when.isEmpty ? channelLabel : '$channelLabel · $when',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (thread.tasksOpen > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: TextButton(
                        onPressed: onEvents,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          '${language.translate('meta_funnel_events')} ${thread.tasksOpen}',
                        ),
                      ),
                    ),
                  if (thread.unread > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.brand,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${thread.unread}',
                        style: textStyles.smallSans.copyWith(
                          color: colors.onBrand,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              if ((thread.lastText ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  thread.lastText!.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  IconButton(
                    tooltip: language.translate('meta_funnel_prev'),
                    onPressed: canPrev ? onPrev : null,
                    icon: const Icon(TablerIcons.chevron_left, size: 20),
                  ),
                  IconButton(
                    tooltip: language.translate('meta_funnel_next'),
                    onPressed: canNext ? onNext : null,
                    icon: const Icon(TablerIcons.chevron_right, size: 20),
                  ),
                  const Spacer(),
                  if (assignee != language.translate('meta_funnel_none'))
                    Flexible(
                      child: Text(
                        assignee,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textStyles.smallSans.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  if (onCall != null)
                    IconButton(
                      tooltip: language.translate('meta_funnel_call'),
                      onPressed: onCall,
                      icon: Icon(
                        TablerIcons.phone,
                        size: 18,
                        color: colors.brand,
                      ),
                    ),
                  IconButton(
                    tooltip: language.translate('meta_funnel_open'),
                    onPressed: onOpen,
                    icon: Icon(
                      TablerIcons.message,
                      size: 18,
                      color: colors.brand,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stage and assignee for the open dialog.
Future<MetaThread?> showMetaFunnelSheet(
  BuildContext context,
  MetaThread thread,
) {
  final language = context.read<LanguageCubit>();
  final repo = context.read<MetaRepository>();
  return LedgerBottomSheet.show<MetaThread>(
    context: context,
    title: language.translate('meta_tab_funnel'),
    builder: (ctx, setSheetState) {
      return _FunnelSheetBody(
        thread: thread,
        repo: repo,
        onChanged: (next) => Navigator.of(ctx).pop(next),
      );
    },
  );
}

class _FunnelSheetBody extends StatefulWidget {
  const _FunnelSheetBody({
    required this.thread,
    required this.repo,
    required this.onChanged,
  });

  final MetaThread thread;
  final MetaRepository repo;
  final ValueChanged<MetaThread> onChanged;

  @override
  State<_FunnelSheetBody> createState() => _FunnelSheetBodyState();
}

class _FunnelSheetBodyState extends State<_FunnelSheetBody> {
  var _loading = true;
  List<MetaStage> _stages = const [];
  List<MetaStaff> _staff = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final stages = await widget.repo.getStages();
      final staff = await widget.repo.getStaff();
      if (!mounted) return;
      setState(() {
        _stages = stages;
        _staff = staff;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
    }
  }

  Future<void> _stage(int id) async {
    try {
      final next = await widget.repo.setThreadStage(widget.thread.id, id);
      widget.onChanged(next);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
    }
  }

  Future<void> _assignee(int? id) async {
    try {
      final next = await widget.repo.setThreadAssignee(widget.thread.id, id);
      widget.onChanged(next);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(language.translate('meta_funnel_stage')),
        const SizedBox(height: 8),
        for (final stage in _stages)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(stage.name),
            trailing: stage.id == widget.thread.stageId
                ? Icon(Icons.check, color: context.colors.brand)
                : null,
            onTap: () => _stage(stage.id),
          ),
        const SizedBox(height: 12),
        Text(language.translate('meta_funnel_assignee')),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(language.translate('meta_funnel_none')),
          trailing: widget.thread.assigneeId == null
              ? Icon(Icons.check, color: context.colors.brand)
              : null,
          onTap: () => _assignee(null),
        ),
        for (final person in _staff)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(person.fullName),
            trailing: person.id == widget.thread.assigneeId
                ? Icon(Icons.check, color: context.colors.brand)
                : null,
            onTap: () => _assignee(person.id),
          ),
      ],
    );
  }
}
