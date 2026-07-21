import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';
import '../../core/localization/language_cubit.dart';
import '../../core/theme/theme_extensions.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/bloc/auth_state.dart';
import '../../features/auth/domain/app_access.dart';
import '../../features/tasks/bloc/tasks_bloc.dart';
import '../../features/tasks/bloc/tasks_event.dart';
import '../../features/tasks/bloc/tasks_state.dart';
import '../../features/tasks/domain/tasks_repository.dart';
import '../../features/tasks/domain/task_model.dart';
import '../widgets/ledger_card.dart';
import '../widgets/ledger_pill.dart';
import '../widgets/expansible_widget.dart';
import '../widgets/ledger_bottom_sheet.dart';
import '../widgets/ledger_collapsing_header.dart';

/// Входная точка планировщика задач с внедрением TasksBloc.
class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TasksBloc>(
      create: (context) =>
          TasksBloc(context.read<TasksRepository>())..add(LoadTasks()),
      child: const TasksView(),
    );
  }
}

class TasksView extends StatefulWidget {
  const TasksView({super.key});

  @override
  State<TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends State<TasksView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeTabIndex = 0;

  // Filters state
  String _searchQuery = '';
  Timer? _searchDebounce;
  String? _selectedProjectId;
  bool _onlyOverdue = false;

