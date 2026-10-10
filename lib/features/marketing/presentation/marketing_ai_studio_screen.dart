import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_number_format.dart';
import '../../../core/theme/ledger_buttons.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';
import '../bloc/marketing_bloc.dart';
import '../bloc/marketing_event.dart';
import '../bloc/marketing_state.dart';
import '../domain/marketing_ai_models.dart';

/// Полноценный экран AI-Студии маркетинга (Grounded Enterprise Design System).
class MarketingAiStudioScreen extends StatefulWidget {
  const MarketingAiStudioScreen({super.key});

  @override
  State<MarketingAiStudioScreen> createState() =>
      _MarketingAiStudioScreenState();
}

class _MarketingAiStudioScreenState extends State<MarketingAiStudioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bloc = context.read<MarketingBloc>();
      final lang = context.read<LanguageCubit>().state.languageCode;
      bloc.add(LoadAiStudioDataRequested(lang: lang));
    });
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
    final locale = context.watch<LanguageCubit>();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          locale.translate('marketing_ai_studio_title'),
          style: textStyles.h2Sans.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        leading: const BackButton(),
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(bottom: BorderSide(color: colors.border)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: colors.brand,
              unselectedLabelColor: colors.textSecondary,
              indicatorColor: colors.brand,
              indicatorWeight: 2.5,
              labelStyle: textStyles.bodySans.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              unselectedLabelStyle: textStyles.bodySans.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              tabs: [
                Tab(text: locale.translate('marketing_studio_tab_ideas')),
                Tab(text: locale.translate('marketing_studio_tab_production')),
                Tab(text: locale.translate('marketing_studio_tab_roi')),
              ],
            ),
          ),
        ),
      ),
      body: BlocConsumer<MarketingBloc, MarketingState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(locale.translateMessage(state.errorMessage!)),
                backgroundColor: colors.accentRed,
              ),
            );
          } else if (state.studioSuccessMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(locale.translate(state.studioSuccessMessage!)),
                backgroundColor: colors.accentGreen,
              ),
            );
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              if (state.videoQuota != null)
                _buildQuotaBanner(context, state.videoQuota!)
              else if (state.isStudioLoading)
                const MarketingStudioQuotaShimmer(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildIdeasAndConceptsTab(context, state),
                    _buildProductionTab(context, state),
                    _buildRoiReportsTab(context, state),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuotaBanner(BuildContext context, MarketingVideoQuota quota) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colors.brand.withValues(alpha: 0.06),
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Icon(TablerIcons.video, size: 16, color: colors.brand),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              locale.translate(
                'marketing_video_quota_info',
                params: {
                  'used': '${quota.videoUsed}',
                  'limit': '${quota.videoLimit}',
                  'left': '${quota.videoLeft}',
                },
              ),
              style: textStyles.captionSans.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 12.5,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: quota.videoLeft > 0
                  ? colors.accentGreen.withValues(alpha: 0.15)
                  : colors.accentRed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${quota.videoLeft} left',
              style: textStyles.captionSans.copyWith(
                color: quota.videoLeft > 0
                    ? colors.accentGreen
                    : colors.accentRed,
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: IDEAS & CONCEPTS ---
  Widget _buildIdeasAndConceptsTab(BuildContext context, MarketingState state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();

    return RefreshIndicator(
      onRefresh: () async {
        final lang = locale.state.languageCode;
        context.read<MarketingBloc>().add(
          LoadAiStudioDataRequested(lang: lang, forceRefresh: true),
        );
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // Action button: Generate 3 Ideas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                locale.translate('marketing_ideas_header'),
                style: textStyles.h2Sans.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              OutlinedButton.icon(
                onPressed: state.isStudioLoading
                    ? null
                    : () {
                        final lang = locale.state.languageCode;
                        context.read<MarketingBloc>().add(
                          GenerateAiStudioIdeasRequested(lang: lang),
                        );
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.brand,
                  side: BorderSide(color: colors.brand),
                ),
                icon: const Icon(TablerIcons.sparkles),
                label: Text(locale.translate('marketing_refresh_ideas_btn')),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (state.isStudioLoading && state.aiIdeas.isEmpty)
            const MarketingAiStudioShimmer(wrapList: false)
          else if (state.aiIdeas.isEmpty && !state.isStudioLoading)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Center(
                child: Text(
                  locale.translate('marketing_no_ideas_placeholder'),
                  textAlign: TextAlign.center,
                  style: textStyles.bodySans.copyWith(
                    color: colors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            ...state.aiIdeas.map((idea) => _buildIdeaCard(context, idea)),

          const SizedBox(height: 20),

          // Active Campaign & Concepts Section
          if (state.currentAiCampaign != null) ...[
            Text(
              locale.translate('marketing_active_campaign_title'),
              style: textStyles.h2Sans.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            _buildCampaignSummaryCard(context, state.currentAiCampaign!),
            const SizedBox(height: 14),

            if (state.currentAiCampaign!.concepts.isEmpty)
              Center(
                child: ElevatedButton.icon(
                  onPressed: state.isStudioLoading
                      ? null
                      : () {
                          context.read<MarketingBloc>().add(
                            GenerateAiStudioConceptsRequested(
                              state.currentAiCampaign!.id,
                            ),
                          );
                        },
                  icon: const Icon(TablerIcons.bulb),
                  label: Text(
                    locale.translate('marketing_generate_concepts_btn'),
                  ),
                ),
              )
            else
              ...state.currentAiCampaign!.concepts.map(
                (concept) => _buildConceptCard(
                  context,
                  concept,
                  state.currentAiCampaign!.id,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildIdeaCard(BuildContext context, MarketingIdea idea) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();

    Color tagBg = colors.surfaceNested;
    Color tagText = colors.textSecondary;
    if (idea.source == 'season') {
      tagBg = colors.accentGreen.withValues(alpha: 0.12);
      tagText = colors.accentGreen;
    } else if (idea.source == 'sales_drop') {
      tagBg = colors.accentAmber.withValues(alpha: 0.12);
      tagText = colors.accentAmber;
    } else if (idea.source == 'stale_stock') {
      tagBg = colors.brand.withValues(alpha: 0.10);
      tagText = colors.brand;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tagBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  idea.tag.isNotEmpty ? idea.tag : idea.source,
                  style: textStyles.captionSans.copyWith(
                    color: tagText,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => _openCreateCampaignFromIdea(context, idea),
                child: Text(locale.translate('marketing_use_idea_btn')),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            idea.title,
            style: textStyles.bodySans.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            idea.reason,
            style: textStyles.captionSans.copyWith(
              color: colors.textSecondary,
              fontSize: 12.5,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignSummaryCard(
    BuildContext context,
    MarketingCampaignAi campaign,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;

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
          Text(
            campaign.name,
            style: textStyles.bodySans.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: colors.textPrimary,
            ),
          ),
          if (campaign.product != null && campaign.product!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Товар: ${campaign.product}',
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
          if (campaign.briefText != null && campaign.briefText!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              campaign.briefText!,
              style: textStyles.captionSans.copyWith(
                color: colors.textPrimary,
                fontSize: 12.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConceptCard(
    BuildContext context,
    MarketingConcept concept,
    String campaignId,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: concept.isApproved ? colors.accentGreen : colors.border,
          width: concept.isApproved ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.brand.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Вариант ${concept.variant} (Раунд ${concept.roundNo})',
                  style: textStyles.captionSans.copyWith(
                    color: colors.brand,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
              ),
              const Spacer(),
              if (concept.isApproved)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.accentGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        TablerIcons.check,
                        size: 13,
                        color: colors.accentGreen,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Утверждено',
                        style: textStyles.captionSans.copyWith(
                          color: colors.accentGreen,
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            concept.title,
            style: textStyles.bodySans.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 14.5,
              color: colors.textPrimary,
            ),
          ),
          if (concept.storyline != null) ...[
            const SizedBox(height: 6),
            Text(
              concept.storyline!,
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
                fontSize: 12.5,
                height: 1.3,
              ),
            ),
          ],
          if (concept.theses != null) ...[
            const SizedBox(height: 6),
            Text(
              'Тезисы: ${concept.theses}',
              style: textStyles.captionSans.copyWith(
                color: colors.textPrimary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (concept.cta != null) ...[
            const SizedBox(height: 6),
            Text(
              'CTA: ${concept.cta}',
              style: textStyles.captionSans.copyWith(
                color: colors.brand,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => _openReviseModal(context, campaignId, concept),
                child: Text(locale.translate('marketing_concept_revise')),
              ),
              const SizedBox(width: 8),
              if (!concept.isApproved)
                ElevatedButton(
                  onPressed: () {
                    context.read<MarketingBloc>().add(
                      ApproveAiStudioConceptRequested(concept.id),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accentGreen,
                    foregroundColor: colors.surface,
                  ),
                  child: Text(locale.translate('marketing_concept_approve')),
                )
              else
                ElevatedButton.icon(
                  onPressed: () {
                    context.read<MarketingBloc>().add(
                      GenerateAiStudioScriptRequested(concept.id),
                    );
                    _tabController.animateTo(1);
                  },
                  icon: const Icon(TablerIcons.movie),
                  label: Text(locale.translate('marketing_produce_media_btn')),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // --- TAB 2: PRODUCTION (SCRIPT & VEO VIDEO / IMAGEN) ---
  Widget _buildProductionTab(BuildContext context, MarketingState state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();

    final media = state.currentMedia ?? state.currentScript;

    if (state.isStudioLoading && media == null) {
      return const MarketingAiStudioShimmer(
        tab: MarketingStudioShimmerTab.production,
      );
    }

    if (media == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                TablerIcons.movie_off,
                size: 48,
                color: colors.textSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                locale.translate('marketing_no_media_placeholder'),
                textAlign: TextAlign.center,
                style: textStyles.bodySans.copyWith(
                  color: colors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      children: [
        // Script Card
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
                children: [
                  Icon(TablerIcons.file_text, size: 16, color: colors.brand),
                  const SizedBox(width: 6),
                  Text(
                    'Сценарий ролика (Версия ${media.version})',
                    style: textStyles.bodySans.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: colors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(TablerIcons.copy, size: 16),
                    tooltip: locale.translate('more'),
                    onPressed: () {
                      if (media.script != null) {
                        Clipboard.setData(ClipboardData(text: media.script!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              locale.translate('marketing_script_copied'),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (media.script != null)
                Text(
                  media.script!,
                  style: textStyles.bodySans.copyWith(
                    fontSize: 13,
                    color: colors.textPrimary,
                    height: 1.4,
                  ),
                ),
              if (media.postText != null) ...[
                const SizedBox(height: 12),
                Container(height: 1, color: colors.border),
                const SizedBox(height: 10),
                Text(
                  locale.translate('marketing_post_text_label'),
                  style: textStyles.captionSans.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  media.postText!,
                  style: textStyles.bodySans.copyWith(
                    fontSize: 13,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Media Generation Actions
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
              Text(
                locale.translate('marketing_media_gen_title'),
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: state.isStudioLoading
                          ? null
                          : () {
                              context.read<MarketingBloc>().add(
                                GenerateAiStudioMediaRequested(
                                  mediaId: media.id,
                                  kind: 'photo',
                                ),
                              );
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.brand,
                        side: BorderSide(color: colors.brand),
                      ),
                      icon: const Icon(TablerIcons.photo),
                      label: Text(locale.translate('marketing_imagen_photo')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: state.isStudioLoading
                          ? null
                          : () => _confirmVeoVideoGeneration(context, media.id),
                      icon: const Icon(TablerIcons.video),
                      label: Text(locale.translate('marketing_veo_video')),
                    ),
                  ),
                ],
              ),
              if (media.fileUrl != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.accentGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colors.accentGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        TablerIcons.circle_check,
                        size: 20,
                        color: colors.accentGreen,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          locale.translate(
                            'marketing_media_ready',
                            params: {'version': media.version.toString()},
                          ),
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: colors.accentGreen,
                          ),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => _openRejectModal(context, media.id),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.accentRed,
                          side: BorderSide(color: colors.accentRed),
                        ),
                        child: Text(locale.translate('marketing_reject')),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // --- TAB 3: ROI REPORTS ---
  Widget _buildRoiReportsTab(BuildContext context, MarketingState state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);

    if (state.isStudioLoading && state.publicationStats.isEmpty) {
      return const MarketingAiStudioShimmer(tab: MarketingStudioShimmerTab.roi);
    }

    if (state.publicationStats.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async {
          context.read<MarketingBloc>().add(
            const LoadAiStudioReportRequested(),
          );
        },
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Text(
                locale.translate('marketing_no_roi_stats_placeholder'),
                textAlign: TextAlign.center,
                style: textStyles.bodySans.copyWith(
                  color: colors.textSecondary,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      itemCount: state.publicationStats.length,
      itemBuilder: (context, index) {
        final stat = state.publicationStats[index];
        final roi = stat.roiPercent ?? 0.0;
        final isProfitable = roi > 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
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
                  Text(
                    locale.translate(
                      'marketing_publication_id',
                      params: {'id': stat.publicationId},
                    ),
                    style: textStyles.bodySans.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: colors.textPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isProfitable
                              ? colors.accentGreen.withValues(alpha: 0.12)
                              : colors.accentRed.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'ROI: ${roi.toStringAsFixed(1)}%',
                          style: textStyles.captionSans.copyWith(
                            color: isProfitable
                                ? colors.accentGreen
                                : colors.accentRed,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: locale.translate('marketing_refresh_stats'),
                        visualDensity: VisualDensity.compact,
                        onPressed:
                            state.refreshingPublicationId == stat.publicationId
                            ? null
                            : () => context.read<MarketingBloc>().add(
                                RefreshPublicationStatsRequested(
                                  stat.publicationId,
                                ),
                              ),
                        icon:
                            state.refreshingPublicationId == stat.publicationId
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                TablerIcons.refresh,
                                size: 18,
                                color: colors.brand,
                              ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statItem(
                    context,
                    locale.translate('revenue'),
                    '${oCcy.format(stat.revenue)} TJS',
                  ),
                  _statItem(
                    context,
                    locale.translate('marketing_budget'),
                    '${oCcy.format(stat.spend)} TJS',
                  ),
                  _statItem(
                    context,
                    locale.translate('marketing_leads_purchases'),
                    '${stat.intents} / ${stat.purchases}',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statItem(BuildContext context, String label, String value) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textStyles.captionSans.copyWith(
            color: colors.textSecondary,
            fontSize: 11.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: textStyles.bodySans.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }

  // --- MODALS & DIALOGS ---
  void _openCreateCampaignFromIdea(BuildContext context, MarketingIdea idea) {
    final nameCtrl = TextEditingController(text: idea.title);
    final notesCtrl = TextEditingController(text: idea.reason);
    final daysCtrl = TextEditingController(text: '7');
    final locale = context.read<LanguageCubit>();

    LedgerBottomSheet.show(
      context: context,
      title: locale.translate('marketing_create_campaign_title'),
      builder: (context, setSheetState) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameCtrl,
            decoration: InputDecoration(
              labelText: locale.translate('marketing_campaign_name'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: daysCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: locale.translate('marketing_campaign_duration'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: locale.translate('marketing_campaign_brief_notes'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.read<MarketingBloc>().add(
                  CreateAiStudioCampaignRequested(
                    name: nameCtrl.text.trim(),
                    goalDays: int.tryParse(daysCtrl.text.trim()) ?? 7,
                    briefText: notesCtrl.text.trim(),
                    ideaSource: idea.source,
                  ),
                );
              },
              child: Text(locale.translate('marketing_create_campaign_cta')),
            ),
          ),
        ],
      ),
    );
  }

  void _openReviseModal(
    BuildContext context,
    String campaignId,
    MarketingConcept concept,
  ) {
    final noteCtrl = TextEditingController();
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.read<LanguageCubit>();

    LedgerBottomSheet.show(
      context: context,
      title: locale.translate('marketing_concept_revise_title'),
      builder: (context, setSheetState) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            locale.translate(
              'marketing_concept_revise_prompt',
              params: {'title': concept.title},
            ),
            style: textStyles.captionSans.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: noteCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: locale.translate('marketing_concept_revise_hint'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (noteCtrl.text.trim().isEmpty) return;
                Navigator.of(context).pop();
                context.read<MarketingBloc>().add(
                  ReviseAiStudioConceptRequested(
                    campaignId: campaignId,
                    baseIds: [concept.id],
                    note: noteCtrl.text.trim(),
                  ),
                );
              },
              child: Text(locale.translate('marketing_concept_regenerate')),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmVeoVideoGeneration(BuildContext context, String mediaId) {
    final textStyles = context.textStyles;
    final locale = context.read<LanguageCubit>();

    showDialog(
      context: context,
      builder: (ctx) => Theme(
        data: LedgerButtons.modalOverlay(ctx),
        child: AlertDialog(
          title: Text(
            locale.translate('marketing_veo_dialog_title'),
            style: textStyles.h2Sans.copyWith(fontSize: 16),
          ),
          content: Text(
            locale.translate('marketing_veo_dialog_desc'),
            style: textStyles.bodySans.copyWith(fontSize: 13.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(locale.translate('cancel')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.read<MarketingBloc>().add(
                  GenerateAiStudioMediaRequested(
                    mediaId: mediaId,
                    kind: 'video',
                    confirm: true,
                  ),
                );
              },
              child: Text(locale.translate('save_to_ledger')),
            ),
          ],
        ),
      ),
    );
  }

  void _openRejectModal(BuildContext context, String mediaId) {
    final reasonCtrl = TextEditingController();
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.read<LanguageCubit>();

    LedgerBottomSheet.show(
      context: context,
      title: locale.translate('marketing_reject_modal_title'),
      builder: (context, setSheetState) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            locale.translate('marketing_reject_modal_subtitle'),
            style: textStyles.captionSans.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: reasonCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: locale.translate('marketing_reject_modal_hint'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (reasonCtrl.text.trim().isEmpty) return;
                Navigator.of(context).pop();
                context.read<MarketingBloc>().add(
                  RejectAiStudioMediaRequested(
                    mediaId: mediaId,
                    reason: reasonCtrl.text.trim(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accentRed,
                foregroundColor: colors.onBrand,
              ),
              child: Text(locale.translate('marketing_reject_confirm')),
            ),
          ),
        ],
      ),
    );
  }
}
