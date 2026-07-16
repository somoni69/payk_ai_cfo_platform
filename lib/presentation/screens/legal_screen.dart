import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../core/theme/theme_extensions.dart';
import '../../features/legal/bloc/legal_bloc.dart';
import '../../features/legal/bloc/legal_event.dart';
import '../../features/legal/bloc/legal_state.dart';
import '../../features/legal/domain/legal_models.dart';
import '../widgets/ledger_card.dart';
import '../widgets/expansible_widget.dart';
import '../widgets/ledger_bottom_sheet.dart';

class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _chatInputController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  String _lawSearchQuery = '';
  String _selectedLawCategory = 'Все';

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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return BlocProvider(
      create: (context) => LegalBloc(context.read())..add(LoadLegalData()),
      child: BlocConsumer<LegalBloc, LegalState>(
        listener: (context, state) {
          if (state is LegalLoaded) {
            if (state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage!),
                  backgroundColor: colors.accentRed,
                ),
              );
            }
            // Auto scroll chat when new messages arrive
            _scrollToBottom();
          }
        },
        builder: (context, state) {
          if (state is LegalLoading) {
            return Scaffold(
              backgroundColor: colors.background,
              appBar: AppBar(
                backgroundColor: colors.surface,
                title: Text('База законов и ИИ-Юрист', style: textStyles.h1Sans),
              ),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          if (state is LegalError) {
            return Scaffold(
              backgroundColor: colors.background,
              appBar: AppBar(
                backgroundColor: colors.surface,
                title: Text('Ошибка', style: textStyles.h1Sans),
              ),
              body: Center(
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
                          context.read<LegalBloc>().add(LoadLegalData());
                        },
                        child: const Text('Повторить попытку'),
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
                title: Text('Юридический блок РТ', style: textStyles.h1Sans),
                bottom: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: colors.brand,
                  unselectedLabelColor: colors.textSecondary,
                  indicatorColor: colors.brand,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: colors.border,
                  labelStyle: textStyles.captionSans.copyWith(fontWeight: FontWeight.w500),
                  unselectedLabelStyle: textStyles.captionSans.copyWith(fontWeight: FontWeight.w400),
                  tabs: const [
                    Tab(text: 'ИИ-Юрист'),
                    Tab(text: 'Законы РТ'),
                    Tab(text: 'Конструктор'),
                    Tab(text: 'Сроки'),
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
    );
  }

  // --- 1. Вкладка ИИ-Юрист ---
  Widget _buildAiLawyerTab(BuildContext context, LegalLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    final chips = [
      'Ставка по упрощенке в РТ',
      'Как оформить трудовой договор в РТ?',
      'Сроки уплаты соцналога за сотрудников',
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
                  labelStyle: textStyles.captionSans.copyWith(color: colors.brand),
                  backgroundColor: colors.brand.withValues(alpha: 0.05),
                  side: BorderSide(color: colors.brand.withValues(alpha: 0.1)),
                  onPressed: () {
                    context.read<LegalBloc>().add(AskLawyerQuestion(chips[index]));
                  },
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
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.8,
                  ),
                  decoration: BoxDecoration(
                    color: isUser ? colors.brand : colors.surface,
                    borderRadius: BorderRadius.circular(12).copyWith(
                      bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(12),
                      bottomLeft: isUser ? const Radius.circular(12) : const Radius.circular(0),
                    ),
                    border: isUser ? null : Border.all(color: colors.border),
                  ),
                  child: Text(
                    msg['text'] ?? '',
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
                Text('ИИ-Юрист думает...', style: textStyles.captionSans),
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
                  onPressed: () {
                    context.read<LegalBloc>().add(ClearLawyerHistory());
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _chatInputController,
                    style: textStyles.bodySans,
                    decoration: const InputDecoration(
                      hintText: 'Задайте вопрос юристу...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        context.read<LegalBloc>().add(AskLawyerQuestion(val.trim()));
                        _chatInputController.clear();
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(TablerIcons.send, color: colors.brand),
                  onPressed: () {
                    final text = _chatInputController.text.trim();
                    if (text.isNotEmpty) {
                      context.read<LegalBloc>().add(AskLawyerQuestion(text));
                      _chatInputController.clear();
                    }
                  },
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

    // Categories filter list
    final categories = ['Все', 'Налоги', 'Трудовое право', 'Корпоративное право'];

    final filteredLaws = state.laws.where((law) {
      final matchesSearch = law.title.toLowerCase().contains(_lawSearchQuery.toLowerCase()) ||
          law.body.toLowerCase().contains(_lawSearchQuery.toLowerCase());
      final matchesCategory = _selectedLawCategory == 'Все' || law.category == _selectedLawCategory;
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
                  hintText: 'Поиск по базе законов...',
                  prefixIcon: Icon(TablerIcons.search, color: colors.textSecondary),
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
                    final cat = categories[index];
                    final isSel = _selectedLawCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSel,
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _selectedLawCategory = cat;
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
              ? Center(child: Text('Ничего не найдено', style: textStyles.captionSans))
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
                          style: textStyles.bodySans.copyWith(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          law.category ?? 'Законодательство',
                          style: textStyles.captionSans.copyWith(color: colors.brand),
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
                                  Icon(TablerIcons.link, color: colors.brand, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Читать на официальном сайте',
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

  // --- 3. Вкладка Конструктор договоров ---
  Widget _buildConstructorTab(BuildContext context, LegalLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;

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
                Text('ДОКУМЕНТ СГЕНЕРИРОВАН', style: textStyles.bodySans.copyWith(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: Icon(TablerIcons.x, color: colors.textSecondary),
                  onPressed: () {
                    context.read<LegalBloc>().add(LoadLegalData());
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
                        state.generatedContract!.title,
                        style: textStyles.h2Sans.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Дата: ${state.generatedContract!.createdAt.toIso8601String().split('T').first}',
                        style: textStyles.captionSans.copyWith(color: colors.textSecondary),
                      ),
                      const Divider(height: 24),
                      Text(
                        state.generatedContract!.body,
                        style: textStyles.bodySans.copyWith(height: 1.5, fontFamily: 'monospace'),
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
                      Clipboard.setData(ClipboardData(text: state.generatedContract!.body));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Текст договора скопирован в буфер обмена')),
                      );
                    },
                    icon: const Icon(TablerIcons.copy),
                    label: const Text('Копировать текст'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.read<LegalBloc>().add(LoadLegalData());
                    },
                    icon: const Icon(TablerIcons.file_text),
                    label: const Text('Создать новый'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return state.isGenerating
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Генерация документа на основе реквизитов...'),
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
                            style: textStyles.bodySans.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Icon(TablerIcons.file_plus, color: colors.brand),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        template.category ?? 'Общий шаблон',
                        style: textStyles.captionSans.copyWith(color: colors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => _showGenerateForm(context, template),
                        child: const Text('Заполнить реквизиты'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  void _showGenerateForm(BuildContext context, ContractTemplate template) {
    final colors = context.colors;
    final textStyles = context.textStyles;
    final Map<String, String> values = {};
    final bloc = context.read<LegalBloc>();

    LedgerBottomSheet.show(
      context: context,
      title: 'Реквизиты для договора',
      builder: (context, setSheetState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              template.name,
              style: textStyles.captionSans.copyWith(color: colors.textSecondary),
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
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Check variables filled
                for (var v in template.variables) {
                  if (!values.containsKey(v.key) || values[v.key]!.trim().isEmpty) {
                    values[v.key] = '[${v.label} не указан]';
                  }
                }
                bloc.add(GenerateContractFromTemplate(
                  templateId: template.id,
                  variables: values,
                ));
                Navigator.pop(context);
              },
              child: const Text('Сгенерировать договор'),
            ),
          ],
        );
      },
    );
  }

  // --- 4. Вкладка Сроки ---
  Widget _buildDeadlinesTab(BuildContext context, LegalLoaded state) {
    final colors = context.colors;
    final textStyles = context.textStyles;

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
                  onChanged: (val) {
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
                          fontWeight: FontWeight.w600,
                          decoration: dl.isDone ? TextDecoration.lineThrough : null,
                          color: dl.isDone ? colors.textSecondary : colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Срок сдачи: ${dl.dueDate.toIso8601String().split('T').first} (${dl.daysLeft ?? 0} дн. осталось)',
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
                          style: textStyles.captionSans.copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                if (dl.amount != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    dl.amount!,
                    style: textStyles.bodyMono.copyWith(fontWeight: FontWeight.bold),
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
