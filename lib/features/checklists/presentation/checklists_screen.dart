import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/auth/bloc/auth_state.dart';
import '../../../features/auth/domain/app_access.dart';
import '../../../features/checklists/bloc/checklists_bloc.dart';
import '../../../features/checklists/bloc/checklists_event.dart';
import '../../../features/checklists/bloc/checklists_state.dart';
import '../../../features/checklists/domain/checklist_models.dart';
import '../../../features/checklists/domain/checklists_repository.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../../../presentation/widgets/ledger_card.dart';
import '../../../presentation/widgets/ledger_collapsing_header.dart';
import '../../../presentation/widgets/ledger_pill.dart';

class ChecklistsScreen extends StatelessWidget {
  const ChecklistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ChecklistsBloc>(
      create: (context) =>
          ChecklistsBloc(context.read<ChecklistsRepository>())
            ..add(const LoadChecklists()),
      child: const ChecklistsView(),
    );
  }
}

class ChecklistsView extends StatefulWidget {
  const ChecklistsView({super.key});

  @override
  State<ChecklistsView> createState() => _ChecklistsViewState();
}

class _ChecklistsViewState extends State<ChecklistsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showNewRunModal(BuildContext context) {
    final colors = context.colors;
    final locale = context.read<LanguageCubit>();
    final titleCtrl = TextEditingController();
    final branchCtrl = TextEditingController();
    final itemCtrl = TextEditingController();
    final List<String> items = [];

