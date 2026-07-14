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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          GestureDetector(
            onTap: () => _showAddTaskDialog(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.brand.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(TablerIcons.plus, color: colors.brand, size: 20),
            ),
          ),
          const SizedBox(width: 16),
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
            Tab(text: 'Аналитика'),
          ],
        ),
      ),
      body: BlocBuilder<TasksBloc, TasksState>(
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
            return TabBarView(
              controller: _tabController,
              children: [
                _buildTaskList(context, state.tasks, TaskStatus.todo),
                _buildTaskList(context, state.tasks, TaskStatus.inProgress),
                _buildTaskList(context, state.tasks, TaskStatus.review),
                _buildTaskList(context, state.tasks, TaskStatus.done),
                _buildAnalysisTab(context, state.overloaded, state.criticalPath),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildCheckbox(BuildContext context, Task task, bool isDone) {
    final colors = context.colors;
    return GestureDetector(
      onTap: () {
        final nextStatus = isDone ? TaskStatus.todo : TaskStatus.done;
        context.read<TasksBloc>().add(UpdateTaskStatusRequested(
              taskId: task.id,
              status: nextStatus,
            ));
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isDone ? colors.accentGreen : colors.textSecondary.withValues(alpha: 0.4),
              width: 1.5,
            ),
            color: isDone ? colors.accentGreen.withValues(alpha: 0.1) : Colors.transparent,
          ),
          child: isDone
              ? Icon(TablerIcons.check, size: 14, color: colors.accentGreen)
              : null,
        ),
      ),
    );
  }

  Widget _buildTaskListHeader(BuildContext context, List<Task> tasks, TaskStatus status) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final count = tasks.length;
    final urgentCount = tasks.where((t) => t.priority == TaskPriority.urgent).length;
    final highCount = tasks.where((t) => t.priority == TaskPriority.high).length;

    String descText = '';
    String titleText = '';
    IconData headerIcon = TablerIcons.clipboard;

    switch (status) {
      case TaskStatus.todo:
        titleText = 'Новые задачи';
        descText = 'Задачи в очереди на выполнение. Перепроверьте приоритеты перед началом.';
        headerIcon = TablerIcons.clipboard;
        break;
      case TaskStatus.inProgress:
        titleText = 'Задачи в работе';
        descText = 'Задачи в активном процессе. Следите за сроками и дедлайнами.';
        headerIcon = TablerIcons.device_laptop;
        break;
      case TaskStatus.review:
        titleText = 'Задачи на проверке';
        descText = 'Завершенные задачи, ожидающие проверки и подтверждения.';
        headerIcon = TablerIcons.discount;
        break;
      case TaskStatus.done:
        titleText = 'Готовые задачи';
        descText = 'Успешно завершенные задачи. История проделанной работы компании.';
        headerIcon = TablerIcons.circle_check;
        break;
    }

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.brand.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(headerIcon, color: colors.brand, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
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
                            '$count шт',
                            style: textStyles.captionSans.copyWith(color: colors.brand, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      descText,
                      style: textStyles.captionSans.copyWith(color: colors.textSecondary, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (urgentCount > 0 || highCount > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (urgentCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.accentRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Срочно: $urgentCount',
                      style: textStyles.captionSans.copyWith(color: colors.accentRed, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (highCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.accentAmber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Высокий: $highCount',
                      style: textStyles.captionSans.copyWith(color: colors.accentAmber, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskList(BuildContext context, List<Task> allTasks, TaskStatus status) {
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

          return Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Цветной левый индикатор приоритета (премиальный Kanban-дизайн)
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: pTextColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildCheckbox(context, task, isDone),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      task.title,
                                      style: textStyles.bodySans.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        decoration: isDone ? TextDecoration.lineThrough : null,
                                        color: isDone ? colors.textTooltip : colors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      task.description,
                                      style: textStyles.captionSans.copyWith(color: colors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Icon(TablerIcons.calendar, size: 14, color: colors.textTooltip),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('dd MMM').format(task.dueDate),
                                style: textStyles.captionSans.copyWith(
                                  color: task.dueDate.isBefore(DateTime.now()) && !isDone
                                      ? colors.accentRed
                                      : colors.textTooltip,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 1,
                                height: 16,
                                color: colors.border,
                              ),
                              const SizedBox(width: 12),
                              _buildStatusMenu(context, task),
                              const Spacer(),
                              LedgerPill(
                                text: task.priority.label,
                                backgroundColor: pColor,
                                textColor: pTextColor,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusMenu(BuildContext context, Task task) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return SizedBox(
      width: 140,
      child: ExpansibleWidget(
        key: ValueKey(task.status),
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
            onTap: () {
              context.read<TasksBloc>().add(UpdateTaskStatusRequested(
                    taskId: task.id,
                    status: status,
                  ));
            },
          );
        }).toList(),
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    final tasksBloc = context.read<TasksBloc>();
    final colors = context.colors;
    final textStyles = context.textStyles;

    final titleController = TextEditingController();
    final descController = TextEditingController();
    TaskPriority selectedPriority = TaskPriority.medium;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colors.border),
              ),
              title: Text('Новая задача', style: textStyles.h2Sans),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: titleController,
                      style: textStyles.bodySans,
                      decoration: const InputDecoration(
                        labelText: 'Название задачи',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      maxLines: 3,
                      style: textStyles.bodySans,
                      decoration: const InputDecoration(
                        labelText: 'Описание',
                      ),
                    ),
                    const SizedBox(height: 16),
                    ExpansibleWidget(
                      key: ValueKey(selectedPriority),
                      cardPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      title: Text(selectedPriority.label, style: textStyles.bodySans),
                      children: TaskPriority.values.map((p) {
                        return ListTile(
                          title: Text(p.label, style: textStyles.bodySans),
                          onTap: () {
                            setDialogState(() {
                              selectedPriority = p;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.trim().isNotEmpty) {
                      final newTask = Task(
                        id: '',
                        title: titleController.text.trim(),
                        description: descController.text.trim(),
                        status: TaskStatus.todo,
                        dueDate: DateTime.now().add(const Duration(days: 3)),
                        priority: selectedPriority,
                      );
                      tasksBloc.add(CreateTaskRequested(newTask));
                      Navigator.pop(dialogCtx);
                    }
                  },
                  child: const Text('Создать'),
                ),
              ],
            );
          },
        );
      },
    );
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
