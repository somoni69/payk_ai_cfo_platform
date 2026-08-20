part of 'tasks_screen.dart';

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
                fontWeight: isCurrent ? FontWeight.w500 : FontWeight.w400,
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

/// Builds a tab lazily on first activation, then keeps it mounted (offstage)
/// so NestedScrollView/tab transitions do not tear down InheritedWidgets mid-frame.
class _LazyTaskTab extends StatefulWidget {
  final bool isActive;
  final WidgetBuilder builder;

  const _LazyTaskTab({required this.isActive, required this.builder});

  @override
  State<_LazyTaskTab> createState() => _LazyTaskTabState();
}

class _LazyTaskTabState extends State<_LazyTaskTab>
    with AutomaticKeepAliveClientMixin {
  bool _hasBeenActive = false;

  @override
  bool get wantKeepAlive => _hasBeenActive;

  @override
  void didUpdateWidget(covariant _LazyTaskTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_hasBeenActive) {
      _hasBeenActive = true;
      updateKeepAlive();
    }
  }

  @override
  void initState() {
    super.initState();
    _hasBeenActive = widget.isActive;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_hasBeenActive && !widget.isActive) {
      return const SizedBox.expand();
    }
    _hasBeenActive = true;
    return TickerMode(
      enabled: widget.isActive,
      child: Offstage(
        offstage: !widget.isActive,
        child: widget.builder(context),
      ),
    );
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final contentWidth = math.max(viewportWidth, chartWidth + 32);
        final rangeLabel =
            '${formatLocalizedDateTime(context, timelineStart, style: LocalizedDateTimeStyle.date)} – '
            '${formatLocalizedDateTime(context, timelineEnd, style: LocalizedDateTimeStyle.date)}';

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
                              fontWeight: FontWeight.w500,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            rangeLabel,
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
                                  fontWeight: FontWeight.w500,
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
                                    fontWeight: FontWeight.w500,
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
                            _legendItem(
                              context,
                              colors.accentAmber.withValues(alpha: 0.12),
                              colors.accentAmber,
                              language.translate('tasks_source_personal'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final task = tasks[index - 2];
                  final palette = _paletteForStatus(context, task.status);
                  final assignee = task.isPersonal
                      ? language.translate('tasks_source_personal')
                      : language.translateMessage(
                          task.assigneeName ??
                              language.translate('tasks_unassigned'),
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
                                  fontWeight: FontWeight.w500,
                                ),
                                dueDateLabel: _formatLocalizedCompactDate(
                                  language,
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
