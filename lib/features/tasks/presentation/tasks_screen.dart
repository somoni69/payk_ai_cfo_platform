import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/auth/bloc/auth_state.dart';
import '../../../features/auth/domain/app_access.dart';
import '../../../features/tasks/bloc/tasks_bloc.dart';
import '../../../features/tasks/bloc/tasks_event.dart';
import '../../../features/tasks/bloc/tasks_state.dart';
import '../../../features/tasks/domain/tasks_repository.dart';
import '../../../features/tasks/domain/task_model.dart';
import '../../../presentation/widgets/ledger_card.dart';
import '../../../presentation/widgets/ledger_pill.dart';
import '../../../presentation/widgets/expansible_widget.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../../../presentation/widgets/ledger_collapsing_header.dart';

part 'tasks_list.dart';
part 'tasks_forms.dart';
part 'tasks_calendar.dart';
part 'tasks_analysis.dart';
part 'tasks_widgets.dart';

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

  /// Allows library parts / extensions to trigger rebuilds without calling
  /// protected [State.setState] directly.
  void _rebuild([VoidCallback? fn]) => setState(fn ?? () {});

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
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
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
                        return !identical(
                              previous.projects,
                              current.projects,
                            ) ||
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
                        onPressed: () => _showAddTaskBottomSheet(
                          context,
                          projects,
                          assignees,
                        ),
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
}
