part of 'tasks_screen.dart';

extension _TasksAnalysisBuilders on _TasksViewMixin {
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
      if (isLoading || error == null) {
        return const TasksOverviewShimmer();
      }
      return RefreshIndicator(
        onRefresh: () => _refreshTasks(context),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 320,
              child: Center(
                child: Column(
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Row(
            children: [
              Icon(
                TablerIcons.alert_triangle,
                color: colors.accentRed,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                language.translate('tasks_analysis_overload_title'),
                style: textStyles.captionSans.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (overloaded.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Center(
                child: Text(
                  language.translate('tasks_analysis_no_overload'),
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
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
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
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
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            language.translateMessage(ov.assigneeName),
                            style: textStyles.bodySans.copyWith(
                              fontWeight: FontWeight.w500,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colors.accentRed.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              language.translate(
                                'tasks_analysis_active_count',
                                params: {'count': ov.activeCount},
                              ),
                              style: textStyles.captionSans.copyWith(
                                color: colors.accentRed,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (ov.overdueCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: colors.accentAmber.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                language.translate(
                                  'tasks_analysis_overdue_count',
                                  params: {'count': ov.overdueCount},
                                ),
                                style: textStyles.captionSans.copyWith(
                                  color: colors.accentAmber,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
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

          const SizedBox(height: 20),

          Row(
            children: [
              Icon(TablerIcons.git_branch, color: colors.brand, size: 16),
              const SizedBox(width: 8),
              Text(
                language.translate('tasks_analysis_critical_path_title'),
                style: textStyles.captionSans.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (critical.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Center(
                child: Text(
                  language.translate('tasks_analysis_no_critical_path'),
                  style: textStyles.captionSans.copyWith(
                    color: colors.textSecondary,
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
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
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
                                fontSize: 13.5,
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
                                  color: colors.textSecondary,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusLabel,
                              style: textStyles.captionSans.copyWith(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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
                                fontSize: 11,
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
