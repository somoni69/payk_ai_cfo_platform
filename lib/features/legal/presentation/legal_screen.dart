import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/localization/locale_date_time_format.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/auth/bloc/auth_state.dart';
import '../../../features/auth/domain/app_access.dart';
import '../../../features/legal/bloc/legal_bloc.dart';
import '../../../features/legal/bloc/legal_event.dart';
import '../../../features/legal/bloc/legal_state.dart';
import '../../../features/legal/domain/legal_models.dart';
import '../../../presentation/widgets/expansible_widget.dart';
import '../../../presentation/widgets/ledger_shimmer.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';

bool shouldAutoScrollLegalChat(LegalState previous, LegalState current) {
  return current is LegalLoaded &&
      (previous is! LegalLoaded ||
          !identical(previous.chatHistory, current.chatHistory));
}

enum LegalSection { aiLawyer, laws, constructor, deadlines }

String _legalSectionTitle(LanguageCubit language, LegalSection section) {
  return language.translate(switch (section) {
    LegalSection.aiLawyer => 'legal_tab_ai_lawyer',
    LegalSection.laws => 'legal_tab_laws',
    LegalSection.constructor => 'legal_tab_constructor',
    LegalSection.deadlines => 'legal_tab_deadlines',
  });
}

void _openLegalSection(BuildContext context, LegalSection section) {
  final bloc = context.read<LegalBloc>();
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: LegalSectionScreen(section: section),
      ),
    ),
  );
}

