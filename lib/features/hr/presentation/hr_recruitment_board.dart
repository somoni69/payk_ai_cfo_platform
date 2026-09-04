import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/ledger_buttons.dart';
import '../../../core/theme/ledger_layout.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../bloc/hr_bloc.dart';
import '../bloc/hr_event.dart';
import '../domain/hr_models.dart';

/// Стадии воронки найма — как на вебе (HR-07).
const kHrCandidateStages = <String>[
  'new',
  'screening',
  'interview',
  'test_task',
  'final',
  'offer',
  'hired',
  'rejected',
];

/// Линейный поток без «Отказа».
const kHrCandidateFlow = <String>[
  'new',
  'screening',
  'interview',
  'test_task',
  'final',
  'offer',
  'hired',
];

String? _neighbourStage(String stage, int dir) {
  final idx = kHrCandidateFlow.indexOf(stage);
  if (idx < 0) return dir == 1 ? 'new' : null;
  final next = idx + dir;
  if (next < 0 || next >= kHrCandidateFlow.length) return null;
  return kHrCandidateFlow[next];
}

({Color bg, Color fg}) _stageTone(LedgerColors colors, String stage) {
  return switch (stage) {
    'hired' => (
      bg: colors.accentGreen.withValues(alpha: 0.12),
      fg: colors.accentGreen,
    ),
    'rejected' => (
      bg: colors.accentRed.withValues(alpha: 0.12),
      fg: colors.accentRed,
    ),
    'offer' => (bg: colors.brand.withValues(alpha: 0.12), fg: colors.brand),
    _ => (bg: colors.surfaceNested, fg: colors.textPrimary),
  };
}

/// Горизонтальная доска найма: колонки по этапам, карточки внутри.
class HrRecruitmentBoard extends StatelessWidget {
  const HrRecruitmentBoard({
    super.key,
    required this.candidates,
    required this.canWrite,
    required this.onRefresh,
  });

  final List<Candidate> candidates;
  final bool canWrite;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = context.layout;
        final colWidth = layout.funnelColumnWidth(constraints.maxWidth);
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              SizedBox(
                height: constraints.maxHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    layout.funnelBottomPadding,
                  ),
                  itemCount: kHrCandidateStages.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final stage = kHrCandidateStages[index];
                    final items = candidates
                        .where((c) => c.stage == stage)
                        .toList();
                    return SizedBox(
                      width: colWidth,
                      child: _StageColumn(
                        stage: stage,
                        candidates: items,
                        canWrite: canWrite,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StageColumn extends StatelessWidget {
  const _StageColumn({
    required this.stage,
    required this.candidates,
    required this.canWrite,
  });

  final String stage;
  final List<Candidate> candidates;
  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final tone = _stageTone(colors, stage);

    return DragTarget<Candidate>(
      onWillAcceptWithDetails: (details) =>
          canWrite && details.data.stage != stage,
      onAcceptWithDetails: (details) {
        context.read<HrBloc>().add(
          UpdateCandidateStageRequested(id: details.data.id, stage: stage),
        );
      },
      builder: (context, hovering, rejected) {
        final highlighting = hovering.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          decoration: BoxDecoration(
            color: highlighting
                ? colors.brand.withValues(alpha: 0.06)
                : colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: highlighting ? colors.brand : colors.border,
              width: highlighting ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      language.translate('hr_candidate_stage_$stage'),
                      style: textStyles.bodySans.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: tone.bg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${candidates.length}',
                      style: textStyles.captionSans.copyWith(
                        color: tone.fg,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              if (canWrite) ...[
                const SizedBox(height: 2),
                Text(
                  language.translate('hr_recruitment_drag_hint'),
                  style: textStyles.captionSans.copyWith(
                    color: colors.textTooltip,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Expanded(
                child: candidates.isEmpty
                    ? Center(
                        child: Text(
                          language.translate('hr_recruitment_empty_stage'),
                          style: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: candidates.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          return _CandidateCard(
                            candidate: candidates[i],
                            canWrite: canWrite,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.candidate, required this.canWrite});

  final Candidate candidate;
  final bool canWrite;

  void _move(BuildContext context, int dir) {
    final next = _neighbourStage(candidate.stage, dir);
    if (next == null) return;
    context.read<HrBloc>().add(
      UpdateCandidateStageRequested(id: candidate.id, stage: next),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final language = context.read<LanguageCubit>();
    final colors = context.colors;
    final textStyles = context.textStyles;
    final ok = await LedgerBottomSheet.show<bool>(
      context: context,
      title: language.translate('hr_recruitment_delete_title'),
      builder: (ctx, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              language.translate('hr_recruitment_delete_msg'),
              style: textStyles.bodySans.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: kLedgerModalButtonHeight,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accentRed,
                  foregroundColor: colors.surface,
                ),
                child: Text(language.translate('hr_recruitment_delete')),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: kLedgerModalButtonHeight,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(language.translate('common_cancel')),
              ),
            ),
          ],
        );
      },
    );
    if (ok == true && context.mounted) {
      context.read<HrBloc>().add(DeleteCandidateRequested(candidate.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final language = context.watch<LanguageCubit>();
    final prev = _neighbourStage(candidate.stage, -1);
    final next = _neighbourStage(candidate.stage, 1);

    final card = Material(
      color: colors.surfaceNested,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidate.fullName,
                        style: textStyles.bodySans.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        candidate.vacancy,
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (canWrite)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: language.translate('hr_recruitment_delete'),
                    onPressed: () => _confirmDelete(context),
                    icon: Icon(
                      TablerIcons.trash,
                      size: 16,
                      color: colors.accentRed,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              formatLocalizedDateTime(
                context,
                candidate.createdAt,
                style: LocalizedDateTimeStyle.date,
              ),
              style: textStyles.captionSans.copyWith(
                color: colors.textTooltip,
                fontSize: 11,
              ),
            ),
            if (candidate.phone != null && candidate.phone!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                candidate.phone!,
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                  fontSize: 11.5,
                ),
              ),
            ],
            if (canWrite) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: language.translate('hr_recruitment_prev'),
                    onPressed: prev == null ? null : () => _move(context, -1),
                    icon: Icon(
                      TablerIcons.chevron_left,
                      size: 18,
                      color: prev == null
                          ? colors.textTooltip
                          : colors.textPrimary,
                    ),
                  ),
                  if (candidate.stage != 'rejected')
                    TextButton(
                      onPressed: () {
                        context.read<HrBloc>().add(
                          UpdateCandidateStageRequested(
                            id: candidate.id,
                            stage: 'rejected',
                          ),
                        );
                      },
                      child: Text(
                        language.translate('hr_recruitment_reject'),
                        style: textStyles.captionSans.copyWith(
                          color: colors.accentRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: language.translate('hr_recruitment_next'),
                    onPressed: next == null ? null : () => _move(context, 1),
                    icon: Icon(
                      TablerIcons.chevron_right,
                      size: 18,
                      color: next == null
                          ? colors.textTooltip
                          : colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );

    if (!canWrite) return card;

    return LongPressDraggable<Candidate>(
      data: candidate,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 240, child: Opacity(opacity: 0.92, child: card)),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }
}
