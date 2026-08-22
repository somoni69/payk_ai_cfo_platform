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
import '../../../presentation/widgets/ledger_shimmer.dart';

enum ChecklistSection { runs, templates, summary }

String _checklistSectionTitle(LanguageCubit language, ChecklistSection section) {
  return language.translate(switch (section) {
    ChecklistSection.runs => 'checklists_tab_runs',
    ChecklistSection.templates => 'checklists_tab_templates',
    ChecklistSection.summary => 'checklists_tab_summary',
  });
}

void _openChecklistSection(BuildContext context, ChecklistSection section) {
  final bloc = context.read<ChecklistsBloc>();
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: ChecklistSectionScreen(section: section),
      ),
    ),
  );
}

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

class _ChecklistsViewState extends State<ChecklistsView> {
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
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          locale.translate('checklists_title'),
          style: textStyles.h2Sans.copyWith(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: colors.border),
        ),
      ),
      body: BlocBuilder<ChecklistsBloc, ChecklistsState>(
        builder: (context, state) {
          if (state is ChecklistsLoading) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: LedgerListShimmer(itemCount: 5),
            );
          }
          if (state is ChecklistsError) {
            return Center(child: Text(state.message));
          }
          if (state is ChecklistsLoaded) {
            return _buildChecklistsOverviewHub(context, state, canManage);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildChecklistsOverviewHub(
    BuildContext context,
    ChecklistsLoaded state,
    bool canManage,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();

    final totalRuns = state.todayRuns.length;
    final completedRuns = state.todayRuns
        .where((r) => r.progressPercentage >= 1.0)
        .length;
    final pendingRuns = totalRuns - completedRuns;

    int totalItems = 0;
    int totalDone = 0;
    for (final run in state.todayRuns) {
      totalItems += run.totalCount;
      totalDone += run.doneCount;
    }
    final overallProgress = totalItems > 0 ? (totalDone / totalItems) : 1.0;

    return RefreshIndicator(
      onRefresh: () async {
        context.read<ChecklistsBloc>().add(
          const LoadChecklists(forceRefresh: true),
        );
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // 1. Hero Card: Execution & Compliance
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        locale.translate('checklists_hero_title'),
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w500,
                          fontSize: 13.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: overallProgress >= 1.0
                            ? colors.accentGreen.withValues(alpha: 0.1)
                            : colors.brand.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            overallProgress >= 1.0
                                ? TablerIcons.circle_check
                                : TablerIcons.list_check,
                            size: 13,
                            color: overallProgress >= 1.0
                                ? colors.accentGreen
                                : colors.brand,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${(overallProgress * 100).toInt()}%',
                            style: textStyles.captionSans.copyWith(
                              color: overallProgress >= 1.0
                                  ? colors.accentGreen
                                  : colors.brand,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '$totalDone из $totalItems пунктов выполнено',
                  style: textStyles.h2Sans.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: overallProgress,
                    backgroundColor: colors.surfaceNested,
                    color: overallProgress >= 1.0
                        ? colors.accentGreen
                        : colors.brand,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: colors.border),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(TablerIcons.clock, size: 16, color: colors.brand),
                    const SizedBox(width: 6),
                    Text(
                      '$totalRuns ${locale.translate('checklists_runs_count', params: {'count': ''}).toLowerCase()}',
                      style: textStyles.captionSans.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• ${state.templates.length} ${locale.translate('checklists_tab_templates').toLowerCase()}',
                      style: textStyles.captionSans.copyWith(
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. Actionable Attention Card
          InkWell(
            onTap: () => _openChecklistSection(
              context,
              pendingRuns > 0
                  ? ChecklistSection.runs
                  : ChecklistSection.templates,
            ),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: pendingRuns > 0
                      ? colors.brand.withValues(alpha: 0.4)
                      : colors.accentGreen.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: pendingRuns > 0
                          ? colors.brand.withValues(alpha: 0.08)
                          : colors.accentGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      pendingRuns > 0
                          ? TablerIcons.clipboard_list
                          : TablerIcons.circle_check,
                      color: pendingRuns > 0
                          ? colors.brand
                          : colors.accentGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locale.translate('checklists_attention_title'),
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          pendingRuns > 0
                              ? locale.translate(
                                  'checklists_attention_active',
                                  params: {'count': '$pendingRuns'},
                                )
                              : locale.translate('checklists_attention_ok'),
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
          const SizedBox(height: 12),

          // 3. Quick Action Buttons Row (if canManage)
          if (canManage) ...[
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () => _openChecklistSection(
                        context,
                        ChecklistSection.runs,
                      ),
                      icon: const Icon(TablerIcons.list_check, size: 17),
                      label: Text(
                        locale.translate('checklists_action_open'),
                        style: textStyles.captionSans.copyWith(
                          color: colors.surface,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.brand,
                        foregroundColor: colors.surface,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () => _showTemplateModal(context),
                      icon: const Icon(TablerIcons.plus, size: 17),
                      label: Text(
                        locale.translate('checklists_action_template'),
                        style: textStyles.captionSans.copyWith(
                          color: colors.brand,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.brand,
                        side: BorderSide(color: colors.border),
                        minimumSize: const Size.fromHeight(44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // 4. Main 2x2 Navigation Grid
          Row(
            children: [
              Expanded(
                child: _buildHubCard(
                  context,
                  title: locale.translate('checklists_tab_runs'),
                  subtitle: locale.translate(
                    'checklists_runs_count',
                    params: {'count': '${state.todayRuns.length}'},
                  ),
                  icon: TablerIcons.calendar_event,
                  onTap: () => _openChecklistSection(
                    context,
                    ChecklistSection.runs,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHubCard(
                  context,
                  title: locale.translate('checklists_tab_templates'),
                  subtitle: '${state.templates.length} регламентов',
                  icon: TablerIcons.file_text,
                  onTap: () => _openChecklistSection(
                    context,
                    ChecklistSection.templates,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildHubCard(
                  context,
                  title: locale.translate('checklists_tab_summary'),
                  subtitle: '$completedRuns из $totalRuns смен закрыто',
                  icon: TablerIcons.chart_bar,
                  onTap: () => _openChecklistSection(
                    context,
                    ChecklistSection.summary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 5. Recent Checklist Runs Feed
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                locale.translate('checklists_recent_runs'),
                style: textStyles.h2Sans.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () => _openChecklistSection(
                  context,
                  ChecklistSection.runs,
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  children: [
                    Text(
                      locale.translate('checklists_all_runs'),
                      style: textStyles.captionSans.copyWith(
                        color: colors.brand,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      TablerIcons.chevron_right,
                      size: 14,
                      color: colors.brand,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (state.todayRuns.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              alignment: Alignment.center,
              child: Text(
                locale.translate('checklists_empty'),
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                  fontSize: 13.5,
                ),
              ),
            )
          else
            ...state.todayRuns.take(3).map((run) {
              final progressPercent = run.progressPercentage;
              final isDone = progressPercent >= 1.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              run.title,
                              style: textStyles.bodySans.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isDone
                                  ? colors.accentGreen.withValues(alpha: 0.1)
                                  : colors.brand.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${(progressPercent * 100).toInt()}% · ${run.doneCount}/${run.totalCount}',
                              style: textStyles.captionSans.copyWith(
                                color: isDone
                                    ? colors.accentGreen
                                    : colors.brand,
                                fontWeight: FontWeight.w600,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${run.branchName} • ${run.responsiblePerson}',
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progressPercent,
                          backgroundColor: colors.surfaceNested,
                          color: isDone ? colors.accentGreen : colors.brand,
                          minHeight: 5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...run.entries.take(3).map(
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
                              fontSize: 13.5,
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
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildHubCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
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
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors.brand.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 20, color: colors.brand),
                  ),
                  Icon(
                    TablerIcons.chevron_right,
                    size: 16,
                    color: colors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
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

class ChecklistSectionScreen extends StatelessWidget {
  final ChecklistSection section;

  const ChecklistSectionScreen({super.key, required this.section});

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
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
        title: Text(
          _checklistSectionTitle(locale, section),
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
      floatingActionButton: canManage && section == ChecklistSection.templates
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => _showTemplateModal(context),
              backgroundColor: colors.brand,
              foregroundColor: colors.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              icon: const Icon(TablerIcons.plus),
              label: Text(
                locale.translate('checklists_new_template'),
                style: textStyles.bodySans.copyWith(
                  color: colors.surface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
      body: BlocBuilder<ChecklistsBloc, ChecklistsState>(
        builder: (context, state) {
          if (state is ChecklistsLoading) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: LedgerListShimmer(itemCount: 4),
            );
          }
          if (state is! ChecklistsLoaded) {
            return const SizedBox.shrink();
          }

          return switch (section) {
            ChecklistSection.runs => _buildRunsTab(context, state.todayRuns),
            ChecklistSection.templates => _buildTemplatesTab(
                context,
                state.templates,
                canManage,
              ),
            ChecklistSection.summary => _buildSummaryTab(
                context,
                state.summary,
              ),
          };
        },
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
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
        itemCount: runs.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final run = runs[index];
          final progressPercent = run.progressPercentage;
          final isDone = progressPercent >= 1.0;

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        run.title,
                        style: textStyles.bodySans.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isDone
                            ? colors.accentGreen.withValues(alpha: 0.1)
                            : colors.brand.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${(progressPercent * 100).toInt()}% · ${run.doneCount}/${run.totalCount}',
                        style: textStyles.captionSans.copyWith(
                          color: isDone ? colors.accentGreen : colors.brand,
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${run.branchName} • ${run.responsiblePerson}',
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progressPercent,
                    backgroundColor: colors.surfaceNested,
                    color: isDone ? colors.accentGreen : colors.brand,
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 10),
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

  Widget _buildTemplatesTab(
    BuildContext context,
    List<ChecklistTemplate> templates,
    bool canManage,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.read<LanguageCubit>();

    if (templates.isEmpty) {
      return Center(
        child: Text(
          locale.translate('checklists_templates_empty'),
          style: textStyles.bodySans.copyWith(color: colors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
      itemCount: templates.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final t = templates[index];
        return InkWell(
          onTap: canManage
              ? () => _showTemplateModal(context, template: t)
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colors.brand.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        TablerIcons.file_text,
                        size: 20,
                        color: colors.brand,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.name,
                            style: textStyles.bodySans.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                            ),
                          ),
                          Text(
                            locale.translate(
                              'checklists_tasks_count',
                              params: {
                                'count': t.items.length,
                                'branch': t.branchName ?? '—',
                              },
                            ),
                            style: textStyles.captionSans.copyWith(
                              color: colors.textSecondary,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (t.regulationText != null && t.regulationText!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    t.regulationText!,
                    style: textStyles.captionSans.copyWith(
                      color: colors.textSecondary,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryTab(
    BuildContext context,
    List<ChecklistSummaryRow> summary,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.read<LanguageCubit>();

    final totalRuns = summary.length;
    final completedRuns = summary.where((r) => r.percent >= 100).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    '$totalRuns',
                    style: textStyles.h1Sans.copyWith(
                      color: colors.brand,
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    locale.translate('checklists_total_shifts'),
                    style: textStyles.captionSans.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(width: 1, height: 40, color: colors.border),
              Column(
                children: [
                  Text(
                    '$completedRuns',
                    style: textStyles.h1Sans.copyWith(
                      color: colors.accentGreen,
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    locale.translate('checklists_fully_done'),
                    style: textStyles.captionSans.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (summary.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            alignment: Alignment.center,
            child: Text(
              locale.translate('checklists_summary_empty'),
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
              ),
            ),
          )
        else
          ...summary.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.checklistName,
                            style: textStyles.bodySans.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                            ),
                          ),
                          if (row.branchName != null)
                            Text(
                              row.branchName!,
                              style: textStyles.captionSans.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '${row.doneCount}/${row.totalCount} · ${row.percent.toStringAsFixed(0)}%',
                      style: textStyles.bodyMono.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: colors.brand,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

void _showTemplateModal(BuildContext context, {ChecklistTemplate? template}) {
  final checklistsBloc = context.read<ChecklistsBloc>();
  final colors = context.colors;
  final locale = context.read<LanguageCubit>();
  final titleCtrl = TextEditingController(text: template?.name ?? '');
  final regCtrl = TextEditingController(text: template?.regulationText ?? '');
  final itemCtrl = TextEditingController();
  final List<String> items = List<String>.from(
    template?.items.map((i) => i.text) ?? [],
  );

  LedgerBottomSheet.show(
    context: context,
    title: template == null
        ? locale.translate('checklists_new_template')
        : template.name,
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
          controller: regCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: locale.translate('checklists_regulation'),
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
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              checklistsBloc.add(
                CreateTemplateRequested(
                  name: titleCtrl.text.trim(),
                  regulationText: regCtrl.text.trim().isEmpty
                      ? null
                      : regCtrl.text.trim(),
                  items: items,
                ),
              );
              Navigator.pop(context);
            },
            child: Text(
              locale.translate(
                template == null ? 'common_create' : 'common_save',
              ),
            ),
          ),
        ),
        if (template != null) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                checklistsBloc.add(DeleteTemplateRequested(template.id));
                Navigator.pop(context);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.accentRed,
                side: BorderSide(
                  color: colors.accentRed.withValues(alpha: 0.5),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(TablerIcons.trash, size: 18),
              label: Text(locale.translate('common_delete')),
            ),
          ),
        ],
      ],
    ),
  );
}
