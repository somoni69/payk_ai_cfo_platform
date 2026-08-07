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
import '../../../presentation/widgets/ledger_card.dart';
import '../../../presentation/widgets/ledger_pill.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';
import '../../../presentation/widgets/expansible_widget.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';
import '../../../presentation/widgets/ledger_collapsing_header.dart';

class MarketingScreen extends StatelessWidget {
  const MarketingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageCubit>();
    return BlocProvider<MarketingBloc>(
      create: (context) =>
          MarketingBloc(context.read<MarketingRepository>())
            ..add(LoadMarketingData()),
      child: const MarketingView(),
    );
  }
}

class MarketingView extends StatefulWidget {
  const MarketingView({super.key});

  @override
  State<MarketingView> createState() => _MarketingViewState();
}

class _MarketingViewState extends State<MarketingView>
    with SingleTickerProviderStateMixin {
  static const _pageSize = 40;

  late TabController _tabController;
  final ScrollController _campaignsController = ScrollController();
  final ScrollController _postsController = ScrollController();
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _postController = TextEditingController();
  String _selectedChannel = 'telegram';
  bool _generatePostTextMode = false;
  int _visibleCampaigns = _pageSize;
  int _visiblePosts = _pageSize;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _campaignsController.addListener(_revealMoreCampaigns);
    _postsController.addListener(_revealMorePosts);
  }

  void _revealMoreCampaigns() {
    if (!_campaignsController.hasClients ||
        _campaignsController.position.extentAfter > 600) {
      return;
    }
    final total = context.read<MarketingBloc>().state.campaigns.length;
    if (_visibleCampaigns >= total) return;
    final next = _visibleCampaigns + _pageSize;
    setState(() => _visibleCampaigns = next < total ? next : total);
  }

  void _revealMorePosts() {
    if (!_postsController.hasClients ||
        _postsController.position.extentAfter > 600) {
      return;
    }
    final total = context.read<MarketingBloc>().state.posts.length;
    if (_visiblePosts >= total) return;
    final next = _visiblePosts + _pageSize;
    setState(() => _visiblePosts = next < total ? next : total);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _campaignsController
      ..removeListener(_revealMoreCampaigns)
      ..dispose();
    _postsController
      ..removeListener(_revealMorePosts)
      ..dispose();
    _promptController.dispose();
    _postController.dispose();
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
    final localeCubit = context.watch<LanguageCubit>();

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            LedgerCollapsingHeader(
              title: localeCubit.translate('marketing_title'),
              pinned: true,
              floating: true,
              snap: true,
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: colors.brand,
                labelColor: colors.brand,
                unselectedLabelColor: colors.textSecondary,
                labelStyle: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                tabs: [
                  Tab(text: localeCubit.translate('marketing_tab_ai_writer')),
                  Tab(text: localeCubit.translate('marketing_tab_campaigns')),
                  Tab(text: localeCubit.translate('marketing_tab_posts')),
                ],
              ),
            ),
          ];
        },
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
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildAiWriterTab(context),
              _buildCampaignsTab(context),
              _buildPostsTab(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiWriterTab(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();

    return BlocBuilder<MarketingBloc, MarketingState>(
      buildWhen: (previous, current) =>
          previous.isGenerating != current.isGenerating ||
          previous.generatedIdeas != current.generatedIdeas ||
          previous.generatedText != current.generatedText,
      builder: (context, state) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              localeCubit.translate('marketing_writer_description'),
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            // Режим генерации
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Text(
                      localeCubit.translate('marketing_mode_ad_ideas'),
                    ),
                    labelStyle: textStyles.captionSans.copyWith(
                      color: !_generatePostTextMode ? Colors.white : colors.textPrimary,
                      fontWeight: !_generatePostTextMode ? FontWeight.w500 : FontWeight.w400,
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
                      color: _generatePostTextMode ? Colors.white : colors.textPrimary,
                      fontWeight: _generatePostTextMode ? FontWeight.w500 : FontWeight.w400,
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
              icon: const Icon(TablerIcons.sparkles),
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
              const Center(child: CircularProgressIndicator())
            else ...[
              if (!_generatePostTextMode &&
                  state.generatedIdeas.isNotEmpty) ...[
                Text(
                  localeCubit.translate('marketing_generated_ideas'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                LedgerCard(
                  padding: const EdgeInsets.all(16),
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
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                LedgerCard(
                  padding: const EdgeInsets.all(16),
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
      buildWhen: (previous, current) =>
          previous.campaigns != current.campaigns ||
          previous.isCampaignsLoading != current.isCampaignsLoading,
      builder: (context, state) {
        if (state.isCampaignsLoading && state.campaigns.isEmpty) {
          return const LedgerListShimmer(showStatsHeader: false, itemCount: 5);
        }

        final visibleCount = _visibleCampaigns < state.campaigns.length
            ? _visibleCampaigns
            : state.campaigns.length;
        return Scaffold(
          floatingActionButton: _canManageMarketing(context)
              ? FloatingActionButton.extended(
                  tooltip: localeCubit.translate('marketing_new_campaign'),
                  backgroundColor: colors.brand,
                  foregroundColor: colors.surface,
                  elevation: 0,
                  highlightElevation: 0,
                  focusElevation: 0,
                  hoverElevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colors.brand),
                  ),
                  onPressed: () => _showCreateCampaignDialog(context),
                  icon: const Icon(TablerIcons.plus),
                  label: Text(
                    localeCubit.translate('marketing_new_campaign'),
                    style: textStyles.bodySans.copyWith(
                      color: colors.surface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              : null,
          body: RefreshIndicator(
            onRefresh: () async {
              _visibleCampaigns = _pageSize;
              await context.read<MarketingBloc>().reload();
            },
            child: ListView.builder(
              controller: _campaignsController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: state.campaigns.isEmpty ? 1 : visibleCount,
              itemBuilder: (context, index) {
                if (state.campaigns.isEmpty) {
                  return Center(
                    child: Text(
                      localeCubit.translate('marketing_no_campaigns'),
                    ),
                  );
                }

                final camp = state.campaigns[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: InkWell(
                    onTap: () => _showCampaignDetailsBottomSheet(context, camp),
                    borderRadius: BorderRadius.circular(12),
                    child: LedgerCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              camp.name,
                              style: textStyles.bodySans.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          LedgerPill(
                            text:
                                camp.channel?.toUpperCase() ??
                                localeCubit.translate('marketing_channel_none'),
                            backgroundColor: colors.brand.withValues(
                              alpha: 0.1,
                            ),
                            textColor: colors.brand,
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            TablerIcons.chevron_right,
                            size: 20,
                            color: colors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildPostsTab(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();

    return BlocBuilder<MarketingBloc, MarketingState>(
      buildWhen: (previous, current) =>
          previous.posts != current.posts ||
          previous.isPostsLoading != current.isPostsLoading,
      builder: (context, state) {
        if (state.isPostsLoading && state.posts.isEmpty) {
          return const LedgerListShimmer(showStatsHeader: false, itemCount: 5);
        }

        final visibleCount = _visiblePosts < state.posts.length
            ? _visiblePosts
            : state.posts.length;
        return Scaffold(
          floatingActionButton: _canManageMarketing(context)
              ? FloatingActionButton.extended(
                  tooltip: localeCubit.translate('marketing_new_publication'),
                  backgroundColor: colors.brand,
                  foregroundColor: colors.surface,
                  elevation: 0,
                  highlightElevation: 0,
                  focusElevation: 0,
                  hoverElevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colors.brand),
                  ),
                  onPressed: () => _showCreatePostDialog(context),
                  icon: const Icon(TablerIcons.plus),
                  label: Text(
                    localeCubit.translate('marketing_new_publication'),
                    style: textStyles.bodySans.copyWith(
                      color: colors.surface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              : null,
          body: RefreshIndicator(
            onRefresh: () async {
              _visiblePosts = _pageSize;
              await context.read<MarketingBloc>().reload();
            },
            child: ListView.builder(
              controller: _postsController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: state.posts.isEmpty ? 1 : visibleCount,
              itemBuilder: (context, index) {
                if (state.posts.isEmpty) {
                  return Center(
                    child: Text(localeCubit.translate('marketing_no_posts')),
                  );
                }

                final post = state.posts[index];
                final isDraft = post.status == 'draft';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: LedgerCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            LedgerPill(
                              text: post.channel.toUpperCase(),
                              backgroundColor: colors.brand.withValues(
                                alpha: 0.1,
                              ),
                              textColor: colors.brand,
                            ),
                            LedgerPill(
                              text: localeCubit.translate(
                                isDraft
                                    ? 'marketing_status_draft'
                                    : 'marketing_status_published',
                              ),
                              backgroundColor: isDraft
                                  ? colors.accentAmber.withValues(alpha: 0.1)
                                  : colors.accentGreen.withValues(alpha: 0.1),
                              textColor: isDraft
                                  ? colors.accentAmber
                                  : colors.accentGreen,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(post.text, style: textStyles.bodySans),
                        const Divider(height: 24),
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
                                    style: LocalizedDateTimeStyle.dayMonthTime,
                                  ),
                                },
                              ),
                              style: textStyles.captionSans.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                            if (isDraft && _canManageMarketing(context))
                              ElevatedButton.icon(
                                onPressed: () {
                                  context.read<MarketingBloc>().add(
                                    PublishPostRequested(post.id),
                                  );
                                },
                                icon: const Icon(TablerIcons.send, size: 16),
                                label: Text(
                                  localeCubit.translate(
                                    'marketing_publish_telegram',
                                  ),
                                  style: textStyles.smallSans,
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(
    String label,
    String val,
    dynamic textStyles,
    dynamic colors,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: textStyles.bodySans.copyWith(color: colors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            val,
            style: textStyles.h2Sans.copyWith(
              fontWeight: FontWeight.w500,
              color: colors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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
                LedgerPill(
                  text:
                      campaign.channel?.toUpperCase() ??
                      localeCubit.translate('marketing_channel_none'),
                  backgroundColor: colors.brand.withValues(alpha: 0.1),
                  textColor: colors.brand,
                ),
              ],
            ),
            const Divider(height: 24),

            // Строка 1 (2х2х2): Бюджет | Потрачено
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

            // Строка 2 (2х2х2): Лиды | Продажи
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

            // Строка 3 (2х2х2): ROI | CAC
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
                  campaign.cac != null
                      ? '${formatLocalizedNumber(context, campaign.cac!)} TJS'
                      : '—',
                  textStyles,
                  colors,
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Future<void> _showCreateCampaignDialog(BuildContext context) async {
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();
    final nameCtrl = TextEditingController();
    final budgetCtrl = TextEditingController();
    final spentCtrl = TextEditingController();
    final leadsCtrl = TextEditingController();
    final convCtrl = TextEditingController();
    final revCtrl = TextEditingController();
    String channel = 'telegram';

    bool isDirty() {
      return nameCtrl.text.trim().isNotEmpty ||
          budgetCtrl.text.trim().isNotEmpty ||
          spentCtrl.text.trim().isNotEmpty ||
          leadsCtrl.text.trim().isNotEmpty ||
          convCtrl.text.trim().isNotEmpty ||
          revCtrl.text.trim().isNotEmpty ||
          channel != 'telegram';
    }

    try {
      await LedgerBottomSheet.show(
        context: context,
        title: localeCubit.translate('marketing_new_campaign'),
        isDirty: isDirty,
        builder: (context, setSheetState) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: nameCtrl,
                style: textStyles.bodySans,
                decoration: InputDecoration(
                  labelText: localeCubit.translate('marketing_campaign_name'),
                ),
                onChanged: (_) => setSheetState(() {}),
              ),
              const SizedBox(height: 16),
              Text(
                localeCubit.translate('marketing_channel'),
                style: textStyles.bodySans.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              ExpansibleWidget<String>.selection(
                cardPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                title: Text(
                  channel[0].toUpperCase() + channel.substring(1),
                  style: textStyles.bodySans,
                ),
                items: const ['telegram', 'instagram', 'facebook'],
                selectedValue: channel,
                itemLabelBuilder: (s) => s[0].toUpperCase() + s.substring(1),
                onSelected: (val) {
                  setSheetState(() {
                    channel = val;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: budgetCtrl,
                style: textStyles.bodySans,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: localeCubit.translate('marketing_budget_tjs'),
                ),
                onChanged: (_) => setSheetState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: spentCtrl,
                style: textStyles.bodySans,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: localeCubit.translate('marketing_spent_tjs'),
                ),
                onChanged: (_) => setSheetState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: leadsCtrl,
                style: textStyles.bodySans,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: localeCubit.translate('marketing_leads_count'),
                ),
                onChanged: (_) => setSheetState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: convCtrl,
                style: textStyles.bodySans,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: localeCubit.translate('marketing_sales_count'),
                ),
                onChanged: (_) => setSheetState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: revCtrl,
                style: textStyles.bodySans,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: localeCubit.translate('marketing_revenue_tjs'),
                ),
                onChanged: (_) => setSheetState(() {}),
              ),
            ],
          );
        },
        footerBuilder: (context, setSheetState) {
          return ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              context.read<MarketingBloc>().add(
                CreateCampaignRequested(
                  name: name,
                  channel: channel,
                  budget: parseLocalizedNumber(context, budgetCtrl.text) ?? 0.0,
                  spent: parseLocalizedNumber(context, spentCtrl.text) ?? 0.0,
                  leads: int.tryParse(leadsCtrl.text) ?? 0,
                  conversions: int.tryParse(convCtrl.text) ?? 0,
                  revenue: parseLocalizedNumber(context, revCtrl.text) ?? 0.0,
                ),
              );

              Navigator.pop(context);
            },
            child: Text(localeCubit.translate('marketing_create')),
          );
        },
      );
    } finally {
      nameCtrl.dispose();
      budgetCtrl.dispose();
      spentCtrl.dispose();
      leadsCtrl.dispose();
      convCtrl.dispose();
      revCtrl.dispose();
    }
  }

  void _showCreatePostDialog(BuildContext context) {
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();

    bool isDirty() {
      return _postController.text.trim().isNotEmpty ||
          _selectedChannel != 'telegram';
    }

    LedgerBottomSheet.show(
      context: context,
      title: localeCubit.translate('marketing_new_publication'),
      isDirty: isDirty,
      builder: (context, setSheetState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _postController,
              maxLines: 4,
              style: textStyles.bodySans,
              decoration: InputDecoration(
                hintText: localeCubit.translate('marketing_publication_hint'),
              ),
              onChanged: (_) => setSheetState(() {}),
            ),
            const SizedBox(height: 16),
            Text(
              localeCubit.translate('marketing_publication_channel'),
              style: textStyles.bodySans.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            ExpansibleWidget<String>.selection(
              cardPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
              ),
              title: Text(
                _selectedChannel[0].toUpperCase() +
                    _selectedChannel.substring(1),
                style: textStyles.bodySans,
              ),
              items: const ['telegram', 'instagram', 'facebook'],
              selectedValue: _selectedChannel,
              itemLabelBuilder: (s) => s[0].toUpperCase() + s.substring(1),
              onSelected: (val) {
                setSheetState(() {
                  _selectedChannel = val;
                });
              },
            ),
          ],
        );
      },
      footerBuilder: (context, setSheetState) {
        return ElevatedButton(
          onPressed: () {
            final text = _postController.text.trim();
            if (text.isEmpty) return;

            context.read<MarketingBloc>().add(
              CreatePostRequested(text: text, channel: _selectedChannel),
            );

            _postController.clear();
            Navigator.pop(context);
          },
          child: Text(localeCubit.translate('marketing_save_draft')),
        );
      },
    );
  }
}
