import 'package:payk_ai_cfo_platform/features/marketing/domain/marketing_ai_models.dart';
import 'package:payk_ai_cfo_platform/features/marketing/domain/marketing_models.dart';
import 'package:payk_ai_cfo_platform/features/marketing/domain/marketing_repository.dart';

class MockMarketingRepository implements MarketingRepository {
  final List<MarketingCampaign> _campaigns = [
    MarketingCampaign(
      id: '1',
      name: 'Реклама цемента в Худжанде',
      channel: 'telegram',
      budget: 1500.0,
      spent: 1200.0,
      leads: 350,
      conversions: 45,
      revenue: 4500.0,
      startedAt: DateTime(2026, 6, 1),
      endedAt: DateTime(2026, 6, 30),
      roi: 275.0,
      cac: 26.6,
    ),
    MarketingCampaign(
      id: '2',
      name: 'Акция: Скидка 10% на арматуру',
      channel: 'instagram',
      budget: 800.0,
      spent: 800.0,
      leads: 180,
      conversions: 18,
      revenue: 1200.0,
      startedAt: DateTime(2026, 7, 1),
      roi: 50.0,
      cac: 44.4,
    ),
  ];

  final List<SocialPost> _posts = [
    SocialPost(
      id: '1',
      text:
          'Новое поступление высококачественного бетона марки М400. Доставка по Душанбе в течение 2 часов!',
      channel: 'telegram',
      status: 'published',
      publishedAt: DateTime(2026, 7, 5, 10, 0),
      createdAt: DateTime(2026, 7, 5, 9, 30),
    ),
    SocialPost(
      id: '2',
      text:
          'Спешите заказать металлоконструкции любого уровня сложности. Цены снижены до конца недели!',
      channel: 'facebook',
      status: 'draft',
      createdAt: DateTime(2026, 7, 6, 14, 0),
    ),
  ];

  @override
  Future<List<MarketingCampaign>> getCampaigns({
    bool forceRefresh = false,
  }) async {
    return _campaigns;
  }

  @override
  Future<MarketingCampaign> createCampaign({
    required String name,
    required String channel,
    required double budget,
    required double spent,
    required int leads,
    required int conversions,
    required double revenue,
  }) async {
    final newCamp = MarketingCampaign(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      channel: channel,
      budget: budget,
      spent: spent,
      leads: leads,
      conversions: conversions,
      revenue: revenue,
      startedAt: DateTime.now(),
      roi: spent > 0 ? ((revenue - spent) / spent) * 100 : 0.0,
      cac: conversions > 0 ? spent / conversions : 0.0,
    );
    _campaigns.insert(0, newCamp);
    return newCamp;
  }

  @override
  Future<List<SocialPost>> getPosts({bool forceRefresh = false}) async {
    return _posts;
  }

  @override
  Future<SocialPost> createPost({
    required String text,
    required String channel,
  }) async {
    final post = SocialPost(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      channel: channel,
      status: 'draft',
      createdAt: DateTime.now(),
    );
    _posts.insert(0, post);
    return post;
  }

  @override
  Future<void> deleteCampaign(String id) async {
    _campaigns.removeWhere((c) => c.id == id);
  }

  @override
  Future<void> deletePost(String id) async {
    _posts.removeWhere((p) => p.id == id);
  }

  @override
  Future<SocialPost> publishPost(String id) async {
    final idx = _posts.indexWhere((p) => p.id == id);
    if (idx != -1) {
      final updated = SocialPost(
        id: _posts[idx].id,
        text: _posts[idx].text,
        imageUrl: _posts[idx].imageUrl,
        channel: _posts[idx].channel,
        status: 'published',
        publishedAt: DateTime.now(),
        createdAt: _posts[idx].createdAt,
      );
      _posts[idx] = updated;
      return updated;
    }
    throw Exception('Пост не найден');
  }