  // Calendar state
  DateTime _calendarMonth = DateTime.now();
  DateTime? _selectedCalendarDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    final nextIndex = _tabController.index;
    if (nextIndex == _activeTabIndex || !mounted) return;
    setState(() => _activeTabIndex = nextIndex);
    if (nextIndex == 6) {
      context.read<TasksBloc>().add(const LoadTaskAnalytics());
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshTasks(BuildContext context) {
    final completion = Completer<void>();
    if (_activeTabIndex == 6) {
      context.read<TasksBloc>().add(
        LoadTaskAnalytics(forceRefresh: true, completion: completion),
      );
    } else {
      context.read<TasksBloc>().add(
        LoadTasks(forceRefresh: true, completion: completion),
      );
    }
    return completion.future;
  }

  bool _canManageTasks(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated &&
        authState.role.canManage(AppCapability.tasks);
  }

  List<Task> _getFilteredTasks(List<Task> tasks) {
    return tasks.where((task) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesTitle = task.title.toLowerCase().contains(query);
        final matchesDesc = task.description.toLowerCase().contains(query);
        if (!matchesTitle && !matchesDesc) return false;
      }
      if (_selectedProjectId != null && _selectedProjectId!.isNotEmpty) {
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
      height: 48,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: projects.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? colors.brand : colors.surface,
                borderRadius: BorderRadius.circular(999),
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
                  color: isSelected ? colors.surface : colors.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    return Scaffold(
      backgroundColor: colors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            LedgerCollapsingHeader(
              title: language.translate('tasks_title'),
              pinned: true,
              floating: true,
              snap: true,
              actions: [
                if (_canManageTasks(context))
                  BlocBuilder<TasksBloc, TasksState>(
                    buildWhen: (previous, current) {
                      if (previous is TasksLoaded && current is TasksLoaded) {
                        return !identical(previous.projects, current.projects) ||
                            !identical(previous.assignees, current.assignees);
                      }
                      return previous.runtimeType != current.runtimeType;
                    },
                    builder: (context, state) {
                      final projects = state is TasksLoaded
                          ? state.projects
                          : const <TaskProject>[];
                      final assignees = state is TasksLoaded
                          ? state.assignees
                          : const <TaskAssignee>[];
                      return IconButton(
                        icon: const Icon(TablerIcons.plus),
                        tooltip: language.translate('tasks_add_title'),
                        color: colors.brand,
                        onPressed: () =>
                            _showAddTaskBottomSheet(context, projects, assignees),
                      );
                    },
                  ),
              ],
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: colors.brand,
                unselectedLabelColor: colors.textSecondary,
                indicatorColor: colors.brand,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: colors.border,
                labelStyle: textStyles.captionSans.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                unselectedLabelStyle: textStyles.captionSans.copyWith(
                  fontWeight: FontWeight.w400,
                ),
                tabs: [
                  Tab(text: language.translate('tasks_tab_new')),
                  Tab(text: language.translate('tasks_tab_in_progress')),
                  Tab(text: language.translate('tasks_tab_review')),
                  Tab(text: language.translate('tasks_tab_done')),
                  Tab(text: language.translate('tasks_tab_calendar')),
                  Tab(text: language.translate('tasks_tab_gantt')),
                  Tab(text: language.translate('tasks_tab_analytics')),
                ],
              ),
            ),
          ];
        },
        body: BlocBuilder<TasksBloc, TasksState>(
          buildWhen: (previous, current) {
            if (previous is TasksLoaded && current is TasksLoaded) {
              return !identical(previous.tasks, current.tasks) ||
                  !identical(previous.projects, current.projects) ||
                  !identical(previous.assignees, current.assignees) ||
                  !identical(previous.overloaded, current.overloaded) ||
                  !identical(previous.criticalPath, current.criticalPath) ||
                  previous.isAnalyticsLoading != current.isAnalyticsLoading ||
                  previous.analyticsLoaded != current.analyticsLoaded ||
                  previous.analyticsError != current.analyticsError ||
                  previous.pendingStatusTaskIds != current.pendingStatusTaskIds;
            }
            return previous.runtimeType != current.runtimeType;
          },
          builder: (context, state) {
            if (state is TasksLoading) {
              return const Center(child: CircularProgressIndicator());
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
              final filteredTasks = _getFilteredTasks(state.tasks);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            style: textStyles.bodySans,
                            decoration: InputDecoration(
                              hintText: language.translate('tasks_search_hint'),
                              prefixIcon: Icon(
                                TablerIcons.search,
                                size: 18,
                                color: colors.textSecondary,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            onChanged: (value) {
                              _searchDebounce?.cancel();
                              _searchDebounce = Timer(
                                const Duration(milliseconds: 300),
                                () {
                                  if (!mounted || _searchQuery == value) return;
                                  setState(() => _searchQuery = value);
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _onlyOverdue = !_onlyOverdue;
                            });
                          },
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: _onlyOverdue
                                  ? colors.accentRed.withValues(alpha: 0.08)
                                  : colors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _onlyOverdue
                                    ? colors.accentRed
                                    : colors.border,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              children: [
                                Icon(
                                  TablerIcons.alert_triangle,
                                  size: 16,
                                  color: _onlyOverdue
                                      ? colors.accentRed
                                      : colors.textSecondary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  language.translate('tasks_overdue'),
                                  style: textStyles.captionSans.copyWith(
                                    color: _onlyOverdue
                                        ? colors.accentRed
                                        : colors.textPrimary,
                                    fontWeight: _onlyOverdue
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (state.projects.isNotEmpty)
                    _buildProjectFilterBar(context, state.projects),

                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _LazyTaskTab(
                          isActive: _activeTabIndex == 0,
                          builder: (context) => _buildTaskList(
                            context,
                            filteredTasks,
                            TaskStatus.todo,
                            state.projects,
                            state.assignees,
                            state.pendingStatusTaskIds,
                          ),
                        ),
                        _LazyTaskTab(
                          isActive: _activeTabIndex == 1,
                          builder: (context) => _buildTaskList(
                            context,
                            filteredTasks,
                            TaskStatus.inProgress,
                            state.projects,
                            state.assignees,
                            state.pendingStatusTaskIds,
                          ),
                        ),
                        _LazyTaskTab(
                          isActive: _activeTabIndex == 2,
                          builder: (context) => _buildTaskList(
                            context,
                            filteredTasks,
                            TaskStatus.review,
                            state.projects,
                            state.assignees,
                            state.pendingStatusTaskIds,
                          ),
                        ),
                        _LazyTaskTab(
                          isActive: _activeTabIndex == 3,
                          builder: (context) => _buildTaskList(
                            context,
                            filteredTasks,
                            TaskStatus.done,
                            state.projects,
                            state.assignees,
                            state.pendingStatusTaskIds,
                          ),
                        ),
                        _LazyTaskTab(
                          isActive: _activeTabIndex == 4,
                          builder: (context) => _buildCalendarTab(
                            context,
                            filteredTasks,
                            state.projects,
                            state.assignees,
                          ),
                        ),
                        _LazyTaskTab(
                          isActive: _activeTabIndex == 5,
                          builder: (context) => _GanttTaskTab(
                            tasks: filteredTasks,
                            onRefresh: () => _refreshTasks(context),
                          ),
                        ),
                        _LazyTaskTab(
                          isActive: _activeTabIndex == 6,
                          builder: (context) => _buildAnalysisTab(
                            context,
                            state.overloaded,
                            state.criticalPath,
                            isLoading: state.isAnalyticsLoading,
                            isLoaded: state.analyticsLoaded,
                            error: state.analyticsError,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildCheckbox(
    BuildContext context,
    Task task,
    bool isDone,
    bool isPending,
  ) {
    return AnimatedCheckbox(
      value: isDone,
      isPending: isPending,
      isEnabled: _canManageTasks(context),
      semanticLabel: task.title,
      pendingSemanticLabel: context.translate('common_loading'),
      onChanged: (newValue) {
        if (isPending) return;
        final nextStatus = newValue ? TaskStatus.done : TaskStatus.todo;
        context.read<TasksBloc>().add(
          UpdateTaskStatusRequested(taskId: task.id, status: nextStatus),
        );
      },
    );
  }

  Widget _buildTaskListHeader(
    BuildContext context,
    List<Task> tasks,
    TaskStatus status,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final count = tasks.length;
    final urgentCount = tasks
        .where((t) => t.priority == TaskPriority.urgent)
        .length;
    final highCount = tasks
        .where((t) => t.priority == TaskPriority.high)
        .length;

    String titleText = '';

    switch (status) {
      case TaskStatus.todo:
        titleText = language.translate('tasks_list_header_new');
        break;
      case TaskStatus.inProgress:
        titleText = language.translate('tasks_list_header_in_progress');
        break;
      case TaskStatus.review:
        titleText = language.translate('tasks_list_header_review');
        break;
      case TaskStatus.done:
        titleText = language.translate('tasks_list_header_done');
        break;
    }

    final List<String> priorityList = [];
    if (urgentCount > 0) {
      priorityList.add(
        language.translatePlural('tasks_priority_urgent_count', urgentCount),
      );
    }
    if (highCount > 0) {
      priorityList.add(
        language.translate(
          'tasks_priority_high_count',
          params: {'count': highCount},
        ),
      );
    }
    final priorityText = priorityList.join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: colors.brand.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.brand.withValues(alpha: 0.05)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                titleText,
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.brand.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _taskCountLabel(language, count),
                  style: textStyles.captionSans.copyWith(
                    color: colors.brand,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (priorityText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              priorityText,
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskList(
    BuildContext context,
    List<Task> allTasks,
    TaskStatus status,
    List<TaskProject> projects,
    List<TaskAssignee> assignees,
    Set<String> pendingTaskIds,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    final tasks = allTasks.where((t) => t.status == status).toList();

    return RefreshIndicator(
      onRefresh: () => _refreshTasks(context),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: tasks.length + 1,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildTaskListHeader(context, tasks, status);
          }

          final task = tasks[index - 1];
          final isDone = status == TaskStatus.done;

          Color pColor = colors.surfaceNested;
          Color pTextColor = colors.textSecondary;
          if (task.priority == TaskPriority.urgent) {
            pColor = colors.accentRed.withValues(alpha: 0.1);
            pTextColor = colors.accentRed;
          } else if (task.priority == TaskPriority.high) {
            pColor = colors.accentAmber.withValues(alpha: 0.1);
            pTextColor = colors.accentAmber;
          } else if (task.priority == TaskPriority.medium) {
            pColor = colors.brand.withValues(alpha: 0.1);
            pTextColor = colors.brand;
          } else if (task.priority == TaskPriority.low) {
            pColor = colors.accentGreen.withValues(alpha: 0.1);
            pTextColor = colors.accentGreen;
          }

          return GestureDetector(
            onTap: _canManageTasks(context)
                ? () => _showEditTaskBottomSheet(
                    context,
                    task,
                    projects,
                    assignees,
                  )
                : null,
            child: Container(
              key: ValueKey(task.id),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.bold,
                            decoration: isDone
                                ? TextDecoration.lineThrough
                                : null,
                            color: isDone
                                ? colors.textTooltip
                                : colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (task.projectName != null) ...[
                              Flexible(
                                child: Text(
                                  task.projectName!,
                                  style: textStyles.captionSans.copyWith(
                                    color: colors.brand,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: colors.textSecondary.withValues(
                                    alpha: 0.4,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Icon(
                              TablerIcons.calendar,
                              size: 12,
                              color: colors.textTooltip,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatLocalizedCompactDate(
                                language,
                                task.dueDate,
                              ),
                              style: textStyles.captionSans.copyWith(
                                color:
                                    task.dueDate.isBefore(DateTime.now()) &&
                                        !isDone
                                    ? colors.accentRed
                                    : colors.textTooltip,
                              ),
                            ),
                            if (task.assigneeName != null &&
                                task.assigneeName!.trim().isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: colors.textSecondary.withValues(
                                    alpha: 0.4,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                TablerIcons.user,
                                size: 12,
                                color: colors.textTooltip,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  language.translateMessage(task.assigneeName!),
                                  style: textStyles.captionSans.copyWith(
                                    color: colors.textTooltip,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  LedgerPill(
                    text: language.translate(task.priority.localizationKey),
                    backgroundColor: pColor,
                    textColor: pTextColor,
                    fontSize: 13,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildCheckbox(
                    context,
                    task,
                    isDone,
                    pendingTaskIds.contains(task.id),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Compact priority chips in a single row (no orphan wrap on the second line).
  Widget _buildPriorityChips(
    BuildContext context, {
    required TaskPriority selectedPriority,
    required ValueChanged<TaskPriority> onSelected,
  }) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: TaskPriority.values.map((priority) {
        final isSelected = selectedPriority == priority;

        final selectedTextColor = switch (priority) {
          TaskPriority.urgent => colors.accentRed,
          TaskPriority.high => colors.accentAmber,
          TaskPriority.low => colors.accentGreen,
          TaskPriority.medium => colors.brand,
        };

        final selectedBgColor = selectedTextColor.withValues(alpha: 0.15);
        final selectedBorderColor = selectedTextColor;

        return Semantics(
          button: true,
          selected: isSelected,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onSelected(priority),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? selectedBgColor : colors.surface,
                  border: Border.all(
                    color: isSelected ? selectedBorderColor : colors.border,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Text(
                  language.translate(priority.localizationKey),
                  style: textStyles.captionSans.copyWith(
                    color: isSelected ? selectedTextColor : colors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _showAddTaskBottomSheet(
    BuildContext context,
    List<TaskProject> projects,
    List<TaskAssignee> assignees,
  ) async {
    final tasksBloc = context.read<TasksBloc>();
    final colors = context.colors;
    final textStyles = context.textStyles;

    final titleController = TextEditingController();
    final descController = TextEditingController();

    TaskPriority selectedPriority = TaskPriority.medium;
    TaskProject? selectedProject;
    TaskAssignee? selectedAssignee;
    DateTime? selectedStartDate;
    DateTime selectedDueDate = DateTime.now().add(const Duration(days: 3));

    bool isDirty() {
      return titleController.text.trim().isNotEmpty ||
          descController.text.trim().isNotEmpty ||
          selectedProject != null ||
          selectedAssignee != null ||
          selectedStartDate != null ||
          selectedPriority != TaskPriority.medium;
    }

    try {
      await LedgerBottomSheet.show(
        context: context,
        title: context.read<LanguageCubit>().translate('tasks_add_title'),
        builder: (context, setSheetState) {
          final language = context.watch<LanguageCubit>();

          return _TaskFormPopScope(
            isDirty: isDirty,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: titleController,
                  style: textStyles.bodySans,
                  decoration: InputDecoration(
                    labelText: language.translate('tasks_field_title'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  style: textStyles.bodySans,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: language.translate('tasks_field_description'),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  language.translate('tasks_field_project'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                ExpansibleWidget<TaskProject?>.selection(
                  cardPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  title: Text(
                    selectedProject?.name ??
                        language.translate('tasks_select_project_optional'),
                    style: textStyles.bodySans.copyWith(
                      color: selectedProject == null
                          ? colors.textTooltip
                          : colors.textPrimary,
                    ),
                  ),
                  items: [null, ...projects],
                  selectedValue: selectedProject,
                  itemLabelBuilder: (p) =>
                      p?.name ?? language.translate('tasks_no_project'),
                  onSelected: (p) {
                    setSheetState(() {
                      selectedProject = p;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  language.translate('tasks_field_priority'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                _buildPriorityChips(
                  context,
                  selectedPriority: selectedPriority,
                  onSelected: (p) {
                    setSheetState(() {
                      selectedPriority = p;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  language.translate('tasks_field_assignee'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                ExpansibleWidget<TaskAssignee?>.selection(
                  cardPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  title: Text(
                    language.translateMessage(
                      selectedAssignee?.fullName ??
                          language.translate('tasks_no_assignee'),
                    ),
                    style: textStyles.bodySans.copyWith(
                      color: selectedAssignee == null
                          ? colors.textTooltip
                          : colors.textPrimary,
                    ),
                  ),
                  items: [null, ...assignees],
                  selectedValue: selectedAssignee,
                  itemLabelBuilder: (a) => language.translateMessage(
                    a?.fullName ?? language.translate('tasks_no_assignee'),
                  ),
                  onSelected: (a) {
                    setSheetState(() {
                      selectedAssignee = a;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  language.translate('tasks_field_start_date'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedStartDate ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setSheetState(() {
                        selectedStartDate = picked;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.border),
                      borderRadius: BorderRadius.circular(8),
                      color: colors.surface,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          selectedStartDate != null
                              ? DateFormat(
                                  'dd.MM.yyyy',
                                ).format(selectedStartDate!)
                              : language.translate('tasks_not_set'),
                          style: textStyles.captionSans,
                        ),
                        Icon(
                          TablerIcons.calendar,
                          size: 16,
                          color: colors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  language.translate('tasks_field_due_date'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDueDate,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setSheetState(() {
                        selectedDueDate = picked;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.border),
                      borderRadius: BorderRadius.circular(8),
                      color: colors.surface,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('dd.MM.yyyy').format(selectedDueDate),
                          style: textStyles.captionSans,
                        ),
                        Icon(
                          TablerIcons.calendar,
                          size: 16,
                          color: colors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        footerBuilder: (context, setSheetState) {
          final language = context.watch<LanguageCubit>();

          return ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                final newTask = Task(
                  id: '',
                  title: titleController.text.trim(),
                  description: descController.text.trim(),
                  status: TaskStatus.todo,
                  dueDate: selectedDueDate,
                  priority: selectedPriority,
                  projectId: selectedProject?.id,
                  projectName: selectedProject?.name,
                  assigneeId: selectedAssignee?.id,
                  assigneeName: selectedAssignee?.fullName,
                  startDate: selectedStartDate,
                );
                tasksBloc.add(CreateTaskRequested(newTask));
                Navigator.pop(context);
              }
            },
            child: Text(language.translate('tasks_create')),
          );
        },
      );
    } finally {
      titleController.dispose();
      descController.dispose();
    }
  }

  Future<void> _showEditTaskBottomSheet(
    BuildContext context,
    Task task,
    List<TaskProject> projects,
    List<TaskAssignee> assignees,
  ) async {
    final tasksBloc = context.read<TasksBloc>();
    final colors = context.colors;
    final textStyles = context.textStyles;

    final titleController = TextEditingController(text: task.title);
    final descController = TextEditingController(text: task.description);

    TaskStatus selectedStatus = task.status;
    TaskPriority selectedPriority = task.priority;
    TaskProject? selectedProject;
    if (task.projectId != null) {
      try {
        selectedProject = projects.firstWhere((p) => p.id == task.projectId);
      } catch (_) {}
    }
    TaskAssignee? selectedAssignee;
    if (task.assigneeId != null) {
      try {
        selectedAssignee = assignees.firstWhere((a) => a.id == task.assigneeId);
      } catch (_) {
        if (task.assigneeName != null && task.assigneeName!.trim().isNotEmpty) {
          selectedAssignee = TaskAssignee(
            id: task.assigneeId!,
            fullName: task.assigneeName!,
          );
        }
      }
    }
    DateTime? selectedStartDate = task.startDate;
    DateTime selectedDueDate = task.dueDate;

    bool isDateChanged(DateTime? a, DateTime? b) {
      if (a == null && b == null) return false;
      if (a == null || b == null) return true;
      return a.year != b.year || a.month != b.month || a.day != b.day;
    }

    bool isDirty() {
      final currentTitle = titleController.text.trim();
      final currentDesc = descController.text.trim();
      final origProjectId = task.projectId;
      final currentProjectId = selectedProject?.id;

      return currentTitle != task.title ||
          currentDesc != task.description ||
          selectedStatus != task.status ||
          currentProjectId != origProjectId ||
          selectedAssignee?.id != task.assigneeId ||
          selectedPriority != task.priority ||
          isDateChanged(selectedStartDate, task.startDate) ||
          isDateChanged(selectedDueDate, task.dueDate);
    }

    try {
      await LedgerBottomSheet.show(
        context: context,
        title: context.read<LanguageCubit>().translate('tasks_edit_title'),
        builder: (context, setSheetState) {
          final language = context.watch<LanguageCubit>();

          return _TaskFormPopScope(
            isDirty: isDirty,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: titleController,
                  style: textStyles.bodySans,
                  decoration: InputDecoration(
                    labelText: language.translate('tasks_field_title'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  style: textStyles.bodySans,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: language.translate('tasks_field_description'),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  language.translate('tasks_field_stage_status'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                ExpansibleWidget<TaskStatus>.selection(
                  cardPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  title: Text(
                    language.translate(selectedStatus.localizationKey),
                    style: textStyles.bodySans,
                  ),
                  items: TaskStatus.values,
                  selectedValue: selectedStatus,
                  itemLabelBuilder: (s) =>
                      language.translate(s.localizationKey),
                  onSelected: (s) {
                    setSheetState(() {
                      selectedStatus = s;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  language.translate('tasks_field_project'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                ExpansibleWidget<TaskProject?>.selection(
                  cardPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  title: Text(
                    selectedProject?.name ??
                        language.translate('tasks_select_project_optional'),
                    style: textStyles.bodySans.copyWith(
                      color: selectedProject == null
                          ? colors.textTooltip
                          : colors.textPrimary,
                    ),
                  ),
                  items: [null, ...projects],
                  selectedValue: selectedProject,
                  itemLabelBuilder: (p) =>
                      p?.name ?? language.translate('tasks_no_project'),
                  onSelected: (p) {
                    setSheetState(() {
                      selectedProject = p;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  language.translate('tasks_field_priority'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                _buildPriorityChips(
                  context,
                  selectedPriority: selectedPriority,
                  onSelected: (p) {
                    setSheetState(() {
                      selectedPriority = p;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  language.translate('tasks_field_assignee'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                ExpansibleWidget<TaskAssignee?>.selection(
                  cardPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  title: Text(
                    language.translateMessage(
                      selectedAssignee?.fullName ??
                          language.translate('tasks_no_assignee'),
                    ),
                    style: textStyles.bodySans.copyWith(
                      color: selectedAssignee == null
                          ? colors.textTooltip
                          : colors.textPrimary,
                    ),
                  ),
                  items: [null, ...assignees],
                  selectedValue: selectedAssignee,
                  itemLabelBuilder: (a) => language.translateMessage(
                    a?.fullName ?? language.translate('tasks_no_assignee'),
                  ),
                  onSelected: (a) {
                    setSheetState(() {
                      selectedAssignee = a;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  language.translate('tasks_field_start_date'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedStartDate ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setSheetState(() {
                        selectedStartDate = picked;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.border),
                      borderRadius: BorderRadius.circular(8),
                      color: colors.surface,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          selectedStartDate != null
                              ? DateFormat(
                                  'dd.MM.yyyy',
                                ).format(selectedStartDate!)
                              : language.translate('tasks_not_set'),
                          style: textStyles.captionSans,
                        ),
                        Icon(
                          TablerIcons.calendar,
                          size: 16,
                          color: colors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  language.translate('tasks_field_due_date'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDueDate,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setSheetState(() {
                        selectedDueDate = picked;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.border),
                      borderRadius: BorderRadius.circular(8),
                      color: colors.surface,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('dd.MM.yyyy').format(selectedDueDate),
                          style: textStyles.captionSans,
                        ),
                        Icon(
                          TablerIcons.calendar,
                          size: 16,
                          color: colors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        footerBuilder: (context, setSheetState) {
          final language = context.watch<LanguageCubit>();

          return ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                // Explicit Task so clearing project/assignee can set nulls (copyWith can't).
                final updatedTask = Task(
                  id: task.id,
                  title: titleController.text.trim(),
                  description: descController.text.trim(),
                  status: selectedStatus,
                  dueDate: selectedDueDate,
                  priority: selectedPriority,
                  projectId: selectedProject?.id,
                  projectName: selectedProject?.name,
                  assigneeId: selectedAssignee?.id,
                  assigneeName: selectedAssignee?.fullName,
                  startDate: selectedStartDate,
                  dependsOnId: task.dependsOnId,
                  position: task.position,
                );
                tasksBloc.add(UpdateTaskRequested(updatedTask));
                Navigator.pop(context);
              }
            },
            child: Text(language.translate('tasks_save_changes')),
          );
        },
      );
    } finally {
      titleController.dispose();
      descController.dispose();
    }
  }

  Widget _buildCalendarTab(
    BuildContext context,
    List<Task> tasks,
    List<TaskProject> projects,
    List<TaskAssignee> assignees,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    final year = _calendarMonth.year;
    final month = _calendarMonth.month;

    final firstDay = DateTime(year, month, 1);
    final weekdayOffset = (firstDay.weekday - 1) % 7;
    final startGridDate = firstDay.subtract(Duration(days: weekdayOffset));

    final gridDates = List<DateTime>.generate(
      42,
      (index) => startGridDate.add(Duration(days: index)),
    );

    final tasksByDay = <DateTime, List<Task>>{};
    for (final task in tasks) {
      final day = DateUtils.dateOnly(task.dueDate);
      (tasksByDay[day] ??= <Task>[]).add(task);
    }
    final monthNames = [
      language.translate('tasks_month_january'),
      language.translate('tasks_month_february'),
      language.translate('tasks_month_march'),
      language.translate('tasks_month_april'),
      language.translate('tasks_month_may'),
      language.translate('tasks_month_june'),
      language.translate('tasks_month_july'),
      language.translate('tasks_month_august'),
      language.translate('tasks_month_september'),
      language.translate('tasks_month_october'),
      language.translate('tasks_month_november'),
      language.translate('tasks_month_december'),
    ];
    final weekdayLabels = List.generate(
      7,
      (index) => language.translate(_weekdayLocalizationKey(index + 1)),
    );

    return RefreshIndicator(
      onRefresh: () => _refreshTasks(context),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                language.translate(
                  'tasks_calendar_month_year',
                  params: {'month': monthNames[month - 1], 'year': year},
                ),
                style: textStyles.h2Sans,
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(TablerIcons.chevron_left),
                    tooltip: language.translate('common_previous'),
                    onPressed: () {
                      setState(() {
                        _calendarMonth = DateTime(year, month - 1, 1);
                        _selectedCalendarDay = null;
                      });
                    },
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _calendarMonth = DateTime.now();
                        _selectedCalendarDay = DateTime.now();
                      });
                    },
                    child: Text(
                      language.translate('tasks_calendar_today'),
                      style: textStyles.captionSans.copyWith(
                        color: colors.brand,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(TablerIcons.chevron_right),
                    tooltip: language.translate('common_next'),
                    onPressed: () {
                      setState(() {
                        _calendarMonth = DateTime(year, month + 1, 1);
                        _selectedCalendarDay = null;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.5,
            ),
            itemCount: 7,
            itemBuilder: (context, index) {
              return Center(
                child: Text(
                  weekdayLabels[index],
                  style: textStyles.smallSans.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 2),
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.1,
            ),
            itemCount: 42,
            itemBuilder: (context, index) {
              final day = gridDates[index];
              final isCurrentMonth = day.month == month;
              final isToday = DateUtils.isSameDay(day, DateTime.now());
              final isSelected =
                  _selectedCalendarDay != null &&
                  DateUtils.isSameDay(day, _selectedCalendarDay!);
              final dayTasks =
                  tasksByDay[DateUtils.dateOnly(day)] ?? const <Task>[];

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCalendarDay = day;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.brand.withValues(alpha: 0.15)
                        : isCurrentMonth
                        ? colors.surface
                        : colors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? colors.brand
                          : isToday
                          ? colors.brand.withValues(alpha: 0.5)
                          : colors.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${day.day}',
                        style: textStyles.smallMono.copyWith(
                          fontWeight: isToday || isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isCurrentMonth
                              ? (isToday ? colors.brand : colors.textPrimary)
                              : colors.textTooltip,
                        ),
                      ),
                      if (dayTasks.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: dayTasks.take(3).map((t) {
                            Color dotColor = colors.brand;
                            if (t.priority == TaskPriority.urgent) {
                              dotColor = colors.accentRed;
                            } else if (t.priority == TaskPriority.high) {
                              dotColor = colors.accentAmber;
                            } else if (t.priority == TaskPriority.low) {
                              dotColor = colors.accentGreen;
                            }
                            return Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: dotColor,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          if (_selectedCalendarDay != null) ...[
            Text(
              language.translate(
                'tasks_calendar_due_on',
                params: {
                  'date': _formatLocalizedLongDate(
                    language,
                    _selectedCalendarDay!,
                  ),
                },
              ),
              style: textStyles.bodySans.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildDayTasksList(
              context,
              tasksByDay[DateUtils.dateOnly(_selectedCalendarDay!)] ??
                  const <Task>[],
              projects,
              assignees,
            ),
          ] else ...[
            Center(
              child: Text(
                language.translate('tasks_calendar_select_day'),
                style: textStyles.captionSans.copyWith(
                  color: colors.textTooltip,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDayTasksList(
    BuildContext context,
    List<Task> dayTasks,
    List<TaskProject> projects,
    List<TaskAssignee> assignees,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    if (dayTasks.isEmpty) {
      return LedgerCard(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            language.translate('tasks_calendar_empty_day'),
            style: textStyles.captionSans.copyWith(color: colors.textTooltip),
          ),
        ),
      );
    }

    return Column(
      children: dayTasks.map((task) {
        return GestureDetector(
          onTap: _canManageTasks(context)
              ? () =>
                    _showEditTaskBottomSheet(context, task, projects, assignees)
              : null,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 32,
                  decoration: BoxDecoration(
                    color: task.priority == TaskPriority.urgent
                        ? colors.accentRed
                        : task.priority == TaskPriority.high
                        ? colors.accentAmber
                        : task.priority == TaskPriority.low
                        ? colors.accentGreen
                        : colors.brand,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: textStyles.bodySans.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (task.projectName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          language.translate(
                            'tasks_project_value',
                            params: {'project': task.projectName!},
                          ),
                          style: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                      if (task.assigneeName != null &&
                          task.assigneeName!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '👤 ${language.translateMessage(task.assigneeName!)}',
                          style: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                LedgerPill(
                  text: language.translate(task.status.localizationKey),
                  backgroundColor: colors.brand.withValues(alpha: 0.08),
                  textColor: colors.brand,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAnalysisTab(
    BuildContext context,
    List<TaskOverload> overloaded,
    List<TaskCriticalPath> critical, {
    required bool isLoading,
    required bool isLoaded,
    String? error,
  }) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    if (!isLoaded) {
      return RefreshIndicator(
        onRefresh: () => _refreshTasks(context),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 320,
              child: Center(
                child: isLoading || error == null
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            language.translateMessage(error),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
                              context.read<TasksBloc>().add(
                                const LoadTaskAnalytics(forceRefresh: true),
                              );
                            },
                            child: Text(language.translate('tasks_retry')),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refreshTasks(context),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Icon(
                TablerIcons.alert_triangle,
                color: colors.accentRed,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                language.translate('tasks_analysis_overload_title'),
                style: textStyles.captionSans.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (overloaded.isEmpty)
            LedgerCard(
              padding: const EdgeInsets.all(14),
              child: Center(
                child: Text(
                  language.translate('tasks_analysis_no_overload'),
                  style: textStyles.captionSans.copyWith(
                    color: colors.textTooltip,
                  ),
                ),
              ),
            )
          else
            ...overloaded.map((ov) {
              final initial = ov.assigneeName.isNotEmpty
                  ? ov.assigneeName.characters.first.toUpperCase()
                  : '?';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: LedgerCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: colors.brand.withValues(
                              alpha: 0.1,
                            ),
                            child: Text(
                              initial,
                              style: textStyles.captionSans.copyWith(
                                color: colors.brand,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            language.translateMessage(ov.assigneeName),
                            style: textStyles.bodySans.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          LedgerPill(
                            text: language.translate(
                              'tasks_analysis_active_count',
                              params: {'count': ov.activeCount},
                            ),
                            backgroundColor: colors.accentRed.withValues(
                              alpha: 0.08,
                            ),
                            textColor: colors.accentRed,
                          ),
                          if (ov.overdueCount > 0) ...[
                            const SizedBox(width: 8),
                            LedgerPill(
                              text: language.translate(
                                'tasks_analysis_overdue_count',
                                params: {'count': ov.overdueCount},
                              ),
                              backgroundColor: colors.accentAmber.withValues(
                                alpha: 0.1,
                              ),
                              textColor: colors.accentAmber,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),

          const SizedBox(height: 24),

          Row(
            children: [
              Icon(TablerIcons.git_branch, color: colors.brand, size: 18),
              const SizedBox(width: 8),
              Text(
                language.translate('tasks_analysis_critical_path_title'),
                style: textStyles.captionSans.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (critical.isEmpty)
            LedgerCard(
              padding: const EdgeInsets.all(14),
              child: Center(
                child: Text(
                  language.translate('tasks_analysis_no_critical_path'),
                  style: textStyles.captionSans.copyWith(
                    color: colors.textTooltip,
                  ),
                ),
              ),
            )
          else
            ...critical.map((cp) {
              String statusLabel = language.translate(
                TaskStatus.todo.localizationKey,
              );
              Color statusColor = colors.textSecondary;
              if (cp.status == 'in_progress') {
                statusLabel = language.translate(
                  TaskStatus.inProgress.localizationKey,
                );
                statusColor = colors.brand;
              } else if (cp.status == 'review') {
                statusLabel = language.translate('tasks_gantt_legend_review');
                statusColor = colors.accentAmber;
              } else if (cp.status == 'done') {
                statusLabel = language.translate(
                  TaskStatus.done.localizationKey,
                );
                statusColor = colors.accentGreen;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: LedgerCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cp.title,
                              style: textStyles.bodySans.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (cp.dueDate != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                language.translate(
                                  'tasks_due_value',
                                  params: {
                                    'date': _formatLocalizedCompactDateWithYear(
                                      language,
                                      cp.dueDate!,
                                    ),
                                  },
                                ),
                                style: textStyles.captionSans.copyWith(
                                  color: colors.textTooltip,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          LedgerPill(
                            text: statusLabel,
                            backgroundColor: statusColor.withValues(
                              alpha: 0.08,
                            ),
                            textColor: statusColor,
                          ),
                          if (cp.blocksCount > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              language.translate(
                                'tasks_analysis_blocks_count',
                                params: {'count': cp.blocksCount},
                              ),
                              style: textStyles.smallMono.copyWith(
                                color: colors.accentRed,
                              ),
                            ),
                          ],
                        ],
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
}

/// Меню смены статуса задачи.
///
/// Закрывает ExpansionTile **до** обновления списка, чтобы раскрытое меню
/// не «перепрыгивало» на соседнюю карточку при удалении задачи из вкладки.
class _TaskStatusMenu extends StatefulWidget {
  final Task task;

  const _TaskStatusMenu({required this.task});

  @override
  State<_TaskStatusMenu> createState() => _TaskStatusMenuState();
}

class _TaskStatusMenuState extends State<_TaskStatusMenu> {
  final ExpansibleController _controller = ExpansibleController();

  void _onStatusSelected(TaskStatus status) {
    // Сворачиваем меню до эмита в Bloc — карточка может сразу исчезнуть из списка.
    if (_controller.isExpanded) {
      _controller.collapse();
    }

    if (status == widget.task.status) return;

    context.read<TasksBloc>().add(
      UpdateTaskStatusRequested(taskId: widget.task.id, status: status),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final task = widget.task;

    return SizedBox(
      width: 140,
      child: ExpansibleWidget(
        // Ключ по ID задачи, а не по статусу — иначе все карточки вкладки
        // делят один и тот же ключ и Flutter путает их State.
        key: ValueKey('status-menu-${task.id}'),
        controller: _controller,
        cardPadding: EdgeInsets.zero,
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(TablerIcons.flag, size: 14, color: colors.brand),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                language.translate(task.status.localizationKey),
                style: textStyles.captionSans,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        children: TaskStatus.values.map((status) {
          final isCurrent = task.status == status;
          return ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            title: Text(
              language.translate(status.localizationKey),
              style: textStyles.captionSans.copyWith(
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: isCurrent ? colors.brand : colors.textPrimary,
              ),
            ),
            onTap: () => _onStatusSelected(status),
          );
        }).toList(),
      ),
    );
  }
}

class AnimatedCheckbox extends StatefulWidget {
  final bool value;
  final bool isPending;
  final bool isEnabled;
  final String semanticLabel;
  final String pendingSemanticLabel;
  final ValueChanged<bool> onChanged;

  const AnimatedCheckbox({
    super.key,
    required this.value,
    this.isPending = false,
    this.isEnabled = true,
    required this.semanticLabel,
    required this.pendingSemanticLabel,
    required this.onChanged,
  });

  @override
  State<AnimatedCheckbox> createState() => _AnimatedCheckboxState();
}

class _AnimatedCheckboxState extends State<AnimatedCheckbox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkScaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.8), weight: 30),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.8, end: 1.15),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.0),
        weight: 30,
      ),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _checkScaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0, curve: Curves.elasticOut),
    );

    if (widget.value) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      if (widget.value) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isInteractive = widget.isEnabled && !widget.isPending;
    void handleToggle() => widget.onChanged(!widget.value);

    return Semantics(
      container: true,
      label: widget.semanticLabel,
      value: widget.isPending ? widget.pendingSemanticLabel : null,
      checked: widget.value,
      enabled: isInteractive,
      liveRegion: widget.isPending,
      onTap: isInteractive ? handleToggle : null,
      child: SizedBox(
        width: 48,
        height: 48,
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: isInteractive ? handleToggle : null,
            child: Center(
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: !widget.isEnabled
                          ? colors.textSecondary.withValues(alpha: 0.2)
                          : widget.isPending
                          ? colors.accentGreen.withValues(alpha: 0.4)
                          : (widget.value
                                ? colors.accentGreen
                                : colors.textSecondary.withValues(alpha: 0.4)),
                      width: 1.5,
                    ),
                    color: widget.value
                        ? colors.accentGreen.withValues(alpha: 0.15)
                        : Colors.transparent,
                  ),
                  child: widget.isPending
                      ? Padding(
                          padding: const EdgeInsets.all(5.0),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colors.accentGreen,
                            ),
                          ),
                        )
                      : ScaleTransition(
                          scale: _checkScaleAnimation,
                          child: widget.value
                              ? Icon(
                                  TablerIcons.check,
                                  size: 18,
                                  color: colors.accentGreen,
                                )
                              : const SizedBox.shrink(),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatLocalizedCompactDate(LanguageCubit language, DateTime date) {
  const monthKeys = [
    'tasks_month_short_january',
    'tasks_month_short_february',
    'tasks_month_short_march',
    'tasks_month_short_april',
    'tasks_month_short_may',
    'tasks_month_short_june',
    'tasks_month_short_july',
    'tasks_month_short_august',
    'tasks_month_short_september',
    'tasks_month_short_october',
    'tasks_month_short_november',
    'tasks_month_short_december',
  ];
  return language.translate(
    'tasks_date_day_month',
    params: {
      'day': date.day,
      'month': language.translate(monthKeys[date.month - 1]),
    },
  );
}

String _formatLocalizedLongDate(LanguageCubit language, DateTime date) {
  const monthKeys = [
    'tasks_month_date_january',
    'tasks_month_date_february',
    'tasks_month_date_march',
    'tasks_month_date_april',
    'tasks_month_date_may',
    'tasks_month_date_june',
    'tasks_month_date_july',
    'tasks_month_date_august',
    'tasks_month_date_september',
    'tasks_month_date_october',
    'tasks_month_date_november',
    'tasks_month_date_december',
  ];

  return language.translate(
    'tasks_date_day_month_year',
    params: {
      'day': date.day,
      'month': language.translate(monthKeys[date.month - 1]),
      'year': date.year,
    },
  );
}

String _formatLocalizedCompactDateWithYear(
  LanguageCubit language,
  DateTime date,
) {
  const monthKeys = [
    'tasks_month_short_january',
    'tasks_month_short_february',
    'tasks_month_short_march',
    'tasks_month_short_april',
    'tasks_month_short_may',
    'tasks_month_short_june',
    'tasks_month_short_july',
    'tasks_month_short_august',
    'tasks_month_short_september',
    'tasks_month_short_october',
    'tasks_month_short_november',
    'tasks_month_short_december',
  ];

  return language.translate(
    'tasks_date_day_month_year',
    params: {
      'day': date.day,
      'month': language.translate(monthKeys[date.month - 1]),
      'year': date.year,
    },
  );
}

String _weekdayLocalizationKey(int weekday) {
  const keys = [
    'tasks_weekday_monday',
    'tasks_weekday_tuesday',
    'tasks_weekday_wednesday',
    'tasks_weekday_thursday',
    'tasks_weekday_friday',
    'tasks_weekday_saturday',
    'tasks_weekday_sunday',
  ];
  return keys[weekday - 1];
}

String _taskCountLabel(LanguageCubit language, int count) {
  return language.translatePlural('tasks_count', count);
}

class _LazyTaskTab extends StatelessWidget {
  final bool isActive;
  final WidgetBuilder builder;

  const _LazyTaskTab({required this.isActive, required this.builder});

  @override
  Widget build(BuildContext context) {
    if (!isActive) return const SizedBox.expand();
    return builder(context);
  }
}

class _GanttTaskTab extends StatelessWidget {
  static const int _maxTimelineColumns = 90;
  static const double _dayColumnWidth = 44;
  static const double _taskColumnWidth = 180;
  static const double _rowHeight = 48;

  final List<Task> tasks;
  final Future<void> Function() onRefresh;

  const _GanttTaskTab({required this.tasks, required this.onRefresh});

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    if (tasks.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              key: const PageStorageKey<String>('tasks-gantt-empty'),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: math.max(1, constraints.maxHeight - 1),
                  child: Center(
                    child: Text(
                      language.translate('tasks_gantt_empty'),
                      style: textStyles.captionSans.copyWith(
                        color: colors.textTooltip,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    var minDate = _dateOnly(tasks.first.startDate ?? tasks.first.dueDate);
    var maxDate = _dateOnly(tasks.first.dueDate);
    for (final task in tasks.skip(1)) {
      final start = _dateOnly(task.startDate ?? task.dueDate);
      final end = _dateOnly(task.dueDate);
      if (start.isBefore(minDate)) minDate = start;
      if (end.isBefore(minDate)) minDate = end;
      if (start.isAfter(maxDate)) maxDate = start;
      if (end.isAfter(maxDate)) maxDate = end;
    }

    final timelineStart = minDate.subtract(const Duration(days: 1));
    final timelineEnd = maxDate.add(const Duration(days: 2));
    final spanDays = timelineEnd.difference(timelineStart).inDays + 1;
    final bucketDays = math.max(1, (spanDays / _maxTimelineColumns).ceil());
    final columnCount = (spanDays / bucketDays).ceil();
    final timelineWidth = columnCount * _dayColumnWidth;
    final chartWidth = _taskColumnWidth + timelineWidth;
    final monthNames = _ganttMonthShortNames(language);
    final dueDateFormatter = DateFormat('dd.MM');

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final contentWidth = math.max(viewportWidth, chartWidth + 32);

        return SingleChildScrollView(
          key: const PageStorageKey<String>('tasks-gantt-horizontal'),
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: contentWidth,
            height: constraints.maxHeight,
            child: RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView.builder(
                key: const PageStorageKey<String>('tasks-gantt-vertical'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: tasks.length + 3,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return SizedBox(
                      width: math.max(0, viewportWidth - 32),
                      height: 52,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            language.translate('tasks_gantt_timeline_title'),
                            style: textStyles.captionSans.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${DateFormat('dd.MM.yyyy').format(timelineStart)} - '
                            '${DateFormat('dd.MM.yyyy').format(timelineEnd)}',
                            style: textStyles.smallMono.copyWith(
                              color: colors.textTooltip,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (index == 1) {
                    return SizedBox(
                      width: chartWidth,
                      height: 40,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _GanttHeaderPainter(
                                timelineStart: timelineStart,
                                columnCount: columnCount,
                                bucketDays: bucketDays,
                                dayColumnWidth: _dayColumnWidth,
                                taskColumnWidth: _taskColumnWidth,
                                backgroundColor: colors.surfaceNested,
                                borderColor: colors.border,
                                normalTextStyle: textStyles.smallMono.copyWith(
                                  fontSize: 9,
                                  color: colors.textSecondary,
                                ),
                                todayTextStyle: textStyles.smallMono.copyWith(
                                  fontSize: 9,
                                  color: colors.brand,
                                  fontWeight: FontWeight.bold,
                                ),
                                monthNames: monthNames,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: _taskColumnWidth,
                            height: 40,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  language.translate('tasks_gantt_task_column'),
                                  style: textStyles.captionSans.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (index == tasks.length + 2) {
                    return SizedBox(
                      width: math.max(0, viewportWidth - 32),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            _legendItem(
                              context,
                              colors.surfaceNested,
                              colors.border,
                              language.translate(
                                TaskStatus.todo.localizationKey,
                              ),
                            ),
                            _legendItem(
                              context,
                              colors.brand.withValues(alpha: 0.1),
                              colors.brand,
                              language.translate(
                                TaskStatus.inProgress.localizationKey,
                              ),
                            ),
                            _legendItem(
                              context,
                              colors.accentAmber.withValues(alpha: 0.1),
                              colors.accentAmber,
                              language.translate('tasks_gantt_legend_review'),
                            ),
                            _legendItem(
                              context,
                              colors.accentGreen.withValues(alpha: 0.1),
                              colors.accentGreen,
                              language.translate(
                                TaskStatus.done.localizationKey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final task = tasks[index - 2];
                  final palette = _paletteForStatus(context, task.status);
                  final assignee = language.translateMessage(
                    task.assigneeName ?? language.translate('tasks_unassigned'),
                  );

                  return SizedBox(
                    width: chartWidth,
                    height: _rowHeight,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: _GanttRowPainter(
                                task: task,
                                timelineStart: timelineStart,
                                columnCount: columnCount,
                                bucketDays: bucketDays,
                                dayColumnWidth: _dayColumnWidth,
                                taskColumnWidth: _taskColumnWidth,
                                surfaceColor: colors.surface,
                                borderColor: colors.border,
                                todayColor: colors.accentRed.withValues(
                                  alpha: 0.5,
                                ),
                                barColor: palette.fill,
                                barBorderColor: palette.border,
                                barTextColor: palette.text,
                                barTextStyle: textStyles.smallMono.copyWith(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                                dueDateLabel: dueDateFormatter.format(
                                  task.dueDate,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: _taskColumnWidth,
                          height: _rowHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          color: colors.surface,
                          alignment: Alignment.centerLeft,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.title,
                                style: textStyles.captionSans.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                assignee,
                                style: textStyles.smallSans.copyWith(
                                  color: colors.textTooltip,
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  _GanttPalette _paletteForStatus(BuildContext context, TaskStatus status) {
    final colors = context.colors;
    return switch (status) {
      TaskStatus.todo => _GanttPalette(
        fill: colors.surfaceNested,
        border: colors.border,
        text: colors.textSecondary,
      ),
      TaskStatus.inProgress => _GanttPalette(
        fill: colors.brand.withValues(alpha: 0.1),
        border: colors.brand,
        text: colors.brand,
      ),
      TaskStatus.review => _GanttPalette(
        fill: colors.accentAmber.withValues(alpha: 0.1),
        border: colors.accentAmber,
        text: colors.accentAmber,
      ),
      TaskStatus.done => _GanttPalette(
        fill: colors.accentGreen.withValues(alpha: 0.1),
        border: colors.accentGreen,
        text: colors.accentGreen,
      ),
    };
  }

  Widget _legendItem(
    BuildContext context,
    Color fill,
    Color border,
    String label,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: context.textStyles.smallSans),
      ],
    );
  }
}

class _GanttPalette {
  final Color fill;
  final Color border;
  final Color text;

  const _GanttPalette({
    required this.fill,
    required this.border,
    required this.text,
  });
}

class _GanttHeaderPainter extends CustomPainter {
  final DateTime timelineStart;
  final int columnCount;
  final int bucketDays;
  final double dayColumnWidth;
  final double taskColumnWidth;
  final Color backgroundColor;
  final Color borderColor;
  final TextStyle normalTextStyle;
  final TextStyle todayTextStyle;
  final List<String> monthNames;

  const _GanttHeaderPainter({
    required this.timelineStart,
    required this.columnCount,
    required this.bucketDays,
    required this.dayColumnWidth,
    required this.taskColumnWidth,
    required this.backgroundColor,
    required this.borderColor,
    required this.normalTextStyle,
    required this.todayTextStyle,
    required this.monthNames,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);
    final linePaint = Paint()
      ..color = borderColor
      ..strokeWidth = 1;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke,
    );
    canvas.drawLine(
      Offset(taskColumnWidth, 0),
      Offset(taskColumnWidth, size.height),
      linePaint,
    );

    final today = DateUtils.dateOnly(DateTime.now());
    for (var index = 0; index < columnCount; index++) {
      final x = taskColumnWidth + index * dayColumnWidth;
      if (index > 0) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
      }
      final date = timelineStart.add(Duration(days: index * bucketDays));
      final bucketEnd = date.add(Duration(days: bucketDays - 1));
      final containsToday = !today.isBefore(date) && !today.isAfter(bucketEnd);
      final painter = TextPainter(
        text: TextSpan(
          text: '${date.day}\n${monthNames[date.month - 1]}',
          style: containsToday ? todayTextStyle : normalTextStyle,
        ),
        textAlign: TextAlign.center,
        textDirection: ui.TextDirection.ltr,
        maxLines: 2,
      )..layout(maxWidth: dayColumnWidth - 4);
      painter.paint(
        canvas,
        Offset(
          x + (dayColumnWidth - painter.width) / 2,
          (size.height - painter.height) / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GanttHeaderPainter oldDelegate) {
    return oldDelegate.timelineStart != timelineStart ||
        oldDelegate.columnCount != columnCount ||
        oldDelegate.bucketDays != bucketDays ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.normalTextStyle != normalTextStyle ||
        oldDelegate.todayTextStyle != todayTextStyle ||
        oldDelegate.monthNames != monthNames;
  }
}

class _GanttRowPainter extends CustomPainter {
  final Task task;
  final DateTime timelineStart;
  final int columnCount;
  final int bucketDays;
  final double dayColumnWidth;
  final double taskColumnWidth;
  final Color surfaceColor;
  final Color borderColor;
  final Color todayColor;
  final Color barColor;
  final Color barBorderColor;
  final Color barTextColor;
  final TextStyle barTextStyle;
  final String dueDateLabel;

  const _GanttRowPainter({
    required this.task,
    required this.timelineStart,
    required this.columnCount,
    required this.bucketDays,
    required this.dayColumnWidth,
    required this.taskColumnWidth,
    required this.surfaceColor,
    required this.borderColor,
    required this.todayColor,
    required this.barColor,
    required this.barBorderColor,
    required this.barTextColor,
    required this.barTextStyle,
    required this.dueDateLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = surfaceColor);
    final linePaint = Paint()
      ..color = borderColor.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      Paint()
        ..color = borderColor
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      Offset(taskColumnWidth, 0),
      Offset(taskColumnWidth, size.height),
      Paint()
        ..color = borderColor
        ..strokeWidth = 1,
    );
    for (var index = 1; index < columnCount; index++) {
      final x = taskColumnWidth + index * dayColumnWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }

    final todayOffset = DateUtils.dateOnly(
      DateTime.now(),
    ).difference(timelineStart).inDays;
    final totalTimelineDays = columnCount * bucketDays;
    if (todayOffset >= 0 && todayOffset < totalTimelineDays) {
      final todayX =
          taskColumnWidth + (todayOffset / bucketDays) * dayColumnWidth;
      canvas.drawLine(
        Offset(todayX, 0),
        Offset(todayX, size.height),
        Paint()
          ..color = todayColor
          ..strokeWidth = 1.5,
      );
    }

    var start = DateUtils.dateOnly(task.startDate ?? task.dueDate);
    var end = DateUtils.dateOnly(task.dueDate);
    if (end.isBefore(start)) {
      final originalStart = start;
      start = end;
      end = originalStart;
    }
    final startOffset = start.difference(timelineStart).inDays;
    final durationDays = math.max(1, end.difference(start).inDays + 1);
    final timelineWidth = columnCount * dayColumnWidth;
    final rawLeft = (startOffset / bucketDays) * dayColumnWidth + 4;
    final left = rawLeft.clamp(4.0, math.max(4.0, timelineWidth - 8));
    final rawWidth = math.max(
      10.0,
      (durationDays / bucketDays) * dayColumnWidth - 8,
    );
    final width = math.min(rawWidth, math.max(4.0, timelineWidth - left - 4));
    final barRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(taskColumnWidth + left, 10, width, size.height - 20),
      const Radius.circular(4),
    );
    canvas.drawRRect(barRect, Paint()..color = barColor);
    canvas.drawRRect(
      barRect,
      Paint()
        ..color = barBorderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    if (width >= 28) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: dueDateLabel,
          style: barTextStyle.copyWith(color: barTextColor),
        ),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      )..layout(maxWidth: math.max(0, width - 12));
      textPainter.paint(
        canvas,
        Offset(
          taskColumnWidth + left + 6,
          (size.height - textPainter.height) / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GanttRowPainter oldDelegate) {
    return oldDelegate.task != task ||
        oldDelegate.timelineStart != timelineStart ||
        oldDelegate.columnCount != columnCount ||
        oldDelegate.bucketDays != bucketDays ||
        oldDelegate.surfaceColor != surfaceColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.todayColor != todayColor ||
        oldDelegate.barColor != barColor ||
        oldDelegate.barBorderColor != barBorderColor ||
        oldDelegate.barTextColor != barTextColor ||
        oldDelegate.dueDateLabel != dueDateLabel;
  }
}

List<String> _ganttMonthShortNames(LanguageCubit language) {
  const keys = [
    'tasks_month_short_january',
    'tasks_month_short_february',
    'tasks_month_short_march',
    'tasks_month_short_april',
    'tasks_month_short_may',
    'tasks_month_short_june',
    'tasks_month_short_july',
    'tasks_month_short_august',
    'tasks_month_short_september',
    'tasks_month_short_october',
    'tasks_month_short_november',
    'tasks_month_short_december',
  ];
  return [for (final key in keys) language.translate(key)];
}

class _TaskFormPopScope extends StatefulWidget {
  final bool Function() isDirty;
  final Widget child;

  const _TaskFormPopScope({required this.isDirty, required this.child});

  @override
  State<_TaskFormPopScope> createState() => _TaskFormPopScopeState();
}

class _TaskFormPopScopeState extends State<_TaskFormPopScope> {
  bool _allowPop = false;
  bool _isShowingDialog = false;

  Future<void> _requestPop() async {
    if (_isShowingDialog) return;

    if (widget.isDirty()) {
      _isShowingDialog = true;
      final shouldClose = await LedgerBottomSheet.confirmDiscard(context);
      _isShowingDialog = false;
      if (shouldClose != true || !mounted) return;
    }

    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _requestPop();
      },
      child: widget.child,
    );
  }
}
