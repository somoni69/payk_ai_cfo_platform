import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/localization/locale_number_format.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/auth/bloc/auth_state.dart';
import '../../../features/auth/domain/app_access.dart';
import '../../../features/marketing/bloc/marketing_bloc.dart';
import '../../../features/marketing/bloc/marketing_event.dart';
import '../../../features/marketing/bloc/marketing_state.dart';
import '../../../features/marketing/domain/marketing_models.dart';
import '../../../features/marketing/domain/marketing_repository.dart';
import 'marketing_ai_studio_screen.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../../../presentation/widgets/expansible_widget.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';

enum MarketingSection { aiStudio, aiWriter, campaigns, posts, brandGuide }

String _marketingSectionTitle(
  LanguageCubit language,
  MarketingSection section,
) {
  return language.translate(switch (section) {
    MarketingSection.aiStudio => 'marketing_tab_ai_studio',
    MarketingSection.aiWriter => 'marketing_tab_ai_writer',
    MarketingSection.campaigns => 'marketing_tab_campaigns',
    MarketingSection.posts => 'marketing_tab_posts',
    MarketingSection.brandGuide => 'marketing_tab_brand_guide',
  });
}

void _openMarketingSection(BuildContext context, MarketingSection section) {
  final bloc = context.read<MarketingBloc>();
  if (section == MarketingSection.aiStudio) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: const MarketingAiStudioScreen(),
        ),
      ),
    );
    return;
  }
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: MarketingSectionScreen(section: section),
      ),
    ),
  );
}

class MarketingScreen extends StatelessWidget {
  const MarketingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageCubit>();
    return BlocProvider<MarketingBloc>(
      create: (context) =>
          MarketingBloc(context.read<MarketingRepository>())
            ..add(const LoadMarketingData()),
      child: const MarketingView(),
    );
  }
}

class MarketingView extends StatefulWidget {
  const MarketingView({super.key});

  @override
  State<MarketingView> createState() => _MarketingViewState();
}