  @override
  Future<List<String>> generateAiIdeas(String prompt) async {
    return [
      'Запустить таргет с акцентом на быструю доставку в Худжанде.',
      'Опубликовать видео-отзыв крупного застройщика о прочности бетона.',
      'Разослать спецпредложение постоянным клиентам через Telegram-бота.',
    ];
  }

  @override
  Future<String> generateAiText(String prompt) async {
    return '🔥 Спецпредложение от PAYK! Только в этом месяце при заказе от 50 кубов бетона — бесплатная лабораторная проверка прочности на сжатие. Заказывайте прямо сейчас! 📞 +992 93 123 4567';
  }

  BrandGuide _brandGuide = const BrandGuide(
    brandName: 'PAYK Shop',
    tone: 'Дружелюбный, профессиональный, надежный',
    audience: 'Строительные компании, прорабы, частные застройщики',
    forbidden: 'Скидки более 50%, недостоверные гарантии',
    videoLimitMonth: 10,
    learnedRounds: 3,
  );

  @override
  Future<BrandGuide> getBrandGuide({bool forceRefresh = false}) async {
    return _brandGuide;
  }

  @override
  Future<BrandGuide> updateBrandGuide(BrandGuide brandGuide) async {
    _brandGuide = brandGuide;
    return _brandGuide;
  }

  @override
  Future<List<MarketingIdea>> getAiIdeas({String lang = 'ru'}) async {
    return [
      const MarketingIdea(
        source: 'season',
        tag: 'Сезон',
        title: 'Сезонное промо стройматериалов',
        reason: 'Пик строительного сезона, высокий спрос на цемент и арматуру',
      ),
      const MarketingIdea(
        source: 'sales_drop',
        tag: 'Спад продаж',
        title: 'Спецпредложение на смеси М300',
        reason: 'Падение спроса на 15% за последние 14 дней',
      ),
      const MarketingIdea(
        source: 'stale_stock',
        tag: 'Склад',
        title: 'Ликвидация остатков кафеля',
        reason: 'На складе хранится более 45 дней без движения',
      ),
    ];
  }

  @override
  Future<MarketingCampaignAi> createAiCampaign({
    required String name,
    String? product,
    int? goalQty,
    int? goalDays,
    String? briefText,
    String? ideaSource,
  }) async {
    return MarketingCampaignAi(
      id: 'ai-camp-1',
      name: name,
      product: product,
      goalQty: goalQty,
      goalDays: goalDays,
      briefText: briefText,
      ideaSource: ideaSource,
      aiStatus: 'ideas_ready',
      createdAt: DateTime.now(),
      concepts: [
        MarketingConcept(
          id: 'concept-1',
          campaignId: 'ai-camp-1',
          variant: 'A',
          roundNo: 1,
          title: 'Эмоциональный ролик: Дом вашей мечты',
          storyline: 'Семья выбирает материалы для нового дома.',
          theses: 'Качество, долговечность, доставка за 2 часа.',
          tone: 'Вдохновляющий',
          format: 'Reels / Shorts 9:16',
          durationSec: 15,
          cta: 'Заказывайте в приложении со скидкой 5%',
          status: 'draft',
          createdAt: DateTime.now(),
        ),
        MarketingConcept(
          id: 'concept-2',
          campaignId: 'ai-camp-1',
          variant: 'B',
          roundNo: 1,
          title: 'Экспертный обзор: Почему М400 надежнее',
          storyline: 'Прораб на стройке тестирует бетон на прочность.',
          theses: 'Лабораторные испытания, ГОСТ стандарты.',
          tone: 'Деловой',
          format: 'Reels / Shorts 9:16',
          durationSec: 20,
          cta: 'Получите расчет сметы бесплатно',
          status: 'draft',
          createdAt: DateTime.now(),
        ),
      ],
    );
  }