    LedgerBottomSheet.show(
      context: context,
      title: locale.translate('checklists_new'),
      builder: (context, setSheetState) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: titleCtrl,
            decoration: InputDecoration(
              labelText: locale.translate('checklists_template_title'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: branchCtrl,
            decoration: InputDecoration(
              labelText: locale.translate('checklists_branch_point'),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: itemCtrl,
                  decoration: InputDecoration(
                    labelText: locale.translate('checklists_item_label'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(TablerIcons.plus, color: colors.brand),
                onPressed: () {
                  if (itemCtrl.text.trim().isNotEmpty) {
                    setSheetState(() {
                      items.add(itemCtrl.text.trim());
                      itemCtrl.clear();
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: items
                  .map(
                    (it) => Chip(
                      label: Text(it),
                      onDeleted: () {
                        setSheetState(() {
                          items.remove(it);
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              context.read<ChecklistsBloc>().add(
                CreateChecklistRunRequested(
                  title: titleCtrl.text.trim(),
                  branchName: branchCtrl.text.trim().isEmpty
                      ? 'checklists_office_main'
                      : branchCtrl.text.trim(),
                  responsiblePerson: 'checklists_auto_responsible',
                  items: items.isEmpty
                      ? [
                          'checklists_default_item_equipment',
                          'checklists_default_item_cash',
                        ]
                      : items,
                ),
              );
              Navigator.pop(context);
            },
            child: Text(locale.translate('save_to_ledger')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();
    final authState = context.watch<AuthBloc>().state;
    final canManage =
        authState is AuthAuthenticated &&
        authState.role.canManage(AppCapability.checklists);

    return Scaffold(
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showNewRunModal(context),
              backgroundColor: colors.brand,
              foregroundColor: Colors.white,
              icon: const Icon(TablerIcons.plus),
              label: Text(
                locale.translate('checklists_new'),
                style: textStyles.bodySans.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          : null,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            LedgerCollapsingHeader(
              title: locale.translate('checklists_title'),
              pinned: true,
              floating: true,
              snap: true,
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: colors.brand,
                labelColor: colors.brand,
                unselectedLabelColor: colors.textSecondary,
                tabs: [
                  Tab(text: locale.translate('checklists_tab_runs')),
                  Tab(text: locale.translate('checklists_tab_templates')),
                  Tab(text: locale.translate('checklists_tab_summary')),
                ],
              ),
            ),
          ];
        },
        body: BlocBuilder<ChecklistsBloc, ChecklistsState>(
          builder: (context, state) {
            if (state is ChecklistsLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is ChecklistsError) {
              return Center(child: Text(state.message));
            }
            if (state is ChecklistsLoaded) {
              return TabBarView(
                controller: _tabController,
                children: [
                  _buildRunsTab(context, state.todayRuns),
                  _buildTemplatesTab(context),
                  _buildSummaryTab(context, state.todayRuns),
                ],
              );
            }
            return const SizedBox();
          },
        ),
      ),
    );
  }

  Widget _buildRunsTab(BuildContext context, List<ChecklistRun> runs) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    if (runs.isEmpty) {
      return Center(
        child: Text(
          context.read<LanguageCubit>().translate('checklists_empty'),
          style: textStyles.bodySans.copyWith(color: colors.textSecondary),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<ChecklistsBloc>().add(
          const LoadChecklists(forceRefresh: true),
        );
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: runs.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final run = runs[index];
          final progressPercent = run.progressPercentage;

          return LedgerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        run.title,
                        style: textStyles.h2Sans.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    LedgerPill(
                      text:
                          '${(progressPercent * 100).toInt()}% ${run.doneCount}/${run.totalCount}',
                      backgroundColor: progressPercent == 1.0
                          ? colors.accentGreen.withValues(alpha: 0.1)
                          : colors.brand.withValues(alpha: 0.1),
                      textColor: progressPercent == 1.0
                          ? colors.accentGreen
                          : colors.brand,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${run.branchName} • ${run.responsiblePerson}',
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressPercent,
                    backgroundColor: colors.border,
                    color: progressPercent == 1.0
                        ? colors.accentGreen
                        : colors.brand,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(),
                ...run.entries.map(
                  (entry) => CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      entry.text,
                      style: textStyles.bodySans.copyWith(
                        decoration: entry.isDone
                            ? TextDecoration.lineThrough
                            : null,
                        color: entry.isDone
                            ? colors.textSecondary
                            : colors.textPrimary,
                      ),
                    ),
                    value: entry.isDone,
                    activeColor: colors.brand,
                    onChanged: (val) {
                      if (val != null) {
                        context.read<ChecklistsBloc>().add(
                          ToggleEntryRequested(
                            runId: run.id,
                            entryId: entry.id,
                            isDone: val,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTemplatesTab(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    final locale = context.read<LanguageCubit>();
    final templates = [
      {
        'name': locale.translate('checklists_tpl_open_shift'),
        'count': 5,
        'branch': locale.translate('users_branch_main'),
      },
      {
        'name': locale.translate('checklists_tpl_close_shift'),
        'count': 6,
        'branch': locale.translate('users_branch_main'),
      },
      {
        'name': locale.translate('checklists_tpl_cleanliness'),
        'count': 4,
        'branch': locale.translate('checklists_retail'),
      },
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: templates.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final t = templates[index];
        return LedgerCard(
          child: Row(
            children: [
              Icon(TablerIcons.file_text, size: 28, color: colors.brand),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t['name'] as String,
                      style: textStyles.bodySans.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      locale.translate(
                        'checklists_tasks_count',
                        params: {'count': t['count'], 'branch': t['branch']},
                      ),
                      style: textStyles.captionSans.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(TablerIcons.chevron_right, color: colors.textSecondary),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryTab(BuildContext context, List<ChecklistRun> runs) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    final totalRuns = runs.length;
    final completedRuns = runs.where((r) => r.progressPercentage == 1.0).length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          LedgerCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '$totalRuns',
                      style: textStyles.h1Sans.copyWith(
                        color: colors.brand,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.read<LanguageCubit>().translate(
                        'checklists_total_shifts',
                      ),
                      style: textStyles.captionSans.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      '$completedRuns',
                      style: textStyles.h1Sans.copyWith(
                        color: colors.accentGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.read<LanguageCubit>().translate(
                        'checklists_fully_done',
                      ),
                      style: textStyles.captionSans.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