class _MarketingViewState extends State<MarketingView> {
  bool _canManageMarketing(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated &&
        authState.role.canManage(AppCapability.marketing);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.watch<LanguageCubit>();
    final canManage = _canManageMarketing(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          localeCubit.translate('marketing_title'),
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
      body: BlocListener<MarketingBloc, MarketingState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  localeCubit.translateMessage(state.errorMessage!),
                ),
                backgroundColor: colors.accentRed,
              ),
            );
          }
        },
        child: BlocBuilder<MarketingBloc, MarketingState>(
          builder: (context, state) {
            if ((state.isCampaignsLoading || state.isPostsLoading) &&
                state.campaigns.isEmpty &&
                state.posts.isEmpty) {
              return const MarketingOverviewShimmer();
            }
            return _buildMarketingOverviewHub(context, state, canManage);
          },
        ),
      ),
    );
  }

  Widget _buildMarketingOverviewHub(
    BuildContext context,
    MarketingState state,
    bool canManage,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();
    final oCcy = localizedDecimalFormat(context);

    final totalBudget = state.campaigns.fold<double>(
      0.0,
      (s, c) => s + c.budget,
    );
    final activeCampaigns = state.campaigns
        .where((c) => c.endedAt == null || c.endedAt!.isAfter(DateTime.now()))
        .length;
    final activeBudget = state.campaigns
        .where((c) => c.endedAt == null || c.endedAt!.isAfter(DateTime.now()))
        .fold<double>(0.0, (s, c) => s + c.budget);

    return RefreshIndicator(
      onRefresh: () async {
        context.read<MarketingBloc>().add(
          const LoadMarketingData(forceRefresh: true),
        );
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // 1. Hero Card: Marketing Budget & Active Campaigns
          Container(
            padding: const EdgeInsets.all(18),
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
                    Expanded(
                      child: Text(
                        locale.translate('marketing_hero_budget'),
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w500,
                          fontSize: 13.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colors.brand.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            TablerIcons.sparkles,
                            size: 13,
                            color: colors.brand,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            locale.translate(
                              'marketing_campaigns_count',
                              params: {'count': '${state.campaigns.length}'},
                            ),
                            style: textStyles.captionSans.copyWith(
                              color: colors.brand,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${oCcy.format(totalBudget)} TJS',
                  style: textStyles.h2Sans.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: colors.border),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      TablerIcons.speakerphone,
                      size: 16,
                      color: colors.brand,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$activeCampaigns ${locale.translate('hr_status_active').toLowerCase()}',
                      style: textStyles.captionSans.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• ${state.posts.length} ${locale.translate('marketing_tab_posts').toLowerCase()}',
                      style: textStyles.captionSans.copyWith(
                        color: colors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 1.5. AI Marketing Studio Banner
          InkWell(
            onTap: () =>
                _openMarketingSection(context, MarketingSection.aiStudio),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.brand.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.brand.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      TablerIcons.video,
                      color: colors.brand,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              locale.translate('marketing_tab_ai_studio'),
                              style: textStyles.bodySans.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.brand,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'VEO 2',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          locale.translate('marketing_ai_studio_subtitle'),
                          style: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    TablerIcons.chevron_right,
                    size: 18,
                    color: colors.brand,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2. Actionable Attention Card
          InkWell(
            onTap: () => _openMarketingSection(
              context,
              activeCampaigns > 0
                  ? MarketingSection.campaigns
                  : MarketingSection.aiWriter,
            ),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: activeCampaigns > 0
                      ? colors.brand.withValues(alpha: 0.4)
                      : colors.accentGreen.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: activeCampaigns > 0
                          ? colors.brand.withValues(alpha: 0.08)
                          : colors.accentGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      activeCampaigns > 0
                          ? TablerIcons.chart_pie
                          : TablerIcons.circle_check,
                      color: activeCampaigns > 0
                          ? colors.brand
                          : colors.accentGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locale.translate('marketing_attention_title'),
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          activeCampaigns > 0
                              ? locale.translate(
                                  'marketing_attention_active',
                                  params: {
                                    'count': '$activeCampaigns',
                                    'budget': oCcy.format(activeBudget),
                                  },
                                )
                              : locale.translate('marketing_attention_idle'),
                          style: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                            fontSize: 13,
                          ),
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
          ),
          const SizedBox(height: 12),

          // 3. Quick Action Buttons Row (if canManage)
          if (canManage) ...[
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () => _openMarketingSection(
                        context,
                        MarketingSection.aiWriter,
                      ),
                      icon: const Icon(TablerIcons.sparkles, size: 17),
                      label: Text(
                        locale.translate('marketing_action_writer'),
                        style: textStyles.captionSans.copyWith(
                          color: colors.surface,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.brand,
                        foregroundColor: colors.surface,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () => _showCreateCampaignDialog(context),
                      icon: Icon(
                        TablerIcons.plus,
                        size: 17,
                        color: colors.textPrimary,
                      ),
                      label: Text(
                        locale.translate('marketing_action_campaign'),
                        style: textStyles.captionSans.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textPrimary,
                        backgroundColor: colors.surface,
                        side: BorderSide(color: colors.border),
                        minimumSize: const Size.fromHeight(44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // 4. Main 2x2 Navigation Grid
          Row(
            children: [
              Expanded(
                child: _buildHubCard(
                  context,
                  title: locale.translate('marketing_tab_ai_writer'),
                  subtitle: 'ИИ генерация текстов',
                  icon: TablerIcons.sparkles,
                  onTap: () =>
                      _openMarketingSection(context, MarketingSection.aiWriter),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHubCard(
                  context,
                  title: locale.translate('marketing_tab_campaigns'),
                  subtitle: locale.translate(
                    'marketing_campaigns_count',
                    params: {'count': '${state.campaigns.length}'},
                  ),
                  icon: TablerIcons.speakerphone,
                  onTap: () => _openMarketingSection(
                    context,
                    MarketingSection.campaigns,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildHubCard(
                  context,
                  title: locale.translate('marketing_tab_posts'),
                  subtitle: locale.translate(
                    'marketing_posts_count',
                    params: {'count': '${state.posts.length}'},
                  ),
                  icon: TablerIcons.news,
                  onTap: () =>
                      _openMarketingSection(context, MarketingSection.posts),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHubCard(
                  context,
                  title: locale.translate('marketing_tab_brand_guide'),
                  subtitle: 'Tone of Voice & правила',
                  icon: TablerIcons.palette,
                  onTap: () => _openMarketingSection(
                    context,
                    MarketingSection.brandGuide,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 5. Recent Campaigns Feed
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                locale.translate('marketing_recent_campaigns'),
                style: textStyles.h2Sans.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () =>
                    _openMarketingSection(context, MarketingSection.campaigns),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  children: [
                    Text(
                      locale.translate('marketing_all_campaigns'),
                      style: textStyles.captionSans.copyWith(
                        color: colors.brand,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      TablerIcons.chevron_right,
                      size: 14,
                      color: colors.brand,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (state.campaigns.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              alignment: Alignment.center,
              child: Text(
                locale.translate('marketing_no_campaigns'),
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                  fontSize: 13.5,
                ),
              ),
            )
          else
            ...state.campaigns.take(4).map((c) {
              final isActive =
                  c.endedAt == null || c.endedAt!.isAfter(DateTime.now());
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: colors.surfaceNested,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          TablerIcons.speakerphone,
                          color: colors.brand,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              style: textStyles.bodySans.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 14.5,
                                color: colors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${locale.translate('marketing_channel')}: ${c.channel?.toUpperCase() ?? locale.translate('marketing_channel_none')}',
                              style: textStyles.captionSans.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? colors.accentGreen.withValues(alpha: 0.1)
                                  : colors.surfaceNested,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isActive
                                  ? locale.translate('hr_status_active')
                                  : locale.translate('hr_status_inactive'),
                              style: textStyles.captionSans.copyWith(
                                color: isActive
                                    ? colors.accentGreen
                                    : colors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${oCcy.format(c.budget)} TJS',
                            style: textStyles.bodyMono.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: colors.textPrimary,
                            ),
                          ),
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

  Widget _buildHubCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.brand.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 19, color: colors.brand),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                  color: colors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
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
      ),
    );
  }
}

class MarketingSectionScreen extends StatefulWidget {
  final MarketingSection section;

  const MarketingSectionScreen({super.key, required this.section});

  @override
  State<MarketingSectionScreen> createState() => _MarketingSectionScreenState();
}

class _MarketingSectionScreenState extends State<MarketingSectionScreen> {
  final ScrollController _campaignsController = ScrollController();
  final ScrollController _postsController = ScrollController();
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _brandNameController = TextEditingController();
  final TextEditingController _toneController = TextEditingController();
  final TextEditingController _audienceController = TextEditingController();
  final TextEditingController _forbiddenController = TextEditingController();
  final TextEditingController _videoLimitController = TextEditingController();
  bool _brandInitialized = false;
  bool _generatePostTextMode = false;
  final int _visibleCampaigns = 40;
  final int _visiblePosts = 40;

  @override
  void dispose() {
    _campaignsController.dispose();
    _postsController.dispose();
    _promptController.dispose();
    _brandNameController.dispose();
    _toneController.dispose();
    _audienceController.dispose();
    _forbiddenController.dispose();
    _videoLimitController.dispose();
    super.dispose();
  }

  bool _canManageMarketing(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated &&
        authState.role.canManage(AppCapability.marketing);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();
    final canManage = _canManageMarketing(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
        title: Text(
          _marketingSectionTitle(locale, widget.section),
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
      floatingActionButton: canManage
          ? _buildSectionFab(context, locale)
          : null,
      body: switch (widget.section) {
        MarketingSection.aiStudio => const MarketingAiStudioScreen(),
        MarketingSection.aiWriter => _buildAiWriterTab(context),
        MarketingSection.campaigns => _buildCampaignsTab(context),
        MarketingSection.posts => _buildPostsTab(context),
        MarketingSection.brandGuide => _buildBrandGuideTab(context),
      },
    );
  }

  Widget? _buildSectionFab(BuildContext context, LanguageCubit locale) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    if (widget.section == MarketingSection.campaigns) {
      return FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _showCreateCampaignDialog(context),
        backgroundColor: colors.brand,
        foregroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        icon: const Icon(TablerIcons.plus),
        label: Text(
          locale.translate('marketing_new_campaign'),
          style: textStyles.bodySans.copyWith(
            color: colors.surface,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (widget.section == MarketingSection.posts) {
      return FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _showCreatePostDialog(context),
        backgroundColor: colors.brand,
        foregroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        icon: const Icon(TablerIcons.plus),
        label: Text(
          locale.translate('marketing_new_publication'),
          style: textStyles.bodySans.copyWith(
            color: colors.surface,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return null;
  }

  Widget _buildAiWriterTab(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();

    return BlocBuilder<MarketingBloc, MarketingState>(
      builder: (context, state) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              localeCubit.translate('marketing_writer_description'),
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 12),

            // Режим генерации (Идеи / Пост)
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Text(
                      localeCubit.translate('marketing_mode_ad_ideas'),
                    ),
                    labelStyle: textStyles.captionSans.copyWith(
                      color: !_generatePostTextMode
                          ? Colors.white
                          : colors.textPrimary,
                      fontWeight: !_generatePostTextMode
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                    checkmarkColor: Colors.white,
                    selected: !_generatePostTextMode,
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _generatePostTextMode = false;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: Text(
                      localeCubit.translate('marketing_mode_ready_post'),
                    ),
                    labelStyle: textStyles.captionSans.copyWith(
                      color: _generatePostTextMode
                          ? Colors.white
                          : colors.textPrimary,
                      fontWeight: _generatePostTextMode
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                    checkmarkColor: Colors.white,
                    selected: _generatePostTextMode,
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _generatePostTextMode = true;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Ввод промпта
            TextField(
              controller: _promptController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: _generatePostTextMode
                    ? localeCubit.translate('marketing_post_prompt_hint')
                    : localeCubit.translate('marketing_ideas_prompt_hint'),
                fillColor: colors.surface,
                filled: true,
              ),
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: state.isGenerating || !_canManageMarketing(context)
                  ? null
                  : () {
                      final prompt = _promptController.text.trim();
                      if (prompt.isEmpty) return;

                      if (_generatePostTextMode) {
                        context.read<MarketingBloc>().add(
                          GenerateTextRequested(prompt),
                        );
                      } else {
                        context.read<MarketingBloc>().add(
                          GenerateIdeasRequested(prompt),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.brand,
                foregroundColor: colors.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(TablerIcons.plus),
              label: Text(
                localeCubit.translate(
                  state.isGenerating
                      ? 'marketing_ai_thinking'
                      : 'marketing_create_content',
                ),
              ),
            ),
            const SizedBox(height: 24),

            if (state.isGenerating)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: LedgerNamedListShimmer(itemCount: 3),
              )
            else ...[
              if (!_generatePostTextMode &&
                  state.generatedIdeas.isNotEmpty) ...[
                Text(
                  localeCubit.translate('marketing_generated_ideas'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.brand),
                  ),
                  child: Column(
                    children: state.generatedIdeas
                        .map(
                          (idea) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  TablerIcons.bulb,
                                  color: colors.brand,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(idea, style: textStyles.bodySans),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ] else if (_generatePostTextMode &&
                  state.generatedText != null) ...[
                Text(
                  localeCubit.translate('marketing_publication_text'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
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
                        localeCubit.translateMessage(state.generatedText!),
                        style: textStyles.bodySans,
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(TablerIcons.copy),
                            tooltip: localeCubit.translate('common_copy'),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: state.generatedText!),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    localeCubit.translate('marketing_copied'),
                                  ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(TablerIcons.file_plus),
                            tooltip: localeCubit.translate(
                              'marketing_save_draft',
                            ),
                            onPressed: !_canManageMarketing(context)
                                ? null
                                : () {
                                    context.read<MarketingBloc>().add(
                                      CreatePostRequested(
                                        text: state.generatedText!,
                                        channel: 'telegram',
                                      ),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          localeCubit.translate(
                                            'marketing_post_saved_draft',
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        );
      },
    );
  }

  Widget _buildCampaignsTab(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();

    return BlocBuilder<MarketingBloc, MarketingState>(
      builder: (context, state) {
        if (state.isCampaignsLoading && state.campaigns.isEmpty) {
          return const MarketingCampaignsShimmer();
        }

        final visibleCount = _visibleCampaigns < state.campaigns.length
            ? _visibleCampaigns
            : state.campaigns.length;

        if (state.campaigns.isEmpty) {
          return Center(
            child: Text(
              localeCubit.translate('marketing_no_campaigns'),
              style: textStyles.bodySans.copyWith(color: colors.textSecondary),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            context.read<MarketingBloc>().add(
              const LoadMarketingData(forceRefresh: true),
            );
          },
          child: ListView.separated(
            controller: _campaignsController,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
            itemCount: visibleCount,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final campaign = state.campaigns[index];
              final isActive =
                  campaign.endedAt == null ||
                  campaign.endedAt!.isAfter(DateTime.now());

              return InkWell(
                onTap: () => _showCampaignDetailsBottomSheet(context, campaign),
                borderRadius: BorderRadius.circular(12),
                child: Container(
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
                          Expanded(
                            child: Text(
                              campaign.name,
                              style: textStyles.bodySans.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (_canManageMarketing(context))
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                TablerIcons.trash,
                                size: 18,
                                color: colors.accentRed,
                              ),
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text(
                                      localeCubit.translate('common_delete'),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: Text(
                                          localeCubit.translate(
                                            'common_cancel',
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: Text(
                                          localeCubit.translate(
                                            'common_delete',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true && context.mounted) {
                                  context.read<MarketingBloc>().add(
                                    DeleteCampaignRequested(campaign.id),
                                  );
                                }
                              },
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? colors.accentGreen.withValues(alpha: 0.1)
                                  : colors.surfaceNested,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isActive
                                  ? localeCubit.translate('hr_status_active')
                                  : localeCubit.translate('hr_status_inactive'),
                              style: textStyles.captionSans.copyWith(
                                color: isActive
                                    ? colors.accentGreen
                                    : colors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${localeCubit.translate('marketing_budget')}: ${formatLocalizedNumber(context, campaign.budget)} TJS  •  ${localeCubit.translate('marketing_spent')}: ${formatLocalizedNumber(context, campaign.spent)} TJS',
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${localeCubit.translate('marketing_leads')}: ${campaign.leads}  •  ${localeCubit.translate('marketing_sales')}: ${campaign.conversions}',
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPostsTab(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();
    final canManage = _canManageMarketing(context);

    return BlocBuilder<MarketingBloc, MarketingState>(
      builder: (context, state) {
        if (state.isPostsLoading && state.posts.isEmpty) {
          return const MarketingPostsShimmer();
        }

        final visibleCount = _visiblePosts < state.posts.length
            ? _visiblePosts
            : state.posts.length;

        if (state.posts.isEmpty) {
          return Center(
            child: Text(
              localeCubit.translate('marketing_no_posts'),
              style: textStyles.bodySans.copyWith(color: colors.textSecondary),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            context.read<MarketingBloc>().add(
              const LoadMarketingData(forceRefresh: true),
            );
          },
          child: ListView.separated(
            controller: _postsController,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
            itemCount: visibleCount,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final post = state.posts[index];
              final isPublished = post.status == 'published';

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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colors.brand.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            post.channel.toUpperCase(),
                            style: textStyles.captionSans.copyWith(
                              color: colors.brand,
                              fontWeight: FontWeight.w600,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isPublished
                                ? colors.accentGreen.withValues(alpha: 0.1)
                                : colors.surfaceNested,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isPublished
                                ? localeCubit.translate(
                                    'marketing_status_published',
                                  )
                                : localeCubit.translate(
                                    'marketing_status_draft',
                                  ),
                            style: textStyles.captionSans.copyWith(
                              color: isPublished
                                  ? colors.accentGreen
                                  : colors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      post.text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: textStyles.bodySans.copyWith(height: 1.3),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          localeCubit.translate(
                            'marketing_created_at',
                            params: {
                              'date': formatLocalizedDateTime(
                                context,
                                post.createdAt,
                                style: LocalizedDateTimeStyle.date,
                              ),
                            },
                          ),
                          style: textStyles.smallMono.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        if (canManage)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isPublished)
                                TextButton.icon(
                                  onPressed: () {
                                    context.read<MarketingBloc>().add(
                                      PublishPostRequested(post.id),
                                    );
                                  },
                                  icon: const Icon(TablerIcons.send, size: 14),
                                  label: Text(
                                    localeCubit.translate(
                                      'marketing_publish_telegram',
                                    ),
                                    style: textStyles.captionSans.copyWith(
                                      color: colors.brand,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: Icon(
                                  TablerIcons.trash,
                                  size: 18,
                                  color: colors.accentRed,
                                ),
                                onPressed: () {
                                  context.read<MarketingBloc>().add(
                                    DeletePostRequested(post.id),
                                  );
                                },
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBrandGuideTab(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.watch<LanguageCubit>();
    final canManage = _canManageMarketing(context);

    return BlocConsumer<MarketingBloc, MarketingState>(
      listenWhen: (previous, current) =>
          previous.brandGuide != current.brandGuide &&
          current.brandGuide != null,
      listener: (context, state) {
        final guide = state.brandGuide;
        if (guide != null && !_brandInitialized) {
          _brandInitialized = true;
          _brandNameController.text = guide.brandName ?? '';
          _toneController.text = guide.tone ?? '';
          _audienceController.text = guide.audience ?? '';
          _forbiddenController.text = guide.forbidden ?? '';
          _videoLimitController.text = guide.videoLimitMonth.toString();
        }
      },
      builder: (context, state) {
        if (state.isBrandLoading && state.brandGuide == null) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: LedgerListShimmer(itemCount: 4),
          );
        }

        final guide = state.brandGuide;
        if (guide != null && !_brandInitialized) {
          _brandInitialized = true;
          _brandNameController.text = guide.brandName ?? '';
          _toneController.text = guide.tone ?? '';
          _audienceController.text = guide.audience ?? '';
          _forbiddenController.text = guide.forbidden ?? '';
          _videoLimitController.text = guide.videoLimitMonth.toString();
        }

        final learnedRounds = guide?.learnedRounds ?? 0;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
                      Expanded(
                        child: Text(
                          localeCubit.translate('marketing_brand_title'),
                          style: textStyles.h2Sans.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (learnedRounds > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceNested,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            localeCubit.translate(
                              'marketing_brand_learned',
                              params: {'count': learnedRounds.toString()},
                            ),
                            style: textStyles.captionSans.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    localeCubit.translate('marketing_brand_desc'),
                    style: textStyles.captionSans.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _brandNameController,
                    enabled: canManage && !state.isSavingBrand,
                    style: textStyles.bodySans,
                    decoration: InputDecoration(
                      labelText: localeCubit.translate('marketing_brand_name'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _toneController,
                    enabled: canManage && !state.isSavingBrand,
                    maxLines: 2,
                    style: textStyles.bodySans,
                    decoration: InputDecoration(
                      labelText: localeCubit.translate('marketing_brand_tone'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _audienceController,
                    enabled: canManage && !state.isSavingBrand,
                    maxLines: 2,
                    style: textStyles.bodySans,
                    decoration: InputDecoration(
                      labelText: localeCubit.translate(
                        'marketing_brand_audience',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _forbiddenController,
                    enabled: canManage && !state.isSavingBrand,
                    maxLines: 2,
                    style: textStyles.bodySans,
                    decoration: InputDecoration(
                      labelText: localeCubit.translate(
                        'marketing_brand_forbidden',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _videoLimitController,
                    enabled: canManage && !state.isSavingBrand,
                    keyboardType: TextInputType.number,
                    style: textStyles.bodySans,
                    decoration: InputDecoration(
                      labelText: localeCubit.translate(
                        'marketing_brand_video_limit',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: (!canManage || state.isSavingBrand)
                          ? null
                          : () {
                              final updatedGuide = BrandGuide(
                                brandName:
                                    _brandNameController.text.trim().isNotEmpty
                                    ? _brandNameController.text.trim()
                                    : null,
                                tone: _toneController.text.trim().isNotEmpty
                                    ? _toneController.text.trim()
                                    : null,
                                audience:
                                    _audienceController.text.trim().isNotEmpty
                                    ? _audienceController.text.trim()
                                    : null,
                                forbidden:
                                    _forbiddenController.text.trim().isNotEmpty
                                    ? _forbiddenController.text.trim()
                                    : null,
                                videoLimitMonth:
                                    int.tryParse(
                                      _videoLimitController.text.trim(),
                                    ) ??
                                    10,
                                learnedRounds: learnedRounds,
                              );
                              context.read<MarketingBloc>().add(
                                UpdateBrandGuideRequested(updatedGuide),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    localeCubit.translate(
                                      'marketing_brand_save',
                                    ),
                                  ),
                                  backgroundColor: colors.accentGreen,
                                ),
                              );
                            },
                      child: state.isSavingBrand
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.surface,
                              ),
                            )
                          : Text(localeCubit.translate('marketing_brand_save')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCampaignDetailsBottomSheet(
    BuildContext context,
    MarketingCampaign campaign,
  ) {
    final textStyles = context.textStyles;
    final colors = context.colors;
    final localeCubit = context.read<LanguageCubit>();

    LedgerBottomSheet.show(
      context: context,
      title: campaign.name,
      builder: (context, setSheetState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  localeCubit.translate('marketing_channel'),
                  style: textStyles.bodySans.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.brand.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    campaign.channel?.toUpperCase() ??
                        localeCubit.translate('marketing_channel_none'),
                    style: textStyles.captionSans.copyWith(
                      color: colors.brand,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatColumn(
                  localeCubit.translate('marketing_budget'),
                  '${formatLocalizedNumber(context, campaign.budget)} TJS',
                  textStyles,
                  colors,
                ),
                const SizedBox(width: 16),
                _buildStatColumn(
                  localeCubit.translate('marketing_spent'),
                  '${formatLocalizedNumber(context, campaign.spent)} TJS',
                  textStyles,
                  colors,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatColumn(
                  localeCubit.translate('marketing_leads'),
                  formatLocalizedNumber(
                    context,
                    campaign.leads,
                    maximumFractionDigits: 0,
                  ),
                  textStyles,
                  colors,
                ),
                const SizedBox(width: 16),
                _buildStatColumn(
                  localeCubit.translate('marketing_sales'),
                  formatLocalizedNumber(
                    context,
                    campaign.conversions,
                    maximumFractionDigits: 0,
                  ),
                  textStyles,
                  colors,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatColumn(
                  'ROI',
                  '${formatLocalizedNumber(context, campaign.roi, minimumFractionDigits: 1, maximumFractionDigits: 1)}%',
                  textStyles,
                  colors,
                ),
                const SizedBox(width: 16),
                _buildStatColumn(
                  'CAC',
                  '${formatLocalizedNumber(context, campaign.cac ?? 0.0, minimumFractionDigits: 1, maximumFractionDigits: 1)} TJS',
                  textStyles,
                  colors,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatColumn(
    String label,
    String value,
    dynamic textStyles,
    dynamic colors,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textStyles.captionSans.copyWith(
              color: colors.textSecondary,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: textStyles.bodyMono.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  void _showCreatePostDialog(BuildContext context) {
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();
    final textCtrl = TextEditingController();
    String channel = 'telegram';

    LedgerBottomSheet.show(
      context: context,
      title: localeCubit.translate('marketing_new_publication'),
      builder: (context, setSheetState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: textCtrl,
              maxLines: 4,
              style: textStyles.bodySans,
              decoration: InputDecoration(
                hintText: localeCubit.translate('marketing_publication_hint'),
              ),
            ),
            const SizedBox(height: 12),
            ExpansibleWidget<String>.selection(
              title: Text(channel.toUpperCase(), style: textStyles.bodySans),
              items: const ['telegram', 'instagram', 'facebook', 'other'],
              selectedValue: channel,
              itemLabelBuilder: (c) => c.toUpperCase(),
              onSelected: (val) {
                setSheetState(() => channel = val);
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final text = textCtrl.text.trim();
                if (text.isEmpty) return;
                context.read<MarketingBloc>().add(
                  CreatePostRequested(text: text, channel: channel),
                );
                Navigator.pop(context);
              },
              child: Text(localeCubit.translate('common_create')),
            ),
          ],
        );
      },
    );
  }
}

void _showCreateCampaignDialog(BuildContext context) {
  final textStyles = context.textStyles;
  final localeCubit = context.read<LanguageCubit>();
  final nameCtrl = TextEditingController();
  final budgetCtrl = TextEditingController();
  String channel = 'telegram';

  LedgerBottomSheet.show(
    context: context,
    title: localeCubit.translate('marketing_new_campaign'),
    builder: (context, setSheetState) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: nameCtrl,
            style: textStyles.bodySans,
            decoration: InputDecoration(
              labelText: localeCubit.translate('marketing_campaign_name'),
            ),
          ),
          const SizedBox(height: 12),
          ExpansibleWidget<String>.selection(
            title: Text(channel.toUpperCase(), style: textStyles.bodySans),
            items: const [
              'telegram',
              'instagram',
              'facebook',
              'google',
              'other',
            ],
            selectedValue: channel,
            itemLabelBuilder: (c) => c.toUpperCase(),
            onSelected: (val) {
              setSheetState(() => channel = val);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: budgetCtrl,
            keyboardType: TextInputType.number,
            style: textStyles.bodySans,
            decoration: InputDecoration(
              labelText: localeCubit.translate('marketing_budget_tjs'),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final budget =
                  parseLocalizedNumber(context, budgetCtrl.text) ?? 0.0;
              if (name.isEmpty) return;
              context.read<MarketingBloc>().add(
                CreateCampaignRequested(
                  name: name,
                  channel: channel,
                  budget: budget,
                  spent: 0.0,
                  leads: 0,
                  conversions: 0,
                  revenue: 0.0,
                ),
              );
              Navigator.pop(context);
            },
            child: Text(localeCubit.translate('common_create')),
          ),
        ],
      );
    },
  );
}
