part of 'tasks_screen.dart';

/// Unified Task Card adhering to Grounded Enterprise Design System.
///
/// Handles personal to-dos, assigned team tasks (with acceptance / review action bar),
/// and standard corporate tasks with identical visual hierarchy, padding, and typography.
class UnifiedTaskCard extends StatelessWidget {
  const UnifiedTaskCard({
    super.key,
    required this.task,
    this.isPersonal = false,
    this.isAssignee = false,
    this.isReviewer = false,
    this.isPending = false,
    this.canManage = true,
    this.onTap,
    this.onStatusChanged,
    this.onAccept,
    this.onSubmit,
    this.onApprove,
    this.onReject,
    this.onDelete,
  });

  final Task task;
  final bool isPersonal;
  final bool isAssignee;
  final bool isReviewer;
  final bool isPending;
  final bool canManage;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onStatusChanged;
  final VoidCallback? onAccept;
  final VoidCallback? onSubmit;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    final isDone = task.status == TaskStatus.done;
    final isSubmitted = task.status == TaskStatus.review;
    final isOverdue = !isDone && task.dueDate.isBefore(DateTime.now());

    // Priority color mapping
    Color priorityBg = colors.surfaceNested;
    Color priorityText = colors.textSecondary;
    switch (task.priority) {
      case TaskPriority.urgent:
        priorityBg = colors.accentRed.withValues(alpha: 0.12);
        priorityText = colors.accentRed;
        break;
      case TaskPriority.high:
        priorityBg = colors.accentAmber.withValues(alpha: 0.12);
        priorityText = colors.accentAmber;
        break;
      case TaskPriority.medium:
        priorityBg = colors.brand.withValues(alpha: 0.10);
        priorityText = colors.brand;
        break;
      case TaskPriority.low:
        priorityBg = colors.accentGreen.withValues(alpha: 0.12);
        priorityText = colors.accentGreen;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 10, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left interactive checkbox / state indicator
                    if (isSubmitted && !isPersonal)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                        child: Icon(
                          TablerIcons.clock_hour_4,
                          size: 22,
                          color: colors.accentAmber,
                        ),
                      )
                    else
                      AnimatedCheckbox(
                        value: isDone,
                        isPending: isPending,
                        isEnabled: canManage,
                        semanticLabel: task.title,
                        pendingSemanticLabel: context.translate(
                          'common_loading',
                        ),
                        onChanged: (val) => onStatusChanged?.call(val),
                      ),

