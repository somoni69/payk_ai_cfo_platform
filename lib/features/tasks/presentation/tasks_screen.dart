import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/auth/bloc/auth_state.dart';
import '../../../features/auth/domain/app_access.dart';
import '../../../features/tasks/bloc/tasks_bloc.dart';
import '../../../features/tasks/bloc/tasks_event.dart';
import '../../../features/tasks/bloc/tasks_state.dart';
import '../../../features/tasks/domain/tasks_repository.dart';
import '../../../features/tasks/domain/task_model.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';
import '../../../presentation/widgets/expansible_widget.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../../assistant/presentation/ledger_ai_assistant.dart';

part 'tasks_list.dart';
part 'tasks_forms.dart';
part 'tasks_calendar.dart';
part 'tasks_analysis.dart';
part 'tasks_widgets.dart';
part 'tasks_my.dart';
part 'unified_task_card.dart';

/// Входная точка планировщика задач с внедрением TasksBloc.
class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      context.read<TasksBloc>();
      return const TasksView();
    } catch (_) {
      return BlocProvider<TasksBloc>(
        create: (context) =>
            TasksBloc(context.read<TasksRepository>())..add(const LoadTasks()),
        child: const TasksView(),
      );
    }
  }
}

enum TaskSection { myTasks, allTasks, calendar, analytics }

String _taskSectionTitle(LanguageCubit language, TaskSection section) {
  return language.translate(switch (section) {
    TaskSection.myTasks => 'tasks_tab_my_tasks',
    TaskSection.allTasks => 'tasks_tab_all_tasks',
    TaskSection.calendar => 'tasks_tab_calendar',
    TaskSection.analytics => 'tasks_tab_analytics',
  });
}

void _openTaskSection(
  BuildContext context,
  TaskSection section, {
  bool onlyOverdue = false,
}) {
  final bloc = context.read<TasksBloc>();
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: TaskSectionScreen(
          section: section,
          initialOnlyOverdue: onlyOverdue,
        ),
      ),
    ),
  );
}

