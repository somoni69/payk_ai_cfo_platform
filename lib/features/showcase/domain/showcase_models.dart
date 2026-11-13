const showcaseArts = [
  'sparkles',
  'receipt',
  'cart',
  'speech',
  'gem',
  'money-bag',
  'trophy',
  'gear',
  'telephone',
  'crown',
];

class ShowcaseCard {
  const ShowcaseCard({
    required this.id,
    required this.titleTj,
    required this.titleRu,
    required this.textTj,
    required this.textRu,
    required this.imagePath,
    required this.imageUrl,
    required this.art,
    required this.startsOn,
    required this.endsOn,
    required this.isActive,
    required this.state,
    required this.views,
    required this.leads,
  });

  final int id;
  final String titleTj;
  final String titleRu;
  final String textTj;
  final String textRu;
  final String? imagePath;
  final String? imageUrl;
  final String art;
  final String? startsOn;
  final String? endsOn;
  final bool isActive;
  final String state;
  final int views;
  final int leads;

  String title(String languageCode) => languageCode == 'tg' ? titleTj : titleRu;

  String text(String languageCode) => languageCode == 'tg' ? textTj : textRu;

  factory ShowcaseCard.fromJson(Map<String, dynamic> json) {
    return ShowcaseCard(
      id: _int(json['id']),
      titleTj: '${json['title_tj'] ?? ''}',
      titleRu: '${json['title_ru'] ?? ''}',
      textTj: '${json['text_tj'] ?? ''}',
      textRu: '${json['text_ru'] ?? ''}',
      imagePath: json['image_path']?.toString(),
      imageUrl: json['image_url']?.toString(),
      art: '${json['art'] ?? 'sparkles'}',
      startsOn: json['starts_on']?.toString(),
      endsOn: json['ends_on']?.toString(),
      isActive: json['is_active'] == true,
      state: '${json['state'] ?? 'off'}',
      views: _int(json['views']),
      leads: _int(json['leads']),
    );
  }

  Map<String, dynamic> toInput() => {
    'title_tj': titleTj,
    'title_ru': titleRu,
    'text_tj': textTj,
    'text_ru': textRu,
    'image_path': imagePath,
    'art': art,
    'starts_on': startsOn,
    'ends_on': endsOn,
    'is_active': isActive,
  };
}

class ShowcaseTotals {
  const ShowcaseTotals({
    required this.live,
    required this.viewers,
    required this.leads,
    required this.leadsToday,
  });

  final int live;
  final int viewers;
  final int leads;
  final int leadsToday;

  factory ShowcaseTotals.fromJson(Map<String, dynamic> json) {
    return ShowcaseTotals(
      live: _int(json['live']),
      viewers: _int(json['viewers']),
      leads: _int(json['leads']),
      leadsToday: _int(json['leads_today']),
    );
  }
}

class ShowcaseList {
  const ShowcaseList({
    required this.today,
    required this.cards,
    required this.totals,
  });

  final String today;
  final List<ShowcaseCard> cards;
  final ShowcaseTotals totals;

  factory ShowcaseList.fromJson(Map<String, dynamic> json) {
    final raw = json['cards'];
    return ShowcaseList(
      today: '${json['today'] ?? ''}',
      cards: raw is List
          ? [
              for (final item in raw)
                if (item is Map)
                  ShowcaseCard.fromJson(Map<String, dynamic>.from(item)),
            ]
          : const [],
      totals: ShowcaseTotals.fromJson(
        json['totals'] is Map
            ? Map<String, dynamic>.from(json['totals'] as Map)
            : const {},
      ),
    );
  }
}

class ShowcaseImage {
  const ShowcaseImage({required this.path, required this.url});

  final String path;
  final String url;

  factory ShowcaseImage.fromJson(Map<String, dynamic> json) {
    return ShowcaseImage(
      path: '${json['image_path'] ?? ''}',
      url: '${json['image_url'] ?? ''}',
    );
  }
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}