                    // Main Content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title + Priority / Status Badge
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    task.title,
                                    style: textStyles.bodySans.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14.5,
                                      decoration: isDone
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: isDone
                                          ? colors.textSecondary
                                          : colors.textPrimary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (isDone)
                                  _buildBadge(
                                    text: language.translate(
                                      'tasks_status_done',
                                    ),
                                    bgColor: colors.accentGreen.withValues(
                                      alpha: 0.12,
                                    ),
                                    textColor: colors.accentGreen,
                                  )
                                else
                                  _buildBadge(
                                    text: language.translate(
                                      task.priority.localizationKey,
                                    ),
                                    bgColor: priorityBg,
                                    textColor: priorityText,
                                  ),
                              ],
                            ),

                            // Optional Description
                            if (task.description.trim().isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                task.description.trim(),
                                style: textStyles.captionSans.copyWith(
                                  color: colors.textSecondary,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],

                            const SizedBox(height: 8),

                            // Metadata Chips Row
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // Project Chip
                                if (task.projectName != null &&
                                    task.projectName!.trim().isNotEmpty)
                                  _buildMetaChip(
                                    context,
                                    icon: TablerIcons.folder,
                                    label: task.projectName!,
                                    textColor: colors.brand,
                                    bgColor: colors.brand.withValues(
                                      alpha: 0.08,
                                    ),
                                  ),

                                // Assignee / Author Chip
                                if (task.assigneeName != null &&
                                    task.assigneeName!.trim().isNotEmpty)
                                  _buildMetaChip(
                                    context,
                                    icon: TablerIcons.user,
                                    label: language.translateMessage(
                                      task.assigneeName!,
                                    ),
                                    textColor: colors.textSecondary,
                                  )
                                else if (isPersonal)
                                  _buildMetaChip(
                                    context,
                                    icon: TablerIcons.lock,
                                    label: language.translate(
                                      'tasks_my_personal_chip',
                                    ),
                                    textColor: colors.textSecondary,
                                  ),

                                // Author info if assigned to me
                                if (isAssignee && task.createdBy != null)
                                  _buildMetaChip(
                                    context,
                                    icon: TablerIcons.crown,
                                    label:
                                        '${language.translate('tasks_created_by')}: #${task.createdBy}',
                                    textColor: colors.textSecondary,
                                  ),

                                // Due Date Chip
                                _buildMetaChip(
                                  context,
                                  icon: TablerIcons.calendar,
                                  label: _formatLocalizedCompactDate(
                                    language,
                                    task.dueDate,
                                  ),
                                  textColor: isOverdue
                                      ? colors.accentRed
                                      : colors.textTooltip,
                                  bgColor: isOverdue
                                      ? colors.accentRed.withValues(alpha: 0.08)
                                      : null,
                                  isBold: isOverdue,
                                ),

                                // Acceptance status for assigned tasks
                                if (!isPersonal && isAssignee) ...[
                                  if (task.acknowledgedAt != null)
                                    _buildMetaChip(
                                      context,
                                      icon: TablerIcons.check,
                                      label: language.translate(
                                        'tasks_badge_accepted',
                                      ),
                                      textColor: colors.accentGreen,
                                      bgColor: colors.accentGreen.withValues(
                                        alpha: 0.08,
                                      ),
                                    )
                                  else if (!isDone)
                                    _buildMetaChip(
                                      context,
                                      icon: TablerIcons.alert_circle,
                                      label: language.translate(
                                        'tasks_badge_pending_acceptance',
                                      ),
                                      textColor: colors.accentAmber,
                                      bgColor: colors.accentAmber.withValues(
                                        alpha: 0.08,
                                      ),
                                    ),
                                ],
                              ],
                            ),

                            // Reject reason alert (if returned for rework)
                            if (task.rejectReason != null &&
                                task.rejectReason!.trim().isNotEmpty &&
                                !isDone) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.accentRed.withValues(
                                    alpha: 0.06,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: colors.accentRed.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      TablerIcons.alert_triangle,
                                      size: 14,
                                      color: colors.accentRed,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${language.translate('tasks_reject_reason_prefix')}: ${task.rejectReason}',
                                        style: textStyles.captionSans.copyWith(
                                          color: colors.accentRed,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Interactive Action Bar (Acceptance / Submission / Review workflow)
                            if (_hasActionButtons) ...[
                              const SizedBox(height: 10),
                              _buildActionBar(context),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _hasActionButtons {
    if (isPersonal) return false;
    final isDone = task.status == TaskStatus.done;
    if (isDone) return false;

    // 1. Assignee needs to accept
    if (isAssignee && task.acknowledgedAt == null) return true;
    // 2. Assignee accepted and can submit for review
    if (isAssignee &&
        task.acknowledgedAt != null &&
        (task.status == TaskStatus.todo ||
            task.status == TaskStatus.inProgress)) {
      return true;
    }
    // 3. Reviewer evaluating task under review
    if (isReviewer && task.status == TaskStatus.review) return true;

    return false;
  }

  Widget _buildActionBar(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();

    // 1. Accept receipt button
    if (isAssignee && task.acknowledgedAt == null) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 36,
              child: ElevatedButton.icon(
                onPressed: onAccept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(TablerIcons.check, size: 16),
                label: Text(
                  language.translate('tasks_action_accept_receipt'),
                  style: textStyles.captionSans.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // 2. Submit for review button
    if (isAssignee &&
        task.acknowledgedAt != null &&
        (task.status == TaskStatus.todo ||
            task.status == TaskStatus.inProgress)) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 36,
              child: OutlinedButton.icon(
                onPressed: onSubmit,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.brand,
                  side: BorderSide(color: colors.brand),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(TablerIcons.send, size: 16),
                label: Text(
                  language.translate('tasks_action_submit_review'),
                  style: textStyles.captionSans.copyWith(
                    color: colors.brand,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // 3. Reviewer approve / reject buttons
    if (isReviewer && task.status == TaskStatus.review) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 36,
              child: ElevatedButton.icon(
                onPressed: onApprove,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accentGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(TablerIcons.circle_check, size: 16),
                label: Text(
                  language.translate('tasks_action_approve'),
                  style: textStyles.captionSans.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 36,
              child: OutlinedButton.icon(
                onPressed: onReject,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.accentRed,
                  side: BorderSide(color: colors.accentRed),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(TablerIcons.arrow_back_up, size: 16),
                label: Text(
                  language.translate('tasks_action_rework'),
                  style: textStyles.captionSans.copyWith(
                    color: colors.accentRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildMetaChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color textColor,
    Color? bgColor,
    bool isBold = false,
  }) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor ?? colors.surfaceNested,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: textStyles.captionSans.copyWith(
              color: textColor,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
              fontSize: 11.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required String text,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