class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  bool _canManageLegal(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated &&
        authState.role.canManage(AppCapability.legal);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.watch<LanguageCubit>();

    return BlocProvider(
      create: (context) =>
          LegalBloc(context.read())..add(const LoadLegalData()),
      child: MultiBlocListener(
        listeners: [
          BlocListener<LegalBloc, LegalState>(
            listenWhen: (previous, current) {
              return current is LegalLoaded &&
                  current.errorMessage != null &&
                  (previous is! LegalLoaded ||
                      previous.errorMessage != current.errorMessage);
            },
            listener: (context, state) {
              final loaded = state as LegalLoaded;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    localeCubit.translateMessage(loaded.errorMessage!),
                  ),
                  backgroundColor: colors.accentRed,
                ),
              );
            },
          ),
          BlocListener<LegalBloc, LegalState>(
            listenWhen: (previous, current) {
              return current is LegalLoaded &&
                  current.successMessage != null &&
                  (previous is! LegalLoaded ||
                      previous.successMessage != current.successMessage);
            },
            listener: (context, state) {
              final loaded = state as LegalLoaded;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    localeCubit.translateMessage(loaded.successMessage!),
                  ),
                  backgroundColor: colors.accentGreen,
                ),
              );
            },
          ),
        ],
        child: BlocBuilder<LegalBloc, LegalState>(
          builder: (context, state) {
            if (state is LegalLoading) {
              return Scaffold(
                backgroundColor: colors.background,
                appBar: AppBar(
                  backgroundColor: colors.surface,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  title: Text(
                    localeCubit.translate('legal_title'),
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
                body: const LegalOverviewShimmer(),
              );
            }

            if (state is LegalLoaded) {
              final canManage = _canManageLegal(context);
              return Scaffold(
                backgroundColor: colors.background,
                appBar: AppBar(
                  backgroundColor: colors.surface,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  title: Text(
                    localeCubit.translate('legal_title'),
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
                body: _buildLegalOverviewHub(context, state, canManage),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildLegalOverviewHub(
    BuildContext context,
    LegalLoaded state,
    bool canManage,
  ) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();

    final pendingDeadlines = state.deadlines.where((d) => !d.isDone).length;
    final urgentDeadlines = state.deadlines
        .where((d) => !d.isDone && d.daysLeft != null && d.daysLeft! <= 7)
        .toList();

    return RefreshIndicator(
      onRefresh: () async {
        context.read<LegalBloc>().add(const LoadLegalData(forceRefresh: true));
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // 1. Hero Card: Legal & Compliance Radar
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
                        locale.translate('legal_hero_title'),
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
                            TablerIcons.scale,
                            size: 13,
                            color: colors.brand,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            locale.translate(
                              'legal_laws_count',
                              params: {'count': '${state.laws.length}'},
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
                  locale.translate(
                    'legal_attention_pending',
                    params: {'count': '$pendingDeadlines'},
                  ),
                  style: textStyles.h2Sans.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: colors.border),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(TablerIcons.gavel, size: 16, color: colors.brand),
                    const SizedBox(width: 6),
                    Text(
                      '${state.laws.length} ${locale.translate('legal_tab_laws').toLowerCase()}',
                      style: textStyles.captionSans.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• ${state.templates.length} ${locale.translate('legal_templates_count', params: {'count': ''}).toLowerCase()}',
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

          // 2. Actionable Attention Card
          InkWell(
            onTap: () => _openLegalSection(
              context,
              urgentDeadlines.isNotEmpty
                  ? LegalSection.deadlines
                  : LegalSection.aiLawyer,
            ),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: urgentDeadlines.isNotEmpty
                      ? colors.accentAmber.withValues(alpha: 0.5)
                      : colors.accentGreen.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: urgentDeadlines.isNotEmpty
                          ? colors.accentAmber.withValues(alpha: 0.1)
                          : colors.accentGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      urgentDeadlines.isNotEmpty
                          ? TablerIcons.alert_triangle
                          : TablerIcons.circle_check,
                      color: urgentDeadlines.isNotEmpty
                          ? colors.accentAmber
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
                          locale.translate('legal_attention_title'),
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          urgentDeadlines.isNotEmpty
                              ? locale.translate(
                                  'legal_attention_pending',
                                  params: {
                                    'count': '${urgentDeadlines.length}',
                                  },
                                )
                              : locale.translate('legal_attention_ok'),
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
                      onPressed: () =>
                          _openLegalSection(context, LegalSection.aiLawyer),
                      icon: const Icon(TablerIcons.robot, size: 17),
                      label: Text(
                        locale.translate('legal_action_chat'),
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
                      onPressed: () => _showCreateLawSheet(context),
                      icon: Icon(
                        TablerIcons.plus,
                        size: 17,
                        color: colors.textPrimary,
                      ),
                      label: Text(
                        locale.translate('legal_action_law'),
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
                  title: locale.translate('legal_tab_ai_lawyer'),
                  subtitle: 'Консультации ИИ юриста',
                  icon: TablerIcons.robot,
                  onTap: () =>
                      _openLegalSection(context, LegalSection.aiLawyer),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHubCard(
                  context,
                  title: locale.translate('legal_tab_laws'),
                  subtitle: locale.translate(
                    'legal_laws_count',
                    params: {'count': '${state.laws.length}'},
                  ),
                  icon: TablerIcons.scale,
                  onTap: () => _openLegalSection(context, LegalSection.laws),
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
                  title: locale.translate('legal_tab_constructor'),
                  subtitle: locale.translate(
                    'legal_templates_count',
                    params: {'count': '${state.templates.length}'},
                  ),
                  icon: TablerIcons.file_text,
                  onTap: () =>
                      _openLegalSection(context, LegalSection.constructor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHubCard(
                  context,
                  title: locale.translate('legal_tab_deadlines'),
                  subtitle: '$pendingDeadlines активных',
                  icon: TablerIcons.calendar_due,
                  onTap: () =>
                      _openLegalSection(context, LegalSection.deadlines),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 5. Upcoming Deadlines Feed
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                locale.translate('legal_recent_deadlines'),
                style: textStyles.h2Sans.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () =>
                    _openLegalSection(context, LegalSection.deadlines),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  children: [
                    Text(
                      locale.translate('legal_all_deadlines'),
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

          if (state.deadlines.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.border),
              ),
              alignment: Alignment.center,
              child: Text(
                locale.translate('legal_nothing_found'),
                style: textStyles.captionSans.copyWith(
                  color: colors.textSecondary,
                  fontSize: 13.5,
                ),
              ),
            )
          else
            ...state.deadlines.take(4).map((dl) {
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
                      Checkbox.adaptive(
                        value: dl.isDone,
                        activeColor: colors.accentGreen,
                        onChanged: !canManage
                            ? null
                            : (val) {
                                if (val != null) {
                                  context.read<LegalBloc>().add(
                                    ToggleDeadlineStatus(
                                      id: dl.id,
                                      isDone: val,
                                    ),
                                  );
                                }
                              },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dl.title,
                              style: textStyles.bodySans.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 14.5,
                                decoration: dl.isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: dl.isDone
                                    ? colors.textSecondary
                                    : colors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              locale.translate(
                                'legal_deadline_summary',
                                params: {
                                  'date': formatLocalizedDateTime(
                                    context,
                                    dl.dueDate,
                                    style: LocalizedDateTimeStyle.date,
                                  ),
                                  'days': '${dl.daysLeft ?? 0}',
                                },
                              ),
                              style: textStyles.captionSans.copyWith(
                                color: dl.isDone
                                    ? colors.textSecondary
                                    : (dl.daysLeft != null && dl.daysLeft! <= 5)
                                    ? colors.accentRed
                                    : colors.brand,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (dl.amount != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          dl.amount!,
                          style: textStyles.bodyMono.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
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

class LegalSectionScreen extends StatefulWidget {
  final LegalSection section;

  const LegalSectionScreen({super.key, required this.section});

  @override
  State<LegalSectionScreen> createState() => _LegalSectionScreenState();
}

class _LegalSectionScreenState extends State<LegalSectionScreen> {
  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  String _lawSearchQuery = '';
  int _selectedLawCategoryIndex = 0;

  @override
  void dispose() {
    _chatInputController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  bool _canManageLegal(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated &&
        authState.role.canManage(AppCapability.legal);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final locale = context.watch<LanguageCubit>();
    final canManage = _canManageLegal(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
        title: Text(
          _legalSectionTitle(locale, widget.section),
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
      body: BlocBuilder<LegalBloc, LegalState>(
        builder: (context, state) {
          if (state is LegalLoading) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: LedgerListShimmer(itemCount: 4),
            );
          }
          if (state is! LegalLoaded) {
            return const SizedBox.shrink();
          }

          return switch (widget.section) {
            LegalSection.aiLawyer => _buildAiLawyerTab(context, state),
            LegalSection.laws => _buildLawsTab(context, state),
            LegalSection.constructor => _buildConstructorTab(context, state),
            LegalSection.deadlines => _buildDeadlinesTab(context, state),
          };
        },
      ),
    );
  }

  Widget? _buildSectionFab(BuildContext context, LanguageCubit locale) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    if (widget.section == LegalSection.laws) {
      return FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _showCreateLawSheet(context),
        backgroundColor: colors.brand,
        foregroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        icon: const Icon(TablerIcons.plus),
        label: Text(
          locale.translate('legal_law_add'),
          style: textStyles.bodySans.copyWith(
            color: colors.surface,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (widget.section == LegalSection.deadlines) {
      return FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _showCreateDeadlineSheet(context),
        backgroundColor: colors.brand,
        foregroundColor: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        icon: const Icon(TablerIcons.plus),
        label: Text(
          locale.translate('legal_deadline_add'),
          style: textStyles.bodySans.copyWith(
            color: colors.surface,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return null;
  }

  // 1. AI Lawyer Tab
  Widget _buildAiLawyerTab(BuildContext context, LegalLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();

    final chips = [
      localeCubit.translate('legal_prompt_simplified_tax'),
      localeCubit.translate('legal_prompt_employment_contract'),
      localeCubit.translate('legal_prompt_social_tax_deadlines'),
    ];

    return Column(
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: colors.surface,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: chips.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ActionChip(
                  label: Text(chips[index]),
                  labelStyle: textStyles.captionSans.copyWith(
                    color: colors.brand,
                  ),
                  backgroundColor: colors.brand.withValues(alpha: 0.05),
                  side: BorderSide(color: colors.brand.withValues(alpha: 0.1)),
                  onPressed: _canManageLegal(context)
                      ? () {
                          context.read<LegalBloc>().add(
                            AskLawyerQuestion(chips[index]),
                          );
                        }
                      : null,
                ),
              );
            },
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _chatScrollController,
            padding: const EdgeInsets.all(16),
            itemCount: state.chatHistory.length,
            itemBuilder: (context, index) {
              final msg = state.chatHistory[index];
              final isUser = msg['sender'] == 'user';

              return Align(
                alignment: isUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.8,
                  ),
                  decoration: BoxDecoration(
                    color: isUser ? colors.brand : colors.surface,
                    borderRadius: BorderRadius.circular(12).copyWith(
                      bottomRight: isUser
                          ? const Radius.circular(0)
                          : const Radius.circular(12),
                      bottomLeft: isUser
                          ? const Radius.circular(12)
                          : const Radius.circular(0),
                    ),
                    border: isUser ? null : Border.all(color: colors.border),
                  ),
                  child: Text(
                    isUser
                        ? msg['text'] ?? ''
                        : localeCubit.translateMessage(msg['text'] ?? ''),
                    style: textStyles.bodySans.copyWith(
                      color: isUser ? colors.surface : colors.textPrimary,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (state.isAskingAi)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  localeCubit.translate('legal_ai_thinking'),
                  style: textStyles.captionSans,
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(top: BorderSide(color: colors.border)),
          ),
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: Icon(TablerIcons.trash, color: colors.textSecondary),
                  tooltip: localeCubit.translate('legal_clear_history'),
                  onPressed: () {
                    context.read<LegalBloc>().add(ClearLawyerHistory());
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _chatInputController,
                    enabled: _canManageLegal(context),
                    style: textStyles.bodySans,
                    decoration: InputDecoration(
                      hintText: localeCubit.translate('legal_question_hint'),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onSubmitted: _canManageLegal(context)
                        ? (val) {
                            if (val.trim().isNotEmpty) {
                              context.read<LegalBloc>().add(
                                AskLawyerQuestion(val.trim()),
                              );
                              _chatInputController.clear();
                            }
                          }
                        : null,
                  ),
                ),
                IconButton(
                  icon: Icon(TablerIcons.send, color: colors.brand),
                  tooltip: localeCubit.translate('common_send'),
                  onPressed: _canManageLegal(context)
                      ? () {
                          final text = _chatInputController.text.trim();
                          if (text.isNotEmpty) {
                            context.read<LegalBloc>().add(
                              AskLawyerQuestion(text),
                            );
                            _chatInputController.clear();
                          }
                        }
                      : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 2. Laws Tab
  Widget _buildLawsTab(BuildContext context, LegalLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();

    final categories = <({String? value, String labelKey})>[
      (value: null, labelKey: 'legal_category_all'),
      (value: 'Налоги', labelKey: 'legal_category_taxes'),
      (value: 'Трудовое право', labelKey: 'legal_category_labor_law'),
      (value: 'Корпоративное право', labelKey: 'legal_category_corporate_law'),
    ];
    final selectedCategory = categories[_selectedLawCategoryIndex].value;

    final filteredLaws = state.laws.where((law) {
      final matchesSearch =
          law.title.toLowerCase().contains(_lawSearchQuery.toLowerCase()) ||
          law.body.toLowerCase().contains(_lawSearchQuery.toLowerCase());
      final matchesCategory =
          selectedCategory == null || law.category == selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return Column(
      children: [
        Container(
          color: colors.surface,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                style: textStyles.bodySans,
                decoration: InputDecoration(
                  hintText: localeCubit.translate('legal_search_hint'),
                  prefixIcon: Icon(
                    TablerIcons.search,
                    color: colors.textSecondary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  filled: true,
                  fillColor: colors.background,
                ),
                onChanged: (val) {
                  setState(() {
                    _lawSearchQuery = val;
                  });
                },
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isSel = _selectedLawCategoryIndex == index;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(localeCubit.translate(category.labelKey)),
                        selected: isSel,
                        labelStyle: textStyles.captionSans.copyWith(
                          color: isSel ? Colors.white : colors.textPrimary,
                          fontWeight: isSel ? FontWeight.w500 : FontWeight.w400,
                        ),
                        checkmarkColor: Colors.white,
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _selectedLawCategoryIndex = index;
                            });
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filteredLaws.isEmpty
              ? Center(
                  child: Text(
                    localeCubit.translate('legal_nothing_found'),
                    style: textStyles.captionSans,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  itemCount: filteredLaws.length,
                  itemBuilder: (context, index) {
                    final law = filteredLaws[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: ExpansibleWidget(
                        cardPadding: const EdgeInsets.all(16),
                        title: Text(
                          law.title,
                          style: textStyles.bodySans.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          _localizedLawCategory(localeCubit, law.category),
                          style: textStyles.captionSans.copyWith(
                            color: colors.brand,
                          ),
                        ),
                        children: [
                          const SizedBox(height: 12),
                          Text(
                            law.body,
                            style: textStyles.bodySans.copyWith(height: 1.4),
                          ),
                          if (law.sourceUrl != null) ...[
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () {},
                              child: Row(
                                children: [
                                  Icon(
                                    TablerIcons.link,
                                    color: colors.brand,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    localeCubit.translate(
                                      'legal_read_official_site',
                                    ),
                                    style: textStyles.captionSans.copyWith(
                                      color: colors.brand,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _localizedLawCategory(LanguageCubit localeCubit, String? category) {
    return switch (category) {
      'Налоги' => localeCubit.translate('legal_category_taxes'),
      'Трудовое право' => localeCubit.translate('legal_category_labor_law'),
      'Корпоративное право' => localeCubit.translate(
        'legal_category_corporate_law',
      ),
      null => localeCubit.translate('legal_default_law_category'),
      _ => category,
    };
  }

  // 3. Constructor Tab
  Widget _buildConstructorTab(BuildContext context, LegalLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();

    if (state.generatedContract != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  localeCubit.translate('legal_document_generated'),
                  style: textStyles.bodySans.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                IconButton(
                  icon: Icon(TablerIcons.x, color: colors.textSecondary),
                  tooltip: localeCubit.translate('common_close'),
                  onPressed: () {
                    context.read<LegalBloc>().add(
                      const ClearGeneratedContract(),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.border),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localeCubit.translateMessage(
                          state.generatedContract!.title,
                        ),
                        style: textStyles.h2Sans.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        localeCubit.translate(
                          'legal_date',
                          params: {
                            'date': formatLocalizedDateTime(
                              context,
                              state.generatedContract!.createdAt,
                              style: LocalizedDateTimeStyle.date,
                            ),
                          },
                        ),
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const Divider(height: 24),
                      Text(
                        state.generatedContract!.body,
                        style: textStyles.bodySans.copyWith(
                          height: 1.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: state.generatedContract!.body),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            localeCubit.translate('legal_contract_copied'),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(TablerIcons.copy),
                    label: Text(localeCubit.translate('legal_copy_text')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.read<LegalBloc>().add(
                        const ClearGeneratedContract(),
                      );
                    },
                    icon: const Icon(TablerIcons.file_text),
                    label: Text(localeCubit.translate('legal_create_new')),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return state.isGenerating
        ? const LedgerNamedListShimmer(itemCount: 4)
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.templates.length,
            itemBuilder: (context, index) {
              final template = state.templates[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Container(
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
                          Text(
                            template.name,
                            style: textStyles.bodySans.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Icon(TablerIcons.file_plus, color: colors.brand),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        template.category ??
                            localeCubit.translate('legal_general_template'),
                        style: textStyles.captionSans.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _canManageLegal(context)
                            ? () => _showGenerateForm(context, template)
                            : null,
                        child: Text(
                          localeCubit.translate('legal_fill_details'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  void _showGenerateForm(BuildContext context, ContractTemplate template) {
    if (!_canManageLegal(context)) return;
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();
    final Map<String, String> values = {};
    final bloc = context.read<LegalBloc>();

    LedgerBottomSheet.show(
      context: context,
      title: localeCubit.translate('legal_contract_details'),
      builder: (context, setSheetState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              template.name,
              style: textStyles.captionSans.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ...template.variables.map((variable) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: TextField(
                  style: textStyles.bodySans,
                  decoration: InputDecoration(
                    labelText: variable.label,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    values[variable.key] = val;
                  },
                ),
              );
            }),
          ],
        );
      },
      footerBuilder: (context, setSheetState) {
        return ElevatedButton(
          onPressed: () {
            for (var v in template.variables) {
              if (!values.containsKey(v.key) || values[v.key]!.trim().isEmpty) {
                values[v.key] = localeCubit.translate(
                  'legal_not_specified',
                  params: {'label': v.label},
                );
              }
            }
            bloc.add(
              GenerateContractFromTemplate(
                templateId: template.id,
                variables: values,
              ),
            );
            Navigator.pop(context);
          },
          child: Text(localeCubit.translate('legal_generate_contract')),
        );
      },
    );
  }

  // 4. Deadlines Tab
  Widget _buildDeadlinesTab(BuildContext context, LegalLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();

    if (state.deadlines.isEmpty) {
      return Center(
        child: Text(
          localeCubit.translate('legal_nothing_found'),
          style: textStyles.captionSans,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: state.deadlines.length,
      itemBuilder: (context, index) {
        final dl = state.deadlines[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Checkbox.adaptive(
                  value: dl.isDone,
                  activeColor: colors.accentGreen,
                  onChanged: !_canManageLegal(context)
                      ? null
                      : (val) {
                          if (val != null) {
                            context.read<LegalBloc>().add(
                              ToggleDeadlineStatus(id: dl.id, isDone: val),
                            );
                          }
                        },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dl.title,
                        style: textStyles.bodySans.copyWith(
                          fontWeight: FontWeight.w500,
                          decoration: dl.isDone
                              ? TextDecoration.lineThrough
                              : null,
                          color: dl.isDone
                              ? colors.textSecondary
                              : colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        localeCubit.translate(
                          'legal_deadline_summary',
                          params: {
                            'date': formatLocalizedDateTime(
                              context,
                              dl.dueDate,
                              style: LocalizedDateTimeStyle.date,
                            ),
                            'days': '${dl.daysLeft ?? 0}',
                          },
                        ),
                        style: textStyles.captionSans.copyWith(
                          color: dl.isDone
                              ? colors.textSecondary
                              : (dl.daysLeft != null && dl.daysLeft! <= 5)
                              ? colors.accentRed
                              : colors.brand,
                        ),
                      ),
                      if (dl.note != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          dl.note!,
                          style: textStyles.captionSans.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (dl.amount != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    dl.amount!,
                    style: textStyles.bodyMono.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

void _showCreateLawSheet(BuildContext context) {
  final localeCubit = context.read<LanguageCubit>();
  final textStyles = context.textStyles;
  final colors = context.colors;
  final bloc = context.read<LegalBloc>();
  final titleController = TextEditingController();
  final bodyController = TextEditingController();
  String? category;

  final categories = <({String? value, String labelKey})>[
    (value: null, labelKey: 'legal_category_all'),
    (value: 'Налоги', labelKey: 'legal_category_taxes'),
    (value: 'Трудовое право', labelKey: 'legal_category_labor_law'),
    (value: 'Корпоративное право', labelKey: 'legal_category_corporate_law'),
  ];

  LedgerBottomSheet.show(
    context: context,
    title: localeCubit.translate('legal_law_add'),
    builder: (context, setSheetState) {
      final selected = categories.firstWhere(
        (c) => c.value == category,
        orElse: () => categories.first,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: titleController,
            style: textStyles.bodySans,
            decoration: InputDecoration(
              labelText: localeCubit.translate('legal_law_title'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: bodyController,
            style: textStyles.bodySans,
            minLines: 4,
            maxLines: 8,
            decoration: InputDecoration(
              labelText: localeCubit.translate('legal_law_body'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            localeCubit.translate('legal_law_category'),
            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          ExpansibleWidget<({String? value, String labelKey})>.selection(
            title: Text(
              localeCubit.translate(selected.labelKey),
              style: textStyles.bodySans.copyWith(
                color: category == null
                    ? colors.textTooltip
                    : colors.textPrimary,
              ),
            ),
            items: categories,
            selectedValue: selected,
            itemLabelBuilder: (c) => localeCubit.translate(c.labelKey),
            onSelected: (c) {
              setSheetState(() => category = c.value);
            },
          ),
        ],
      );
    },
    footerBuilder: (context, setSheetState) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            final title = titleController.text.trim();
            final body = bodyController.text.trim();
            if (title.isEmpty || body.isEmpty) return;
            bloc.add(
              CreateLawRequested(title: title, body: body, category: category),
            );
            Navigator.pop(context);
          },
          child: Text(localeCubit.translate('common_save')),
        ),
      );
    },
  );
}

void _showCreateDeadlineSheet(BuildContext context) {
  final localeCubit = context.read<LanguageCubit>();
  final textStyles = context.textStyles;
  final colors = context.colors;
  final bloc = context.read<LegalBloc>();
  final titleController = TextEditingController();
  final amountController = TextEditingController();
  final noteController = TextEditingController();
  var type = 'TAX';
  var dueDate = DateTime.now().add(const Duration(days: 7));

  const types = <String>['TAX', 'CONTRACT', 'OTHER'];

  String deadlineTypeLabel(LanguageCubit locale, String t) {
    return switch (t) {
      'TAX' => locale.translate('legal_deadline_type_tax'),
      'CONTRACT' => locale.translate('legal_deadline_type_contract'),
      'OTHER' => locale.translate('legal_deadline_type_other'),
      _ => t,
    };
  }

  LedgerBottomSheet.show(
    context: context,
    title: localeCubit.translate('legal_deadline_add'),
    builder: (context, setSheetState) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: titleController,
            style: textStyles.bodySans,
            decoration: InputDecoration(
              labelText: localeCubit.translate('legal_deadline_title'),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            localeCubit.translate('legal_deadline_type'),
            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          ExpansibleWidget<String>.selection(
            title: Text(
              deadlineTypeLabel(localeCubit, type),
              style: textStyles.bodySans,
            ),
            items: types,
            selectedValue: type,
            itemLabelBuilder: (t) => deadlineTypeLabel(localeCubit, t),
            onSelected: (t) => setSheetState(() => type = t),
          ),
          const SizedBox(height: 16),
          Text(
            localeCubit.translate('legal_deadline_due_date'),
            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: dueDate,
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
              );
              if (picked != null) {
                setSheetState(() => dueDate = picked);
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
                    formatLocalizedDateTime(
                      context,
                      dueDate,
                      style: LocalizedDateTimeStyle.date,
                    ),
                    style: textStyles.smallMono.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  Icon(
                    TablerIcons.calendar,
                    size: 16,
                    color: colors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: amountController,
            style: textStyles.bodyMono,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText: localeCubit.translate('legal_deadline_amount'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteController,
            style: textStyles.bodySans,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: localeCubit.translate('legal_deadline_note'),
            ),
          ),
        ],
      );
    },
    footerBuilder: (context, setSheetState) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            final title = titleController.text.trim();
            if (title.isEmpty) return;
            bloc.add(
              CreateDeadlineRequested(
                title: title,
                type: type,
                dueDate: dueDate,
                amount: amountController.text.trim().isEmpty
                    ? null
                    : amountController.text.trim(),
                note: noteController.text.trim().isEmpty
                    ? null
                    : noteController.text.trim(),
              ),
            );
            Navigator.pop(context);
          },
          child: Text(localeCubit.translate('common_save')),
        ),
      );
    },
  );
}