mixin _TasksViewMixin<T extends StatefulWidget> on State<T> {
  // Filters state
  String _searchQuery = '';
  String? _selectedProjectId;
  TaskStatus? _selectedStatusFilter;
  bool _onlyOverdue = false;

  // Calendar state
  bool _isGanttMode = false;
  DateTime _calendarMonth = DateTime.now();
  DateTime? _selectedCalendarDay = DateTime.now();

  Future<void> _refreshTasks(BuildContext context) async {
    final bloc = context.read<TasksBloc>();
    final boardDone = Completer<void>();
    bloc.add(LoadTasks(forceRefresh: true, completion: boardDone));
    final mineDone = Completer<void>();
    bloc.add(LoadMyTasks(forceRefresh: true, completion: mineDone));
    await Future.wait([boardDone.future, mineDone.future]);
  }

  void _rebuild([VoidCallback? fn]) {
    if (mounted) setState(fn ?? () {});
  }

  bool _canManageTasks(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated &&
        authState.role.canManage(AppCapability.tasks);
  }

  List<Task> _getWorkloadTasks(TasksLoaded state) {
    return _getFilteredTasks(
      state.workloadTasks,
      applyProjectFilter: false,
    ).where((task) {
      if (_selectedProjectId == null || _selectedProjectId!.isEmpty) {
        return true;
      }
      if (task.isPersonal) return true;
      return task.projectId == _selectedProjectId;
    }).toList();
  }

  List<Task> _getFilteredTasks(
    List<Task> tasks, {
    bool applyProjectFilter = true,
  }) {
    return tasks.where((task) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesTitle = task.title.toLowerCase().contains(query);
        final matchesDesc = task.description.toLowerCase().contains(query);
        if (!matchesTitle && !matchesDesc) return false;
      }
      if (applyProjectFilter &&
          _selectedProjectId != null &&
          _selectedProjectId!.isNotEmpty) {
        if (task.projectId != _selectedProjectId) return false;
      }
      if (_onlyOverdue) {
        final isDone = task.status == TaskStatus.done;
        final isOverdue = task.dueDate.isBefore(DateTime.now()) && !isDone;
        if (!isOverdue) return false;
      }
      return true;
    }).toList();
  }

  Widget _buildProjectFilterBar(
    BuildContext context,
    List<TaskProject> projects,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    return Container(
      height: 32,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: projects.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final project = isAll ? null : projects[index - 1];
          final isSelected = isAll
              ? (_selectedProjectId == null)
              : (_selectedProjectId == project!.id);

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedProjectId = isAll ? null : project!.id;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? colors.brand : colors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? colors.brand : colors.border,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                isAll
                    ? language.translate('tasks_filter_all_projects')
                    : project!.name,
                style: textStyles.captionSans.copyWith(
                  color: isSelected ? Colors.white : colors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 11.5,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class TasksView extends StatefulWidget {
  const TasksView({super.key});

  @override
  State<TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends State<TasksView> with _TasksViewMixin {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bloc = context.read<TasksBloc>();
      if (bloc.state is! TasksLoaded) {
        bloc.add(const LoadTasks());
      }
      bloc.add(const LoadMyTasks());
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final canManage = _canManageTasks(context);

    return Scaffold(
      backgroundColor: colors.background,
      floatingActionButtonLocation: kLedgerShellFabLocation,
      floatingActionButton: const LedgerAiFloatingButton(),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              pinned: true,
              elevation: 0,
              scrolledUnderElevation: 1.0,
              backgroundColor: colors.surface,
              surfaceTintColor: colors.surface,
              centerTitle: false,
              title: Text(
                language.translate('tasks_title'),
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
          ];
        },
        body: BlocConsumer<TasksBloc, TasksState>(
          listenWhen: (previous, current) {
            if (current is! TasksLoaded) return false;
            return current.actionMessage != null;
          },
          listener: (context, state) {
            if (state is! TasksLoaded || state.actionMessage == null) return;
            final msg = state.actionMessage!;
            final text = msg.startsWith('tasks_') || msg.startsWith('error_')
                ? language.translate(msg)
                : language.translateMessage(msg);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(text)));
          },
          builder: (context, state) {
            if (state is TasksLoading) {
              return const TasksOverviewShimmer();
            }

            if (state is TasksError) {
              return Center(
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
                          context.read<TasksBloc>().add(LoadTasks());
                        },
                        child: Text(language.translate('tasks_retry')),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (state is TasksLoaded) {
              return _buildTasksOverviewHub(context, state, canManage);
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildTasksOverviewHub(
    BuildContext context,
    TasksLoaded state,
    bool canManage,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    final totalTasks = state.tasks.length;
    final completedTasks =
        state.tasks.where((t) => t.status == TaskStatus.done).length;
    final overdueTasks = state.tasks
        .where((t) => t.dueDate.isBefore(DateTime.now()) && t.status != TaskStatus.done)
        .toList();
    final progress = totalTasks > 0 ? (completedTasks / totalTasks) : 0.0;

    final myTasksCount = state.myTasks.length + state.assignedToMe.length;
    final myOverdueCount = state.myTasks
        .where((t) => t.dueDate.isBefore(DateTime.now()) && t.status != TaskStatus.done)
        .length;

    // Recent 5 tasks for the feed
    final recentTasks = state.tasks.take(5).toList();

    return RefreshIndicator(
      onRefresh: () => _refreshTasks(context),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16 + kLiquidNavClearance),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Hero Progress & Metrics Card
            Container(
              padding: const EdgeInsets.all(16),
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
                      Text(
                        language.translate('tasks_progress_title'),
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      GestureDetector(
                        onTap: overdueTasks.isNotEmpty
                            ? () => _openTaskSection(
                                context,
                                TaskSection.allTasks,
                                onlyOverdue: true,
                              )
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: overdueTasks.isNotEmpty
                                ? colors.accentRed.withValues(alpha: 0.1)
                                : colors.accentGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            overdueTasks.isNotEmpty
                                ? '${overdueTasks.length} ${language.translate('tasks_overdue')}'
                                : language.translate('tasks_status_done'),
                            style: textStyles.captionSans.copyWith(
                              color: overdueTasks.isNotEmpty
                                  ? colors.accentRed
                                  : colors.accentGreen,
                              fontWeight: FontWeight.w600,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$completedTasks / $totalTasks',
                        style: textStyles.h1Sans.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: textStyles.h2Sans.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: colors.brand,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: colors.border.withValues(alpha: 0.4),
                      valueColor: AlwaysStoppedAnimation<Color>(colors.brand),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. Actionable Attention Card
            if (overdueTasks.isNotEmpty)
              InkWell(
                onTap: () => _openTaskSection(
                  context,
                  TaskSection.allTasks,
                  onlyOverdue: true,
                ),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.accentRed.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colors.accentRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          TablerIcons.alert_triangle,
                          color: colors.accentRed,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${language.translate('tasks_overdue')}: ${overdueTasks.length}',
                              style: textStyles.bodySans.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 14.5,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              overdueTasks.first.title,
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
                      Icon(
                        TablerIcons.chevron_right,
                        size: 18,
                        color: colors.textSecondary,
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.accentGreen.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colors.accentGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        TablerIcons.circle_check,
                        color: colors.accentGreen,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            language.translate('tasks_all_on_track'),
                            style: textStyles.bodySans.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            language.translate('tasks_no_critical_delays'),
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
              ),
            const SizedBox(height: 12),

            // 3. Quick Action Buttons Row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showPersonalTaskSheet(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.brand,
                      foregroundColor: colors.surface,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(TablerIcons.plus, size: 18),
                    label: Text(
                      language.translate('tasks_fab_personal'),
                      style: textStyles.captionSans.copyWith(
                        color: colors.surface,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                if (canManage) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showAddTaskBottomSheet(
                        context,
                        state.projects,
                        state.assignees,
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: colors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: Icon(
                        TablerIcons.users_group,
                        size: 18,
                        color: colors.textPrimary,
                      ),
                      label: Text(
                        language.translate('tasks_fab_team'),
                        style: textStyles.captionSans.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),

            // 4. Navigation Grid (2x2)
            Row(
              children: [
                Expanded(
                  child: _buildTaskHubCard(
                    context: context,
                    icon: TablerIcons.user_check,
                    iconColor: colors.brand,
                    title: language.translate('tasks_tab_my_tasks'),
                    badge: '$myTasksCount шт.',
                    subtitle: myOverdueCount > 0
                        ? '$myOverdueCount ${language.translate('tasks_overdue')}'
                        : language.translate('tasks_status_in_progress'),
                    onTap: () => _openTaskSection(context, TaskSection.myTasks),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTaskHubCard(
                    context: context,
                    icon: TablerIcons.list_details,
                    iconColor: colors.brand,
                    title: language.translate('tasks_tab_all_tasks'),
                    badge: '$totalTasks шт.',
                    subtitle: language.translate('tasks_all_projects'),
                    onTap: () => _openTaskSection(context, TaskSection.allTasks),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildTaskHubCard(
                    context: context,
                    icon: TablerIcons.calendar_time,
                    iconColor: colors.accentAmber,
                    title: language.translate('tasks_tab_calendar'),
                    badge: 'Timeline',
                    subtitle: language.translate('tasks_calendar_gantt'),
                    onTap: () => _openTaskSection(context, TaskSection.calendar),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTaskHubCard(
                    context: context,
                    icon: TablerIcons.chart_dots_3,
                    iconColor: colors.accentGreen,
                    title: language.translate('tasks_tab_analytics'),
                    badge: 'AI CFO',
                    subtitle: language.translate('tasks_ai_insights'),
                    onTap: () => _openTaskSection(context, TaskSection.analytics),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 5. Recent Activity Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  language.translate('tasks_recent_urgent'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: colors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () => _openTaskSection(context, TaskSection.allTasks),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      Icon(TablerIcons.arrow_right, size: 14, color: colors.brand),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 6. Recent Tasks List
            if (recentTasks.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: Center(
                  child: Text(
                    language.translate('tasks_no_tasks'),
                    style: textStyles.captionSans.copyWith(color: colors.textSecondary),
                  ),
                ),
              )
            else
              ...recentTasks.map(
                (task) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: UnifiedTaskCard(
                    key: ValueKey('hub-${task.id}'),
                    task: task,
                    isPersonal: task.isPersonal,
                    isPending: state.pendingStatusTaskIds.contains(task.id),
                    canManage: canManage,
                    onTap: canManage
                        ? () => _showEditTaskBottomSheet(
                              context,
                              task,
                              state.projects,
                              state.assignees,
                            )
                        : null,
                    onStatusChanged: (isDone) {
                      if (state.pendingStatusTaskIds.contains(task.id)) return;
                      context.read<TasksBloc>().add(
                        UpdateTaskStatusRequested(
                          taskId: task.id,
                          status: isDone ? TaskStatus.done : TaskStatus.todo,
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskHubCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String badge,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
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
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.surfaceNested,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: textStyles.captionSans.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: textStyles.bodySans.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class TaskSectionScreen extends StatefulWidget {
  final TaskSection section;
  final bool initialOnlyOverdue;
  const TaskSectionScreen({
    super.key,
    required this.section,
    this.initialOnlyOverdue = false,
  });

  @override
  State<TaskSectionScreen> createState() => _TaskSectionScreenState();
}

class _TaskSectionScreenState extends State<TaskSectionScreen>
    with _TasksViewMixin {
  @override
  void initState() {
    super.initState();
    _onlyOverdue = widget.initialOnlyOverdue;
    if (widget.section == TaskSection.analytics) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<TasksBloc>().add(const LoadTaskAnalytics());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final canManage = _canManageTasks(context);

    return BlocBuilder<TasksBloc, TasksState>(
      builder: (context, state) {
        if (state is! TasksLoaded) {
          return Scaffold(
            backgroundColor: colors.background,
            appBar: AppBar(
              backgroundColor: colors.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: const BackButton(),
              title: Text(
                _taskSectionTitle(language, widget.section),
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
            body: const TasksOverviewShimmer(),
          );
        }

        final filteredTasks = _getFilteredTasks(state.tasks);
        final workloadTasks = _getWorkloadTasks(state);

        Widget? fab;
        if (widget.section == TaskSection.myTasks) {
          fab = FloatingActionButton.extended(
            heroTag: 'task_my_fab',
            onPressed: () => _showPersonalTaskSheet(context),
            backgroundColor: colors.brand,
            foregroundColor: colors.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            icon: const Icon(TablerIcons.plus),
            label: Text(
              language.translate('tasks_fab_personal'),
              style: textStyles.bodySans.copyWith(
                color: colors.surface,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        } else if (widget.section == TaskSection.allTasks && canManage) {
          fab = FloatingActionButton.extended(
            heroTag: 'task_team_fab',
            onPressed: () => _showAddTaskBottomSheet(
              context,
              state.projects,
              state.assignees,
            ),
            backgroundColor: colors.brand,
            foregroundColor: colors.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            icon: const Icon(TablerIcons.plus),
            label: Text(
              language.translate('tasks_fab_team'),
              style: textStyles.bodySans.copyWith(
                color: colors.surface,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            backgroundColor: colors.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: const BackButton(),
            title: Text(
              _taskSectionTitle(language, widget.section),
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
          floatingActionButton: fab,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.section == TaskSection.myTasks ||
                  widget.section == TaskSection.allTasks)
                _TasksSearchFilterBar(
                  searchQuery: _searchQuery,
                  onSearchChanged: (value) {
                    if (!mounted || _searchQuery == value) return;
                    setState(() => _searchQuery = value);
                  },
                  onlyOverdue: _onlyOverdue,
                  onOverdueChanged: (value) {
                    if (!mounted || _onlyOverdue == value) return;
                    setState(() => _onlyOverdue = value);
                  },
                ),
              if (widget.section == TaskSection.allTasks &&
                  state.projects.isNotEmpty)
                _buildProjectFilterBar(context, state.projects),
              Expanded(
                child: switch (widget.section) {
                  TaskSection.myTasks => _buildMyTasksTab(context, state),
                  TaskSection.allTasks => _buildAllTasksTab(
                      context,
                      filteredTasks,
                      state.projects,
                      state.assignees,
                      state.pendingStatusTaskIds,
                    ),
                  TaskSection.calendar => _buildCalendarTab(
                      context,
                      workloadTasks,
                      state.projects,
                      state.assignees,
                    ),
                  TaskSection.analytics => _buildAnalysisTab(
                      context,
                      state.overloaded,
                      state.criticalPath,
                      isLoading: state.isAnalyticsLoading,
                      isLoaded: state.analyticsLoaded,
                      error: state.analyticsError,
                    ),
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TasksSearchFilterBar extends StatefulWidget {
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final bool onlyOverdue;
  final ValueChanged<bool> onOverdueChanged;

  const _TasksSearchFilterBar({
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onlyOverdue,
    required this.onOverdueChanged,
  });

  @override
  State<_TasksSearchFilterBar> createState() => _TasksSearchFilterBarState();
}

class _TasksSearchFilterBarState extends State<_TasksSearchFilterBar> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _TasksSearchFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != _controller.text && !_focusNode.hasFocus) {
      _controller.text = widget.searchQuery;
    }
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      if (!_isExpanded) setState(() => _isExpanded = true);
    } else {
      if (_isExpanded) setState(() => _isExpanded = false);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _submitSearch(String val) {
    widget.onSearchChanged(val.trim());
    _focusNode.unfocus();
  }

  void _clear() {
    _controller.clear();
    widget.onSearchChanged('');
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final hasQuery = widget.searchQuery.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: AnimatedCrossFade(
              duration: const Duration(milliseconds: 260),
              firstCurve: Curves.easeOutCubic,
              secondCurve: Curves.easeOutCubic,
              sizeCurve: Curves.easeOutCubic,
              crossFadeState: _isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              // Свернутое состояние (компактный размер)
              firstChild: GestureDetector(
                onTap: () {
                  setState(() => _isExpanded = true);
                  _focusNode.requestFocus();
                },
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: hasQuery
                        ? colors.brand.withValues(alpha: 0.08)
                        : colors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasQuery ? colors.brand : colors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        TablerIcons.search,
                        size: 18,
                        color: hasQuery ? colors.brand : colors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          hasQuery
                              ? widget.searchQuery
                              : language.translate('tasks_search_hint'),
                          style: textStyles.captionSans.copyWith(
                            color: hasQuery
                                ? colors.brand
                                : colors.textSecondary,
                            fontWeight: hasQuery
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasQuery)
                        GestureDetector(
                          onTap: _clear,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              TablerIcons.x,
                              size: 16,
                              color: colors.brand,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Развернутое состояние при поиске
              secondChild: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.brand, width: 1.5),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 10),
                    Icon(TablerIcons.search, size: 18, color: colors.brand),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        style: textStyles.bodySans,
                        textInputAction: TextInputAction.search,
                        onSubmitted: _submitSearch,
                        decoration: InputDecoration(
                          hintText: language.translate('tasks_search_hint'),
                          hintStyle: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {});
                        },
                      ),
                    ),
                    if (_controller.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _controller.clear();
                          setState(() {});
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            TablerIcons.x,
                            size: 16,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    GestureDetector(
                      onTap: () => _submitSearch(_controller.text),
                      child: Container(
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: colors.brand,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          TablerIcons.arrow_right,
                          size: 16,
                          color: colors.surface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Кнопка «Просрочено» — никогда не деформируется и не меняет габариты
          GestureDetector(
            onTap: () => widget.onOverdueChanged(!widget.onlyOverdue),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: widget.onlyOverdue
                    ? colors.accentRed.withValues(alpha: 0.08)
                    : colors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.onlyOverdue ? colors.accentRed : colors.border,
                ),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    TablerIcons.alert_triangle,
                    size: 16,
                    color: widget.onlyOverdue
                        ? colors.accentRed
                        : colors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    language.translate('tasks_overdue'),
                    style: textStyles.captionSans.copyWith(
                      color: widget.onlyOverdue
                          ? colors.accentRed
                          : colors.textPrimary,
                      fontWeight: widget.onlyOverdue
                          ? FontWeight.w500
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
