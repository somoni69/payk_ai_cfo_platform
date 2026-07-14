import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import '../../core/theme/theme_extensions.dart';
import '../../features/marketing/bloc/marketing_bloc.dart';
import '../../features/marketing/bloc/marketing_event.dart';
import '../../features/marketing/bloc/marketing_state.dart';
import '../../features/marketing/domain/marketing_repository.dart';
import '../widgets/ledger_card.dart';
import '../widgets/ledger_pill.dart';

class MarketingScreen extends StatelessWidget {
  const MarketingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MarketingBloc>(
      create: (context) => MarketingBloc(context.read<MarketingRepository>())..add(LoadMarketingData()),
      child: const MarketingView(),
    );
  }
}

class MarketingView extends StatefulWidget {
  const MarketingView({super.key});

  @override
  State<MarketingView> createState() => _MarketingViewState();
}

class _MarketingViewState extends State<MarketingView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _postController = TextEditingController();
  String _selectedChannel = 'telegram';
  bool _generatePostTextMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _promptController.dispose();
    _postController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text(
          'AI-Маркетинг и Соцсети',
          style: textStyles.h2Sans.copyWith(fontWeight: FontWeight.w500),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colors.brand,
          labelColor: colors.brand,
          unselectedLabelColor: colors.textSecondary,
          labelStyle: textStyles.bodySans.copyWith(fontWeight: FontWeight.w500),
          tabs: const [
            Tab(text: 'ИИ-Копирайтер'),
            Tab(text: 'Кампании'),
            Tab(text: 'Посты'),
          ],
        ),
      ),
      body: BlocListener<MarketingBloc, MarketingState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
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
    );
  }

  Widget _buildAiWriterTab(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return BlocBuilder<MarketingBloc, MarketingState>(
      builder: (context, state) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Сгенерируйте продающие слоганы, идеи рекламных постов или готовый текстовый контент для соцсетей компании с помощью ИИ.',
              style: textStyles.captionSans.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 16),

            // Режим генерации
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Идеи рекламы'),
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
                    label: const Text('Готовый пост'),
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
                    ? 'Напиши рекламный пост о скидках на кирпичи...'
                    : 'Слоганы для цементного завода...',
                fillColor: colors.surface,
                filled: true,
              ),
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: state.isGenerating
                  ? null
                  : () {
                      final prompt = _promptController.text.trim();
                      if (prompt.isEmpty) return;

                      if (_generatePostTextMode) {
                        context.read<MarketingBloc>().add(GenerateTextRequested(prompt));
                      } else {
                        context.read<MarketingBloc>().add(GenerateIdeasRequested(prompt));
                      }
                    },
              icon: const Icon(TablerIcons.sparkles),
              label: Text(state.isGenerating ? 'ИИ думает...' : 'Создать контент'),
            ),
            const SizedBox(height: 24),

            if (state.isGenerating)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (!_generatePostTextMode && state.generatedIdeas.isNotEmpty) ...[
                Text('СГЕНЕРИРОВАННЫЕ ИДЕИ', style: textStyles.smallSans),
                const SizedBox(height: 8),
                LedgerCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: state.generatedIdeas
                        .map((idea) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(TablerIcons.bulb, color: colors.brand, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(idea, style: textStyles.bodySans)),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ] else if (_generatePostTextMode && state.generatedText != null) ...[
                Text('ТЕКСТ ПУБЛИКАЦИИ', style: textStyles.smallSans),
                const SizedBox(height: 8),
                LedgerCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(state.generatedText!, style: textStyles.bodySans),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(TablerIcons.copy),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: state.generatedText!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Скопировано в буфер обмена')),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(TablerIcons.file_plus),
                            onPressed: () {
                              context.read<MarketingBloc>().add(CreatePostRequested(
                                    text: state.generatedText!,
                                    channel: 'telegram',
                                  ));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Пост сохранен в черновики')),
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

    return BlocBuilder<MarketingBloc, MarketingState>(
      builder: (context, state) {
        if (state.isCampaignsLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Scaffold(
          floatingActionButton: FloatingActionButton(
            backgroundColor: colors.brand,
            onPressed: () => _showCreateCampaignDialog(context),
            child: const Icon(TablerIcons.plus, color: Colors.white),
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              context.read<MarketingBloc>().add(LoadMarketingData());
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (state.campaigns.isEmpty)
                  const Center(child: Text('Рекламные кампании не созданы'))
                else
                  ...state.campaigns.map((camp) {
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
                                Expanded(
                                  child: Text(
                                    camp.name,
                                    style: textStyles.bodySans.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                LedgerPill(
                                  text: camp.channel?.toUpperCase() ?? 'NONE',
                                  backgroundColor: colors.brand.withValues(alpha: 0.1),
                                  textColor: colors.brand,
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildStatColumn('Бюджет', '${camp.budget.toStringAsFixed(0)} TJS', textStyles, colors),
                                _buildStatColumn('Потрачено', '${camp.spent.toStringAsFixed(0)} TJS', textStyles, colors),
                                _buildStatColumn('Лиды', '${camp.leads}', textStyles, colors),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildStatColumn('Продажи', '${camp.conversions}', textStyles, colors),
                                _buildStatColumn('ROI', '${camp.roi.toStringAsFixed(1)}%', textStyles, colors),
                                _buildStatColumn('CAC', camp.cac != null ? '${camp.cac!.toStringAsFixed(1)} TJS' : '—', textStyles, colors),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPostsTab(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    return BlocBuilder<MarketingBloc, MarketingState>(
      builder: (context, state) {
        if (state.isPostsLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Scaffold(
          floatingActionButton: FloatingActionButton(
            backgroundColor: colors.brand,
            onPressed: () => _showCreatePostDialog(context),
            child: const Icon(TablerIcons.plus, color: Colors.white),
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              context.read<MarketingBloc>().add(LoadMarketingData());
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (state.posts.isEmpty)
                  const Center(child: Text('Черновиков или постов не найдено'))
                else
                  ...state.posts.map((post) {
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
                                  backgroundColor: colors.brand.withValues(alpha: 0.1),
                                  textColor: colors.brand,
                                ),
                                LedgerPill(
                                  text: isDraft ? 'Черновик' : 'Опубликован',
                                  backgroundColor: isDraft ? colors.accentAmber.withValues(alpha: 0.1) : colors.accentGreen.withValues(alpha: 0.1),
                                  textColor: isDraft ? colors.accentAmber : colors.accentGreen,
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
                                  'Создан: ${post.createdAt.day}.${post.createdAt.month} ${post.createdAt.hour}:${post.createdAt.minute}',
                                  style: textStyles.captionSans.copyWith(color: colors.textSecondary),
                                ),
                                if (isDraft)
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      context.read<MarketingBloc>().add(PublishPostRequested(post.id));
                                    },
                                    icon: const Icon(TablerIcons.send, size: 16),
                                    label: const Text('В Telegram', style: TextStyle(fontSize: 12)),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(String label, String val, dynamic textStyles, dynamic colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textStyles.captionSans.copyWith(color: colors.textSecondary)),
        const SizedBox(height: 2),
        Text(val, style: textStyles.bodyMono.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showCreateCampaignDialog(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    final nameCtrl = TextEditingController();
    final budgetCtrl = TextEditingController();
    final spentCtrl = TextEditingController();
    final leadsCtrl = TextEditingController();
    final convCtrl = TextEditingController();
    final revCtrl = TextEditingController();
    String channel = 'telegram';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      builder: (bCtx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Новая рекламная кампания', style: textStyles.h2Sans),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Название кампании'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: channel,
                  items: const [
                    DropdownMenuItem(value: 'telegram', child: Text('Telegram')),
                    DropdownMenuItem(value: 'instagram', child: Text('Instagram')),
                    DropdownMenuItem(value: 'facebook', child: Text('Facebook')),
                  ],
                  onChanged: (val) {
                    if (val != null) channel = val;
                  },
                  decoration: const InputDecoration(labelText: 'Канал'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: budgetCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Бюджет (TJS)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: spentCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Потрачено (TJS)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: leadsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Количество Лидов'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: convCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Количество Продаж'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: revCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Полученная выручка (TJS)'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;

                    context.read<MarketingBloc>().add(CreateCampaignRequested(
                          name: name,
                          channel: channel,
                          budget: double.tryParse(budgetCtrl.text) ?? 0.0,
                          spent: double.tryParse(spentCtrl.text) ?? 0.0,
                          leads: int.tryParse(leadsCtrl.text) ?? 0,
                          conversions: int.tryParse(convCtrl.text) ?? 0,
                          revenue: double.tryParse(revCtrl.text) ?? 0.0,
                        ));

                    Navigator.pop(bCtx);
                  },
                  child: const Text('Создать'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCreatePostDialog(BuildContext context) {
    final colors = context.colors;
    final textStyles = context.textStyles;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      builder: (bCtx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Новая публикация', style: textStyles.h2Sans),
              const SizedBox(height: 16),
              TextField(
                controller: _postController,
                maxLines: 4,
                decoration: const InputDecoration(hintText: 'Текст публикации...'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedChannel,
                items: const [
                  DropdownMenuItem(value: 'telegram', child: Text('Telegram')),
                  DropdownMenuItem(value: 'instagram', child: Text('Instagram')),
                  DropdownMenuItem(value: 'facebook', child: Text('Facebook')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedChannel = val;
                    });
                  }
                },
                decoration: const InputDecoration(labelText: 'Канал публикации'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final text = _postController.text.trim();
                  if (text.isEmpty) return;

                  context.read<MarketingBloc>().add(CreatePostRequested(
                        text: text,
                        channel: _selectedChannel,
                      ));

                  _postController.clear();
                  Navigator.pop(bCtx);
                },
                child: const Text('Сохранить черновик'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
