import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/network/user_facing_error.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../domain/meta_models.dart';
import '../domain/meta_repository.dart';

/// Dialogs grouped by funnel stage. Tapping a card opens the chat.
class MetaFunnelView extends StatefulWidget {
  const MetaFunnelView({
    super.key,
    required this.threads,
    required this.onOpen,
  });

  final List<MetaThread> threads;
  final ValueChanged<MetaThread> onOpen;

  @override
  State<MetaFunnelView> createState() => _MetaFunnelViewState();
}

class _MetaFunnelViewState extends State<MetaFunnelView> {
  var _loading = true;
  String? _error;
  List<MetaStage> _stages = const [];
  List<MetaStaff> _staff = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<MetaRepository>();
    try {
      final stages = await repo.getStages();
      final staff = await repo.getStaff();
      if (!mounted) return;
      setState(() {
        _stages = stages;
        _staff = staff;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = userFacingError(e);
        _loading = false;
      });
    }
  }

  String _assigneeName(int? id, LanguageCubit language) {
    if (id == null) return language.translate('meta_funnel_none');
    for (final person in _staff) {
      if (person.id == id) return person.fullName;
    }
    return language.translate('meta_funnel_none');
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageCubit>();
    final colors = context.colors;
    final textStyles = context.textStyles;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text(language.resolveMessage(_error!)));
    }
    final known = _stages.map((s) => s.id).toSet();
    final groups = <MetaStage, List<MetaThread>>{
      for (final stage in _stages) stage: [],
    };
    final loose = <MetaThread>[];
    for (final thread in widget.threads) {
      final stageId = thread.stageId;
      if (stageId != null && known.contains(stageId)) {
        groups[_stages.firstWhere((s) => s.id == stageId)]!.add(thread);
      } else {
        loose.add(thread);
      }
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final stage in _stages) ...[
          Text(
            stage.name,
            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (groups[stage]!.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                language.translate('meta_funnel_empty'),
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            )
          else
            for (final thread in groups[stage]!)
              _FunnelCard(
                thread: thread,
                assignee: _assigneeName(thread.assigneeId, language),
                onTap: () => widget.onOpen(thread),
              ),
        ],
        if (loose.isNotEmpty)
          for (final thread in loose)
            _FunnelCard(
              thread: thread,
              assignee: _assigneeName(thread.assigneeId, language),
              onTap: () => widget.onOpen(thread),
            ),
      ],
    );
  }
}

class _FunnelCard extends StatelessWidget {
  const _FunnelCard({
    required this.thread,
    required this.assignee,
    required this.onTap,
  });

  final MetaThread thread;
  final String assignee;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  thread.displayName,
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  assignee,
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
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
    final stages = await widget.repo.getStages();
    final staff = await widget.repo.getStaff();
    if (!mounted) return;
    setState(() {
      _stages = stages;
      _staff = staff;
      _loading = false;
    });
  }

  Future<void> _stage(int id) async {
    final next = await widget.repo.setThreadStage(widget.thread.id, id);
    widget.onChanged(next);
  }

  Future<void> _assignee(int? id) async {
    final next = await widget.repo.setThreadAssignee(widget.thread.id, id);
    widget.onChanged(next);
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
