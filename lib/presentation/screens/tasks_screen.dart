import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:intl/intl.dart';
import '../../core/theme/theme_extensions.dart';
import '../../features/tasks/bloc/tasks_bloc.dart';
import '../../features/tasks/bloc/tasks_event.dart';
import '../../features/tasks/bloc/tasks_state.dart';
import '../../features/tasks/domain/tasks_repository.dart';
import '../../features/tasks/domain/task_model.dart';
import '../widgets/ledger_card.dart';
import '../widgets/ledger_pill.dart';
import '../widgets/expansible_widget.dart';
import '../widgets/ledger_bottom_sheet.dart';

/// Входная точка планировщика задач с внедрением TasksBloc.
class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TasksBloc>(
      create: (context) => TasksBloc(context.read<TasksRepository>())..add(LoadTasks()),
      child: const TasksView(),
    );
  }
}

class TasksView extends StatefulWidget {
  const TasksView({super.key});

  @override
  State<TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends State<TasksView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Filters state
  String _searchQuery = '';
  String? _selectedProjectId;
  bool _onlyOverdue = false;

  // Calendar state
  DateTime _calendarMonth = DateTime.now();
  DateTime? _selectedCalendarDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  Widget _buildProjectFilterBar(BuildContext context, List<TaskProject> projects) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return Container(
      height: 34,
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
                isAll ? 'Все проекты' : project!.name,
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

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        scrolledUnderElevation: 0,
        title: Text('Задачи и планирование', style: textStyles.h1Sans),
        actions: [
          BlocBuilder<TasksBloc, TasksState>(
            builder: (context, state) {
              final projects = state is TasksLoaded ? state.projects : const <TaskProject>[];
              final assignees = state is TasksLoaded ? state.assignees : const <TaskAssignee>[];
              return IconButton(
                icon: const Icon(TablerIcons.plus),
                color: colors.brand,
                onPressed: () => _showAddTaskBottomSheet(context, projects, assignees),
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
          labelStyle: textStyles.captionSans.copyWith(fontWeight: FontWeight.w500),
          unselectedLabelStyle: textStyles.captionSans.copyWith(fontWeight: FontWeight.w400),
          tabs: const [
            Tab(text: 'Новые'),
            Tab(text: 'В работе'),
            Tab(text: 'Проверить'),
            Tab(text: 'Готово'),
            Tab(text: 'Календарь'),
            Tab(text: 'Гант'),
            Tab(text: 'Аналитика'),
          ],
        ),
      ),
      body: BlocListener<TasksBloc, TasksState>(
        listenWhen: (previous, current) {
          if (previous is TasksLoaded && current is TasksLoaded) {
            final prevResult = previous.lastStatusUpdateResult;
            final currResult = current.lastStatusUpdateResult;
            if (currResult != null && currResult.operationId != prevResult?.operationId) {
              return currResult.newStatus == TaskStatus.done;
            }
          }
          return false;
        },
        listener: (context, state) {
          if (state is! TasksLoaded) return;
          final result = state.lastStatusUpdateResult!;
          
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Задача завершена'),
              action: SnackBarAction(
                label: 'Отменить',
                onPressed: () {
                  context.read<TasksBloc>().add(UpdateTaskStatusRequested(
                        taskId: result.taskId,
                        status: result.previousStatus,
                      ));
                },
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        },
        child: BlocBuilder<TasksBloc, TasksState>(
          builder: (context, state) {
          if (state is TasksLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (state is TasksError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(TablerIcons.alert_triangle, color: colors.accentRed, size: 40),
                    const SizedBox(height: 12),
                    Text(state.message, style: textStyles.bodySans, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.read<TasksBloc>().add(LoadTasks());
                      },
                      child: const Text('Повторить попытку'),
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
                            hintText: 'Поиск по задачам...',
                            prefixIcon: Icon(TablerIcons.search, size: 18, color: colors.textSecondary),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
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
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: _onlyOverdue
                                ? colors.accentRed.withValues(alpha: 0.08)
                                : colors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _onlyOverdue ? colors.accentRed : colors.border,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            children: [
                              Icon(
                                TablerIcons.alert_triangle,
                                size: 16,
                                color: _onlyOverdue ? colors.accentRed : colors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Просрочено',
                                style: textStyles.captionSans.copyWith(
                                  color: _onlyOverdue ? colors.accentRed : colors.textPrimary,
                                  fontWeight: _onlyOverdue ? FontWeight.bold : FontWeight.normal,
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
                      _buildTaskList(context, filteredTasks, TaskStatus.todo, state.projects, state.assignees, state.pendingStatusTaskIds),
                      _buildTaskList(context, filteredTasks, TaskStatus.inProgress, state.projects, state.assignees, state.pendingStatusTaskIds),
                      _buildTaskList(context, filteredTasks, TaskStatus.review, state.projects, state.assignees, state.pendingStatusTaskIds),
                      _buildTaskList(context, filteredTasks, TaskStatus.done, state.projects, state.assignees, state.pendingStatusTaskIds),
                      _buildCalendarTab(context, filteredTasks, state.projects, state.assignees),
                      _buildGanttTab(context, filteredTasks),
                      _buildAnalysisTab(context, state.overloaded, state.criticalPath),
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

  Widget _buildCheckbox(BuildContext context, Task task, bool isDone, bool isPending) {
    return AnimatedCheckbox(
      value: isDone,
      isPending: isPending,
      onChanged: (newValue) {
        if (isPending) return;
        final nextStatus = newValue ? TaskStatus.done : TaskStatus.todo;
        context.read<TasksBloc>().add(UpdateTaskStatusRequested(
              taskId: task.id,
              status: nextStatus,
            ));
      },
    );
  }

  Widget _buildTaskListHeader(BuildContext context, List<Task> tasks, TaskStatus status) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final count = tasks.length;
    final urgentCount = tasks.where((t) => t.priority == TaskPriority.urgent).length;
    final highCount = tasks.where((t) => t.priority == TaskPriority.high).length;

    String titleText = '';

    switch (status) {
      case TaskStatus.todo:
        titleText = 'Новые задачи';
        break;
      case TaskStatus.inProgress:
        titleText = 'Задачи в работе';
        break;
      case TaskStatus.review:
        titleText = 'Задачи на проверке';
        break;
      case TaskStatus.done:
        titleText = 'Готовые задачи';
        break;
    }

    final List<String> priorityList = [];
    if (urgentCount > 0) {
      priorityList.add('$urgentCount критических');
    }
    if (highCount > 0) {
      priorityList.add('$highCount высокого приоритета');
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
                style: textStyles.bodySans.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.brand.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _taskCountLabel(count),
                  style: textStyles.captionSans.copyWith(color: colors.brand, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (priorityText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              priorityText,
              style: textStyles.captionSans.copyWith(color: colors.textSecondary),
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

    final tasks = allTasks.where((t) => t.status == status).toList();

    return RefreshIndicator(
      onRefresh: () async {
        context.read<TasksBloc>().add(LoadTasks());
      },
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
            onTap: () => _showEditTaskBottomSheet(context, task, projects, assignees),
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
                            decoration: isDone ? TextDecoration.lineThrough : null,
                            color: isDone ? colors.textTooltip : colors.textPrimary,
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
                                  color: colors.textSecondary.withValues(alpha: 0.4),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Icon(TablerIcons.calendar, size: 12, color: colors.textTooltip),
                            const SizedBox(width: 4),
                            Text(
                              _formatRussianDate(task.dueDate),
                              style: textStyles.captionSans.copyWith(
                                color: task.dueDate.isBefore(DateTime.now()) && !isDone
                                    ? colors.accentRed
                                    : colors.textTooltip,
                              ),
                            ),
                            if (task.assigneeName != null && task.assigneeName!.trim().isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: colors.textSecondary.withValues(alpha: 0.4),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(TablerIcons.user, size: 12, color: colors.textTooltip),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  task.assigneeName!,
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
                    text: task.priority.label,
                    backgroundColor: pColor,
                    textColor: pTextColor,
                    fontSize: 13,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildCheckbox(context, task, isDone, pendingTaskIds.contains(task.id)),
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

    Widget buildChip(TaskPriority priority) {
      final isSelected = selectedPriority == priority;
      return ChoiceChip(
        label: Text(
          priority.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        selected: isSelected,
        onSelected: (val) {
          if (val) onSelected(priority);
        },
        selectedColor: switch (priority) {
          TaskPriority.urgent => colors.accentRed,
          TaskPriority.high => colors.accentAmber,
          TaskPriority.low => colors.accentGreen,
          TaskPriority.medium => colors.brand.withValues(alpha: 0.15),
        },
        backgroundColor: colors.surfaceNested,
        labelStyle: textStyles.captionSans.copyWith(
          fontWeight: FontWeight.w500,
          fontSize: 13,
          color: isSelected
              ? (priority == TaskPriority.medium
                  ? colors.brand
                  : Colors.white)
              : colors.textSecondary,
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected ? Colors.transparent : colors.border,
          ),
        ),
        showCheckmark: false,
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: buildChip(TaskPriority.low)),
            const SizedBox(width: 8),
            Expanded(child: buildChip(TaskPriority.medium)),
            const SizedBox(width: 8),
            Expanded(child: buildChip(TaskPriority.high)),
          ],
        ),
        const SizedBox(height: 8),
        Center(child: buildChip(TaskPriority.urgent)),
      ],
    );
  }

  void _showAddTaskBottomSheet(
    BuildContext context,
    List<TaskProject> projects,
    List<TaskAssignee> assignees,
  ) {
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

    bool isShowingDiscardDialog = false;
    bool allowPop = false;

    bool isDirty() {
      return titleController.text.trim().isNotEmpty ||
             descController.text.trim().isNotEmpty ||
             selectedProject != null ||
             selectedAssignee != null ||
             selectedStartDate != null ||
             selectedPriority != TaskPriority.medium;
    }

    LedgerBottomSheet.show(
      context: context,
      title: 'Новая задача',
      builder: (context, setSheetState) {
        return PopScope(
          canPop: !isDirty() || allowPop,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            if (isShowingDiscardDialog) return;

            isShowingDiscardDialog = true;
            final shouldClose = await LedgerBottomSheet.confirmDiscard(context);
            isShowingDiscardDialog = false;

            if (shouldClose == true) {
              allowPop = true;
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: titleController,
                style: textStyles.bodySans,
                decoration: const InputDecoration(
                  labelText: 'Название задачи',
                ),
                onChanged: (_) => setSheetState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 3,
                style: textStyles.bodySans,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Описание',
                ),
                onChanged: (_) => setSheetState(() {}),
              ),
              const SizedBox(height: 16),
              Text('Проект', style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 6),
              ExpansibleWidget<TaskProject?>.selection(
                key: ValueKey(selectedProject?.id ?? 'no-project'),
                cardPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                title: Text(
                  selectedProject?.name ?? 'Выберите проект (опц.)',
                  style: textStyles.bodySans.copyWith(color: selectedProject == null ? colors.textTooltip : colors.textPrimary),
                ),
                items: [null, ...projects],
                selectedValue: selectedProject,
                itemLabelBuilder: (p) => p?.name ?? 'Без проекта',
                onSelected: (p) {
                  setSheetState(() {
                    selectedProject = p;
                  });
                },
              ),
              const SizedBox(height: 16),
              Text('Приоритет', style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
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
              Text('Исполнитель', style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 6),
              ExpansibleWidget<TaskAssignee?>.selection(
                key: ValueKey(selectedAssignee?.id ?? 'no-assignee'),
                cardPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                title: Text(
                  selectedAssignee?.fullName ?? 'Без исполнителя',
                  style: textStyles.bodySans.copyWith(
                    color: selectedAssignee == null ? colors.textTooltip : colors.textPrimary,
                  ),
                ),
                items: [null, ...assignees],
                selectedValue: selectedAssignee,
                itemLabelBuilder: (a) => a?.fullName ?? 'Без исполнителя',
                onSelected: (a) {
                  setSheetState(() {
                    selectedAssignee = a;
                  });
                },
              ),
              const SizedBox(height: 16),
              Text('Дата начала', style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedStartDate ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setSheetState(() {
                      selectedStartDate = picked;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.border),
                    borderRadius: BorderRadius.circular(8),
                    color: colors.surface,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        selectedStartDate != null ? DateFormat('dd.MM.yyyy').format(selectedStartDate!) : 'Не задана',
                        style: textStyles.captionSans,
                      ),
                      Icon(TablerIcons.calendar, size: 16, color: colors.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Срок сдачи', style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDueDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setSheetState(() {
                      selectedDueDate = picked;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                      Icon(TablerIcons.calendar, size: 16, color: colors.textSecondary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      footerBuilder: (context, setSheetState) {
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
          child: const Text('Создать'),
        );
      },
    );
  }

  void _showEditTaskBottomSheet(
    BuildContext context,
    Task task,
    List<TaskProject> projects,
    List<TaskAssignee> assignees,
  ) {
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

    bool isShowingDiscardDialog = false;
    bool allowPop = false;

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

    LedgerBottomSheet.show(
      context: context,
      title: 'Редактировать задачу',
      builder: (context, setSheetState) {
        return PopScope(
          canPop: !isDirty() || allowPop,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            if (isShowingDiscardDialog) return;

            isShowingDiscardDialog = true;
            final shouldClose = await LedgerBottomSheet.confirmDiscard(context);
            isShowingDiscardDialog = false;

            if (shouldClose == true) {
              allowPop = true;
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: titleController,
                style: textStyles.bodySans,
                decoration: const InputDecoration(
                  labelText: 'Название задачи',
                ),
                onChanged: (_) => setSheetState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 3,
                style: textStyles.bodySans,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Описание',
                ),
                onChanged: (_) => setSheetState(() {}),
              ),
              const SizedBox(height: 16),
              Text('Этап и статус', style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 6),
              ExpansibleWidget<TaskStatus>.selection(
                key: ValueKey(selectedStatus),
                cardPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                title: Text(selectedStatus.label, style: textStyles.bodySans),
                items: TaskStatus.values,
                selectedValue: selectedStatus,
                itemLabelBuilder: (s) => s.label,
                onSelected: (s) {
                  setSheetState(() {
                    selectedStatus = s;
                  });
                },
              ),
              const SizedBox(height: 16),
              Text('Проект', style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 6),
              ExpansibleWidget<TaskProject?>.selection(
                key: ValueKey(selectedProject?.id ?? 'no-project'),
                cardPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                title: Text(
                  selectedProject?.name ?? 'Выберите проект (опц.)',
                  style: textStyles.bodySans.copyWith(color: selectedProject == null ? colors.textTooltip : colors.textPrimary),
                ),
                items: [null, ...projects],
                selectedValue: selectedProject,
                itemLabelBuilder: (p) => p?.name ?? 'Без проекта',
                onSelected: (p) {
                  setSheetState(() {
                    selectedProject = p;
                  });
                },
              ),
              const SizedBox(height: 16),
              Text('Приоритет', style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
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
              Text('Исполнитель', style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 6),
              ExpansibleWidget<TaskAssignee?>.selection(
                key: ValueKey(selectedAssignee?.id ?? 'no-assignee'),
                cardPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                title: Text(
                  selectedAssignee?.fullName ?? 'Без исполнителя',
                  style: textStyles.bodySans.copyWith(
                    color: selectedAssignee == null ? colors.textTooltip : colors.textPrimary,
                  ),
                ),
                items: [null, ...assignees],
                selectedValue: selectedAssignee,
                itemLabelBuilder: (a) => a?.fullName ?? 'Без исполнителя',
                onSelected: (a) {
                  setSheetState(() {
                    selectedAssignee = a;
                  });
                },
              ),
              const SizedBox(height: 16),
              Text('Дата начала', style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedStartDate ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setSheetState(() {
                      selectedStartDate = picked;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.border),
                    borderRadius: BorderRadius.circular(8),
                    color: colors.surface,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        selectedStartDate != null ? DateFormat('dd.MM.yyyy').format(selectedStartDate!) : 'Не задана',
                        style: textStyles.captionSans,
                      ),
                      Icon(TablerIcons.calendar, size: 16, color: colors.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Срок сдачи', style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDueDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setSheetState(() {
                      selectedDueDate = picked;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                      Icon(TablerIcons.calendar, size: 16, color: colors.textSecondary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      footerBuilder: (context, setSheetState) {
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
          child: const Text('Сохранить изменения'),
        );
      },
    );
  }

  Widget _buildCalendarTab(
    BuildContext context,
    List<Task> tasks,
    List<TaskProject> projects,
    List<TaskAssignee> assignees,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    final year = _calendarMonth.year;
    final month = _calendarMonth.month;

    final firstDay = DateTime(year, month, 1);
    final weekdayOffset = (firstDay.weekday - 1) % 7;
    final startGridDate = firstDay.subtract(Duration(days: weekdayOffset));

    final gridDates = List<DateTime>.generate(42, (index) => startGridDate.add(Duration(days: index)));

    final monthNames = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
    ];
    final weekdayLabels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

    return RefreshIndicator(
      onRefresh: () async {
        context.read<TasksBloc>().add(LoadTasks());
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${monthNames[month - 1]} $year',
                style: textStyles.h2Sans,
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(TablerIcons.chevron_left),
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
                    child: Text('Сегодня', style: textStyles.captionSans.copyWith(color: colors.brand, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(TablerIcons.chevron_right),
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
          const SizedBox(height: 12),
          GridView.builder(
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
                  style: textStyles.smallSans.copyWith(color: colors.textSecondary),
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          GridView.builder(
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
              final isSelected = _selectedCalendarDay != null && DateUtils.isSameDay(day, _selectedCalendarDay!);
              final dayTasks = tasks.where((t) => DateUtils.isSameDay(t.dueDate, day)).toList();

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
                          fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
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
              'Срок на ${DateFormat('dd MMMM yyyy').format(_selectedCalendarDay!)}:',
              style: textStyles.bodySans.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildDayTasksList(context, tasks, _selectedCalendarDay!, projects, assignees),
          ] else ...[
            Center(
              child: Text(
                'Выберите день для просмотра задач',
                style: textStyles.captionSans.copyWith(color: colors.textTooltip),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDayTasksList(
    BuildContext context,
    List<Task> tasks,
    DateTime selectedDay,
    List<TaskProject> projects,
    List<TaskAssignee> assignees,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final dayTasks = tasks.where((t) => DateUtils.isSameDay(t.dueDate, selectedDay)).toList();

    if (dayTasks.isEmpty) {
      return LedgerCard(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            'Нет запланированных задач на этот день',
            style: textStyles.captionSans.copyWith(color: colors.textTooltip),
          ),
        ),
      );
    }

    return Column(
      children: dayTasks.map((task) {
        return GestureDetector(
          onTap: () => _showEditTaskBottomSheet(context, task, projects, assignees),
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
                        style: textStyles.bodySans.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (task.projectName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Проект: ${task.projectName}',
                          style: textStyles.captionSans.copyWith(color: colors.textSecondary),
                        ),
                      ],
                      if (task.assigneeName != null && task.assigneeName!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '👤 ${task.assigneeName}',
                          style: textStyles.captionSans.copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                LedgerPill(
                  text: task.status.label,
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

  Widget _buildGanttTab(BuildContext context, List<Task> tasks) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    final ganttTasks = tasks.toList();
    if (ganttTasks.isEmpty) {
      return Center(
        child: Text('Нет задач для отображения на диаграмме', style: textStyles.captionSans.copyWith(color: colors.textTooltip)),
      );
    }

    DateTime? minDate;
    DateTime? maxDate;

    for (final task in ganttTasks) {
      final start = task.startDate ?? task.dueDate;
      final end = task.dueDate;
      
      if (minDate == null || start.isBefore(minDate)) {
        minDate = start;
      }
      if (maxDate == null || end.isAfter(maxDate)) {
        maxDate = end;
      }
    }

    final calculatedMinDate = minDate ?? DateTime.now().subtract(const Duration(days: 3));
    final calculatedMaxDate = maxDate ?? DateTime.now().add(const Duration(days: 7));

    final startTimelineDate = DateTime(calculatedMinDate.year, calculatedMinDate.month, calculatedMinDate.day).subtract(const Duration(days: 1));
    final endTimelineDate = DateTime(calculatedMaxDate.year, calculatedMaxDate.month, calculatedMaxDate.day).add(const Duration(days: 2));

    final totalDays = endTimelineDate.difference(startTimelineDate).inDays + 1;
    const dayWidth = 44.0;
    final timelineWidth = totalDays * dayWidth;

    return RefreshIndicator(
      onRefresh: () async {
        context.read<TasksBloc>().add(LoadTasks());
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ВРЕМЕННАЯ ШКАЛА ЗАДАЧ',
              style: textStyles.captionSans.copyWith(fontWeight: FontWeight.bold, color: colors.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: timelineWidth + 180,
                  child: Column(
                    children: [
                      Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: colors.surfaceNested,
                          border: Border(bottom: BorderSide(color: colors.border)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 180,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              alignment: Alignment.centerLeft,
                              child: Text('Задача', style: textStyles.captionSans.copyWith(fontWeight: FontWeight.bold)),
                            ),
                            ...List.generate(totalDays, (index) {
                              final day = startTimelineDate.add(Duration(days: index));
                              final isToday = DateUtils.isSameDay(day, DateTime.now());
                              return Container(
                                width: dayWidth,
                                decoration: BoxDecoration(
                                  border: Border(left: BorderSide(color: colors.border)),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${day.day}\n${_monthShortName(day.month)}',
                                  textAlign: TextAlign.center,
                                  style: textStyles.smallMono.copyWith(
                                    fontSize: 9,
                                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                    color: isToday ? colors.brand : colors.textSecondary,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      ...ganttTasks.map((task) {
                        final start = task.startDate ?? task.dueDate;
                        final end = task.dueDate;
                        
                        final normalizedStart = DateTime(start.year, start.month, start.day);
                        final normalizedEnd = DateTime(end.year, end.month, end.day);
                        
                        int offsetDays = normalizedStart.difference(startTimelineDate).inDays;
                        if (offsetDays < 0) offsetDays = 0;

                        int durationDays = normalizedEnd.difference(normalizedStart).inDays + 1;
                        if (durationDays < 1) durationDays = 1;

                        final double leftOffset = offsetDays * dayWidth;
                        final double barWidth = durationDays * dayWidth;

                        Color barColor = colors.surfaceNested;
                        Color textColor = colors.textSecondary;
                        Color borderColor = colors.border;

                        if (task.status == TaskStatus.todo) {
                          barColor = colors.surfaceNested;
                          textColor = colors.textSecondary;
                        } else if (task.status == TaskStatus.inProgress) {
                          barColor = colors.brand.withValues(alpha: 0.1);
                          textColor = colors.brand;
                          borderColor = colors.brand;
                        } else if (task.status == TaskStatus.review) {
                          barColor = colors.accentAmber.withValues(alpha: 0.1);
                          textColor = colors.accentAmber;
                          borderColor = colors.accentAmber;
                        } else if (task.status == TaskStatus.done) {
                          barColor = colors.accentGreen.withValues(alpha: 0.1);
                          textColor = colors.accentGreen;
                          borderColor = colors.accentGreen;
                        }

                        return Container(
                          height: 48,
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: colors.border)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 180,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                alignment: Alignment.centerLeft,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      task.title,
                                      style: textStyles.captionSans.copyWith(fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      task.assigneeName ?? 'Не назначена',
                                      style: textStyles.smallSans.copyWith(color: colors.textTooltip, fontSize: 10),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Row(
                                        children: List.generate(totalDays, (index) {
                                          return Container(
                                            width: dayWidth,
                                            decoration: BoxDecoration(
                                              border: Border(left: BorderSide(color: colors.border.withValues(alpha: 0.4))),
                                            ),
                                          );
                                        }),
                                      ),
                                    ),
                                    Positioned(
                                      left: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).difference(startTimelineDate).inDays * dayWidth + (dayWidth / 2),
                                      top: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 1.5,
                                        color: colors.accentRed.withValues(alpha: 0.5),
                                      ),
                                    ),
                                    Positioned(
                                      left: leftOffset + 4,
                                      top: 10,
                                      bottom: 10,
                                      width: barWidth - 8,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: barColor,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: borderColor, width: 1.5),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          DateFormat('dd.MM').format(task.dueDate),
                                          style: textStyles.smallMono.copyWith(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildGanttLegendItem(colors.surfaceNested, colors.border, 'Новая', textStyles),
                _buildGanttLegendItem(colors.brand.withValues(alpha: 0.1), colors.brand, 'В работе', textStyles),
                _buildGanttLegendItem(colors.accentAmber.withValues(alpha: 0.1), colors.accentAmber, 'Проверка', textStyles),
                _buildGanttLegendItem(colors.accentGreen.withValues(alpha: 0.1), colors.accentGreen, 'Готово', textStyles),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGanttLegendItem(Color fill, Color border, String label, dynamic textStyles) {
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
        Text(label, style: textStyles.smallSans),
      ],
    );
  }

  String _monthShortName(int month) {
    const list = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    return list[month - 1];
  }

  Widget _buildAnalysisTab(BuildContext context, List<TaskOverload> overloaded, List<TaskCriticalPath> critical) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return RefreshIndicator(
      onRefresh: () async {
        context.read<TasksBloc>().add(LoadTasks());
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Icon(TablerIcons.alert_triangle, color: colors.accentRed, size: 18),
              const SizedBox(width: 8),
              Text(
                'ПЕРЕГРУЗКА СОТРУДНИКОВ',
                style: textStyles.captionSans.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (overloaded.isEmpty)
            LedgerCard(
              padding: const EdgeInsets.all(14),
              child: Center(
                child: Text(
                  'Перегруженных сотрудников не обнаружено',
                  style: textStyles.captionSans.copyWith(color: colors.textTooltip),
                ),
              ),
            )
          else
            ...overloaded.map((ov) {
              final initial = ov.assigneeName.isNotEmpty ? ov.assigneeName.characters.first.toUpperCase() : '?';
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
                            backgroundColor: colors.brand.withValues(alpha: 0.1),
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
                          Text(ov.assigneeName, style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500)),
                        ],
                      ),
                      Row(
                        children: [
                          LedgerPill(
                            text: 'Активных: ${ov.activeCount}',
                            backgroundColor: colors.accentRed.withValues(alpha: 0.08),
                            textColor: colors.accentRed,
                          ),
                          if (ov.overdueCount > 0) ...[
                            const SizedBox(width: 8),
                            LedgerPill(
                              text: 'Просрочено: ${ov.overdueCount}',
                              backgroundColor: colors.accentAmber.withValues(alpha: 0.1),
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
                'КРИТИЧЕСКИЙ ПУТЬ ЗАДАЧ',
                style: textStyles.captionSans.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (critical.isEmpty)
            LedgerCard(
              padding: const EdgeInsets.all(14),
              child: Center(
                child: Text(
                  'Блокирующих критический путь задач не найдено',
                  style: textStyles.captionSans.copyWith(color: colors.textTooltip),
                ),
              ),
            )
          else
            ...critical.map((cp) {
              String statusLabel = 'Новая';
              Color statusColor = colors.textSecondary;
              if (cp.status == 'in_progress') {
                statusLabel = 'В работе';
                statusColor = colors.brand;
              } else if (cp.status == 'review') {
                statusLabel = 'Проверка';
                statusColor = colors.accentAmber;
              } else if (cp.status == 'done') {
                statusLabel = 'Готово';
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
                            Text(cp.title, style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500)),
                            if (cp.dueDate != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Срок: ${DateFormat('dd MMM yyyy').format(cp.dueDate!)}',
                                style: textStyles.captionSans.copyWith(color: colors.textTooltip),
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
                            backgroundColor: statusColor.withValues(alpha: 0.08),
                            textColor: statusColor,
                          ),
                          if (cp.blocksCount > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Блокирует задач: ${cp.blocksCount}',
                              style: textStyles.smallMono.copyWith(color: colors.accentRed),
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
          UpdateTaskStatusRequested(
            taskId: widget.task.id,
            status: status,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
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
                task.status.label,
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
              status.label,
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
  final ValueChanged<bool> onChanged;

  const AnimatedCheckbox({
    super.key,
    required this.value,
    this.isPending = false,
    required this.onChanged,
  });

  @override
  State<AnimatedCheckbox> createState() => _AnimatedCheckboxState();
}

class _AnimatedCheckboxState extends State<AnimatedCheckbox> with SingleTickerProviderStateMixin {
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
      TweenSequenceItem(tween: Tween<double>(begin: 0.8, end: 1.15), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 1.15, end: 1.0), weight: 30),
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

    // Visual circle is 28px; outer box keeps a 48×48 tap target.
    return SizedBox(
      width: 48,
      height: 48,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.isPending
            ? null
            : () {
                widget.onChanged(!widget.value);
              },
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
                  color: widget.isPending
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
                        valueColor:
                            AlwaysStoppedAnimation<Color>(colors.accentGreen),
                      ),
                    )
                  : ScaleTransition(
                      scale: _checkScaleAnimation,
                      child: widget.value
                          ? Icon(TablerIcons.check,
                              size: 18, color: colors.accentGreen)
                          : const SizedBox.shrink(),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatRussianDate(DateTime date) {
  final months = [
    'янв.', 'фев.', 'мар.', 'апр.', 'май', 'июн.',
    'июл.', 'авг.', 'сен.', 'окт.', 'ноя.', 'дек.'
  ];
  return '${date.day} ${months[date.month - 1]}';
}

String _taskCountLabel(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;

  if (mod10 == 1 && mod100 != 11) {
    return '$count задача';
  }

  if (mod10 >= 2 &&
      mod10 <= 4 &&
      (mod100 < 12 || mod100 > 14)) {
    return '$count задачи';
  }

  return '$count задач';
}
