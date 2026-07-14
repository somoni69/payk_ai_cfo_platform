import '../../../core/network/api_client.dart';
import '../domain/marketing_models.dart';
import '../domain/marketing_repository.dart';

class ApiMarketingRepository implements MarketingRepository {
  final ApiClient _apiClient = ApiClient();

  @override
  Future<List<MarketingCampaign>> getCampaigns() async {
    try {
      final response = await _apiClient.dio.get('/marketing/campaigns');
      final list = response.data as List<dynamic>;

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return MarketingCampaign(
          id: (map['id'] ?? '').toString(),
          name: map['name'] ?? '',
          channel: map['channel'],
          budget: double.tryParse((map['budget'] ?? '0').toString()) ?? 0.0,
          spent: double.tryParse((map['spent'] ?? '0').toString()) ?? 0.0,
          leads: (map['leads'] ?? 0) as int,
          conversions: (map['conversions'] ?? 0) as int,
          revenue: double.tryParse((map['revenue'] ?? '0').toString()) ?? 0.0,
          startedAt: map['started_at'] != null ? DateTime.parse(map['started_at']) : null,
          endedAt: map['ended_at'] != null ? DateTime.parse(map['ended_at']) : null,
          roi: double.tryParse((map['roi'] ?? '0').toString()) ?? 0.0,
          cac: map['cac'] != null ? double.tryParse(map['cac'].toString()) : null,
        );
      }).toList();
    } catch (e) {
      throw Exception('Не удалось загрузить рекламные кампании: ${e.toString()}');
    }
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
    try {
      final payload = {
        'name': name,
        'channel': channel,
        'budget': budget,
        'spent': spent,
        'leads': leads,
        'conversions': conversions,
        'revenue': revenue,
      };
      final response = await _apiClient.dio.post('/marketing/campaigns', data: payload);
      final map = response.data as Map<String, dynamic>;

      return MarketingCampaign(
        id: (map['id'] ?? '').toString(),
        name: map['name'] ?? '',
        channel: map['channel'],
        budget: double.tryParse((map['budget'] ?? '0').toString()) ?? 0.0,
        spent: double.tryParse((map['spent'] ?? '0').toString()) ?? 0.0,
        leads: (map['leads'] ?? 0) as int,
        conversions: (map['conversions'] ?? 0) as int,
        revenue: double.tryParse((map['revenue'] ?? '0').toString()) ?? 0.0,
        startedAt: map['started_at'] != null ? DateTime.parse(map['started_at']) : null,
        endedAt: map['ended_at'] != null ? DateTime.parse(map['ended_at']) : null,
        roi: double.tryParse((map['roi'] ?? '0').toString()) ?? 0.0,
        cac: map['cac'] != null ? double.tryParse(map['cac'].toString()) : null,
      );
    } catch (e) {
      throw Exception('Не удалось создать рекламную кампанию: ${e.toString()}');
    }
  }

  @override
  Future<List<SocialPost>> getPosts() async {
    try {
      final response = await _apiClient.dio.get('/marketing/posts');
      final dynamic responseData = response.data;
      final List<dynamic> list = responseData is Map<String, dynamic>
          ? (responseData['items'] as List<dynamic>? ?? [])
          : (responseData as List<dynamic>? ?? []);

      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return SocialPost(
          id: (map['id'] ?? '').toString(),
          text: map['text'] ?? '',
          imageUrl: map['image_url'],
          channel: map['channel'] ?? 'telegram',
          status: map['status'] ?? 'draft',
          scheduledAt: map['scheduled_at'] != null ? DateTime.parse(map['scheduled_at']) : null,
          publishedAt: map['published_at'] != null ? DateTime.parse(map['published_at']) : null,
          createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
        );
      }).toList();
    } catch (e) {
      throw Exception('Не удалось загрузить публикации: ${e.toString()}');
    }
  }

  @override
  Future<SocialPost> createPost({
    required String text,
    required String channel,
  }) async {
    try {
      final payload = {
        'text': text,
        'channel': channel,
      };
      final response = await _apiClient.dio.post('/marketing/posts', data: payload);
      final map = response.data as Map<String, dynamic>;

      return SocialPost(
        id: (map['id'] ?? '').toString(),
        text: map['text'] ?? '',
        imageUrl: map['image_url'],
        channel: map['channel'] ?? channel,
        status: map['status'] ?? 'draft',
        scheduledAt: map['scheduled_at'] != null ? DateTime.parse(map['scheduled_at']) : null,
        publishedAt: map['published_at'] != null ? DateTime.parse(map['published_at']) : null,
        createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      );
    } catch (e) {
      throw Exception('Не удалось создать публикацию: ${e.toString()}');
    }
  }

  @override
  Future<SocialPost> publishPost(String id) async {
    try {
      final response = await _apiClient.dio.post('/marketing/posts/$id/publish');
      final map = response.data as Map<String, dynamic>;

      return SocialPost(
        id: (map['id'] ?? '').toString(),
        text: map['text'] ?? '',
        imageUrl: map['image_url'],
        channel: map['channel'] ?? 'telegram',
        status: map['status'] ?? 'published',
        scheduledAt: map['scheduled_at'] != null ? DateTime.parse(map['scheduled_at']) : null,
        publishedAt: map['published_at'] != null ? DateTime.parse(map['published_at']) : null,
        createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      );
    } catch (e) {
      throw Exception('Не удалось опубликовать пост: ${e.toString()}');
    }
  }

  @override
  Future<List<String>> generateAiIdeas(String prompt) async {
    try {
      final payload = {'prompt': prompt};
      final response = await _apiClient.dio.post('/marketing/ai-ideas', data: payload);
      final map = response.data as Map<String, dynamic>;
      final list = (map['ideas'] ?? []) as List<dynamic>;

      return list.map((e) => e.toString()).toList();
    } catch (e) {
      throw Exception('Не удалось сгенерировать идеи: ${e.toString()}');
    }
  }

  @override
  Future<String> generateAiText(String prompt) async {
    try {
      final payload = {'prompt': prompt};
      final response = await _apiClient.dio.post('/marketing/ai-text', data: payload);
      final map = response.data as Map<String, dynamic>;

      return map['text'] ?? 'Нет сгенерированного текста';
    } catch (e) {
      throw Exception('Не удалось сгенерировать текст публикации: ${e.toString()}');
    }
  }
}
