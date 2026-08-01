import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../../core/localization/language_cubit.dart';
import '../../../core/theme/theme_extensions.dart';
import '../../../features/auth/bloc/auth_bloc.dart';
import '../../../features/auth/bloc/auth_state.dart';
import '../../../features/auth/domain/app_access.dart';
import '../../../features/legal/bloc/legal_bloc.dart';
import '../../../features/legal/bloc/legal_event.dart';
import '../../../features/legal/bloc/legal_state.dart';
import '../../../features/legal/domain/legal_models.dart';
import '../../../presentation/widgets/ledger_card.dart';
import '../../../presentation/widgets/expansible_widget.dart';
import '../../../presentation/widgets/ledger_bottom_sheet.dart';

bool shouldAutoScrollLegalChat(LegalState previous, LegalState current) {
  return current is LegalLoaded &&
      (previous is! LegalLoaded ||
          !identical(previous.chatHistory, current.chatHistory));
}

class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  String _lawSearchQuery = '';
  int _selectedLawCategoryIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatInputController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  bool _canManageLegal(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated &&
        authState.role.canManage(AppCapability.legal);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_chatScrollController.hasClients) return;
      _chatScrollController.animateTo(
        _chatScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.watch<LanguageCubit>();

    return BlocProvider(
      create: (context) =>
          LegalBloc(context.read())..add(const LoadLegalData()),
      child: BlocListener<LegalBloc, LegalState>(
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
              content: Text(localeCubit.translateMessage(loaded.errorMessage!)),
              backgroundColor: colors.accentRed,
            ),
          );
        },
        child: BlocConsumer<LegalBloc, LegalState>(
          listenWhen: shouldAutoScrollLegalChat,
          listener: (context, state) => _scrollToBottom(),
          builder: (context, state) {
            if (state is LegalLoading) {
              return Scaffold(
                backgroundColor: colors.background,
                appBar: AppBar(
                  backgroundColor: colors.surface,
                  title: Text(
                    localeCubit.translate('legal_loading_title'),
                    style: textStyles.h1Sans.copyWith(
                      fontSize: MediaQuery.of(context).size.width >= 600
                          ? 22.0
                          : 20.0,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                body: const Center(child: CircularProgressIndicator()),
              );
            }

            if (state is LegalError) {
              return Scaffold(
                backgroundColor: colors.background,
                appBar: AppBar(
                  backgroundColor: colors.surface,
                  title: Text(
                    localeCubit.translate('legal_error_title'),
                    style: textStyles.h1Sans.copyWith(
                      fontSize: MediaQuery.of(context).size.width >= 600
                          ? 22.0
                          : 20.0,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          TablerIcons.alert_triangle,
                          color: colors.accentRed,
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          localeCubit.translateMessage(state.message),
                          style: textStyles.bodySans,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            context.read<LegalBloc>().add(
                              const LoadLegalData(forceRefresh: true),
                            );
                          },
                          child: Text(localeCubit.translate('legal_retry')),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            if (state is LegalLoaded) {
              return Scaffold(
                backgroundColor: colors.background,
                appBar: AppBar(
                  backgroundColor: colors.surface,
                  scrolledUnderElevation: 0,
                  title: Text(
                    localeCubit.translate('legal_title'),
                    style: textStyles.h1Sans.copyWith(
                      fontSize: MediaQuery.of(context).size.width >= 600
                          ? 22.0
                          : 20.0,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  bottom: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: colors.brand,
                    unselectedLabelColor: colors.textSecondary,
                    indicatorColor: colors.brand,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: colors.border,
                    labelStyle: textStyles.captionSans.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    unselectedLabelStyle: textStyles.captionSans.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                    tabs: [
                      Tab(text: localeCubit.translate('legal_tab_ai_lawyer')),
                      Tab(text: localeCubit.translate('legal_tab_laws')),
                      Tab(text: localeCubit.translate('legal_tab_constructor')),
                      Tab(text: localeCubit.translate('legal_tab_deadlines')),
                    ],
                  ),
                ),
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAiLawyerTab(context, state),
                    _buildLawsTab(context, state),
                    _buildConstructorTab(context, state),
                    _buildDeadlinesTab(context, state),
                  ],
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  // --- 1. Вкладка ИИ-Юрист ---
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
        // Quick helper chips
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
        // Chat Area
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
                      color: isUser ? Colors.white : colors.textPrimary,
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
        // Input Area
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

  // --- 2. Вкладка Законы РТ ---
  Widget _buildLawsTab(BuildContext context, LegalLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();

    // Categories filter list
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
        // Search & Filter
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
        // Laws List
        Expanded(
          child: filteredLaws.isEmpty
              ? Center(
                  child: Text(
                    localeCubit.translate('legal_nothing_found'),
                    style: textStyles.captionSans,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
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
                              onTap: () {
                                // URL launch simulated
                              },
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

  // --- 3. Вкладка Конструктор договоров ---
  Widget _buildConstructorTab(BuildContext context, LegalLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();

    if (state.generatedContract != null) {
      // Show generated contract view
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
              child: LedgerCard(
                padding: const EdgeInsets.all(16),
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
                            'date': state.generatedContract!.createdAt
                                .toIso8601String()
                                .split('T')
                                .first,
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
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(localeCubit.translate('legal_generating_document')),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.templates.length,
            itemBuilder: (context, index) {
              final template = state.templates[index];
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
            // Check variables filled
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

  // --- 4. Вкладка Сроки ---
  Widget _buildDeadlinesTab(BuildContext context, LegalLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final localeCubit = context.read<LanguageCubit>();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.deadlines.length,
      itemBuilder: (context, index) {
        final dl = state.deadlines[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: LedgerCard(
            padding: const EdgeInsets.all(14),
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
                            'date': dl.dueDate
                                .toIso8601String()
                                .split('T')
                                .first,
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