  @override
  Future<List<MarketingConcept>> generateAiConcepts(String campaignId) async {
    return [
      MarketingConcept(
        id: 'concept-1',
        campaignId: campaignId,
        variant: 'A',
        roundNo: 1,
        title: 'Эмоциональный ролик: Надежный фундамент',
        storyline: 'Показ процессов стройки с акцентом на надежность.',
        theses: 'Гарантия 20 лет, быстрая отгрузка.',
        tone: 'Вдохновляющий',
        format: 'Reels 9:16',
        durationSec: 15,
        cta: 'Оставьте заявку сегодня',
        status: 'draft',
        createdAt: DateTime.now(),
      ),
      MarketingConcept(
        id: 'concept-2',
        campaignId: campaignId,
        variant: 'B',
        roundNo: 1,
        title: 'Прямое сравнение цен и выгоды',
        storyline: 'Калькулятор экономии при оптовом заказе.',
        theses: 'Оптовые цены от 10 тонн.',
        tone: 'Практичный',
        format: 'Пост с каруселью',
        durationSec: null,
        cta: 'Смотреть прайс-лист',
        status: 'draft',
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<MarketingConcept> reviseAiConcept({
    required String campaignId,
    required List<String> baseIds,
    required String note,
  }) async {
    return MarketingConcept(
      id: 'concept-rev-1',
      campaignId: campaignId,
      variant: 'Rev',
      roundNo: 2,
      title: 'Объединенный концепт с правками: $note',
      storyline: 'Комбинация эмоциональной подачи и экспертных расчетов.',
      theses: 'Надежность + калькулятор выгоды.',
      tone: 'Уверенный',
      format: 'Reels 9:16',
      durationSec: 18,
      cta: 'Узнайте вашу скидку в боте',
      status: 'draft',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<MarketingConcept> approveAiConcept(String conceptId) async {
    return MarketingConcept(
      id: conceptId,
      campaignId: 'ai-camp-1',
      variant: 'A',
      roundNo: 1,
      title: 'Утвержденный концепт',
      status: 'approved',
      approvedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<MarketingMediaAsset> generateAiScript(String conceptId) async {
    return MarketingMediaAsset(
      id: 'media-1',
      conceptId: conceptId,
      kind: 'video',
      version: 1,
      script:
          '0-3с: Крупный план заливки бетона.\n3-8с: Текст: Доставка за 2 часа.\n8-15с: Заказывайте в PAYK CFO!',
      postText:
          'Строите дом или объект? Заказывайте бетон высшей пробы с гарантией прочности. Доставка в день заказа по всему Душанбе!',
      firstComment:
          '📍 Наш адрес: Душанбе, ул. Айни 45\n📞 Связаться: +992 93 123 4567',
      status: 'ready',
      cost: 0.0,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<MarketingVideoQuota> getVideoQuota() async {
    return const MarketingVideoQuota(
      month: '2026-08',
      videoUsed: 2,
      videoLimit: 10,
      videoLeft: 8,
    );
  }

  @override
  Future<MarketingMediaAsset> generateAiMedia({
    required String mediaId,
    required String kind,
    bool confirm = true,
  }) async {
    return MarketingMediaAsset(
      id: mediaId,
      conceptId: 'concept-1',
      kind: kind,
      version: 1,
      fileUrl: 'https://example.com/generated_video.mp4',
      status: 'ready',
      cost: kind == 'video' ? 15.0 : 2.0,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> rejectAiMedia({
    required String mediaId,
    required String reason,
  }) async {
    return;
  }

  @override
  Future<List<MarketingPublicationStats>> getPublicationStats() async {
    return [
      const MarketingPublicationStats(
        publicationId: '101',
        comments: 48,
        authors: 35,
        intents: 18,
        prepaid: 8,
        purchases: 12,
        revenue: 8400.0,
        spend: 1200.0,
        roiPercent: 600.0,
        period: '2026-08-01 - 2026-08-15',
      ),
    ];
  }
}
