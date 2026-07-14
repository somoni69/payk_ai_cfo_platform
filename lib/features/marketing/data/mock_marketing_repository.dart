import '../domain/marketing_models.dart';
import '../domain/marketing_repository.dart';

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
      text: 'Новое поступление высококачественного бетона марки М400. Доставка по Душанбе в течение 2 часов!',
      channel: 'telegram',
      status: 'published',
      publishedAt: DateTime(2026, 7, 5, 10, 0),
      createdAt: DateTime(2026, 7, 5, 9, 30),
    ),
    SocialPost(
      id: '2',
      text: 'Спешите заказать металлоконструкции любого уровня сложности. Цены снижены до конца недели!',
      channel: 'facebook',
      status: 'draft',
      createdAt: DateTime(2026, 7, 6, 14, 0),
    ),
  ];

  @override
  Future<List<MarketingCampaign>> getCampaigns() async {
    await Future.delayed(const Duration(milliseconds: 200));
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
    await Future.delayed(const Duration(milliseconds: 200));
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
  Future<List<SocialPost>> getPosts() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _posts;
  }

  @override
  Future<SocialPost> createPost({
    required String text,
    required String channel,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
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
  Future<SocialPost> publishPost(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
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
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      'Запустить таргет с акцентом на быструю доставку в Худжанде.',
      'Опубликовать видео-отзыв крупного застройщика о прочности бетона.',
      'Разослать спецпредложение постоянным клиентам через Telegram-бота.',
    ];
  }

  @override
  Future<String> generateAiText(String prompt) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return '🔥 Спецпредложение от PAYK! Только в этом месяце при заказе от 50 кубов бетона — бесплатная лабораторная проверка прочности на сжатие. Заказывайте прямо сейчас! 📞 +992 93 123 4567';
  }
}
