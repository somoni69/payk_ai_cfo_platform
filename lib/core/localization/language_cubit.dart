import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:payk_ai_cfo_platform/core/network/api_client.dart';
import 'package:payk_ai_cfo_platform/core/localization/catalogs/ru_catalog.dart';
import 'package:payk_ai_cfo_platform/core/localization/catalogs/tg_catalog.dart';
import 'package:payk_ai_cfo_platform/core/localization/catalogs/tajik_runtime_messages.dart';

/// Cubit для управления текущим языком локализации (RU / TJ) (SYS-08 / SYS-09).
class LanguageCubit extends Cubit<Locale> {
  static const supportedLanguageCodes = {'ru', 'tg'};
  static const _storageKey = 'interface_language';

  static const Map<String, Map<String, String>> kLocaleCatalogs = {
    'ru': kRussianCatalog,
    'tg': kTajikCatalog,
  };

  final FlutterSecureStorage? storage;
  int _selectionRevision = 0;
  Future<void> _persistenceQueue = Future<void>.value();

  LanguageCubit({this.storage, String? initialLanguageCode})
    : super(Locale(_initialLanguage(initialLanguageCode))) {
    ApiClient().cacheInterfaceLanguage(state.languageCode);
    if (initialLanguageCode == null ||
        !supportedLanguageCodes.contains(initialLanguageCode)) {
      _restoreLanguage();
    }
  }

  static String _initialLanguage(String? languageCode) {
    return supportedLanguageCodes.contains(languageCode) ? languageCode! : 'ru';
  }

  Future<void> setLanguage(String langCode) async {
    if (isClosed || !supportedLanguageCodes.contains(langCode)) {
      return;
    }

    _selectionRevision++;
    if (state.languageCode != langCode) {
      emit(Locale(langCode));
    }
    ApiClient().cacheInterfaceLanguage(langCode);

    final storage = this.storage;
    if (storage == null) return;

    final persistence = _persistenceQueue.then((_) async {
      try {
        await storage.write(key: _storageKey, value: langCode);
      } catch (_) {
        // The interface still switches if secure storage is unavailable.
      }
    });
    _persistenceQueue = persistence;
    await persistence;
  }

  Future<void> _restoreLanguage() async {
    final selectionRevision = _selectionRevision;
    String? savedLanguage;
    try {
      savedLanguage = await storage?.read(key: _storageKey);
    } catch (_) {
      return;
    }
    if (isClosed || _selectionRevision != selectionRevision) return;

    if (savedLanguage != null &&
        supportedLanguageCodes.contains(savedLanguage) &&
        state.languageCode != savedLanguage) {
      ApiClient().cacheInterfaceLanguage(savedLanguage);
      emit(Locale(savedLanguage));
    }
  }

  static const _messageCacheLimit = 512;
  final Map<String, String> _tajikMessageCache = {};

  static final RegExp _auditTitlePattern = RegExp(r'^Аудит системы: (.+)$');
  static final RegExp _auditDescriptionPattern = RegExp(
    r'^Пользователь (.+) совершил действие "(.+)" для сущности "(.*)"\. IP-адрес устройства: (.+)\.$',
  );
  static final RegExp _nightOperationPattern = RegExp(
    r'^Кассир #(.+) провел операцию на сумму (.+) TJS в ночное время \((.+)\)\. Рекомендуется проверить видеокамеры\.$',
  );
  static final RegExp _overdueTaskPattern = RegExp(
    r'^Задача "(.+)" просрочена\. Дедлайн: (.+)\. Срочно завершите ее или перенесите сроки\.$',
  );
  static final RegExp _productCreatedPattern = RegExp(
    r'^Товар "(.+)" успешно добавлен\.$',
  );
  static final RegExp _clientCreatedPattern = RegExp(
    r'^Клиент "(.+)" успешно зарегистрирован\.$',
  );
  static final RegExp _dealCreatedPattern = RegExp(
    r'^Сделка "(.+)" успешно открыта\.$',
  );
  static final RegExp _employeeCreatedPattern = RegExp(
    r'^Сотрудник "(.+)" успешно принят на работу\.$',
  );
  static final RegExp _payrollUpdatedPattern = RegExp(
    r'^Расчет по сотруднику "(.+)" успешно обновлен\.$',
  );
  static final RegExp _tajikReplacementPattern = RegExp(
    (kTajikMessageReplacements.keys.toList()
          ..sort((left, right) => right.length.compareTo(left.length)))
        .map(RegExp.escape)
        .join('|'),
  );

  String translateMessage(String message) {
    // Prefer catalog keys (e.g. error_timeout) for both locales.
    final byKey = translate(message);
    if (byKey != message) return byKey;

    if (state.languageCode != 'tg') {
      return message;
    }
    final cachedTranslation = _tajikMessageCache[message];
    if (cachedTranslation != null) {
      return cachedTranslation;
    }
    return _rememberTajikMessage(message, _translateMessageUncached(message));
  }

  String _translateMessageUncached(String message) {
    final exactTranslation = kTajikMessageTranslations[message];
    if (exactTranslation != null) {
      return exactTranslation;
    }

    final auditTitle = _auditTitlePattern.firstMatch(message);
    if (auditTitle != null) {
      return 'Аудити система: ${auditTitle[1]}';
    }

    final auditDescription = _auditDescriptionPattern.firstMatch(message);
    if (auditDescription != null) {
      return 'Корбар ${auditDescription[1]} амали "${auditDescription[2]}"-ро '
          'барои объекти "${auditDescription[3]}" анҷом дод. '
          'IP-суроғаи дастгоҳ: ${auditDescription[4]}.';
    }

    final nightOperation = _nightOperationPattern.firstMatch(message);
    if (nightOperation != null) {
      return 'Хазинадор #${nightOperation[1]} шабона (${nightOperation[3]}) '
          'ба маблағи ${nightOperation[2]} TJS амалиёт анҷом дод. '
          'Санҷидани камераҳо тавсия дода мешавад.';
    }

    final overdueTask = _overdueTaskPattern.firstMatch(message);
    if (overdueTask != null) {
      return 'Муҳлати вазифаи "${overdueTask[1]}" гузаштааст. '
          'Муҳлат: ${overdueTask[2]}. Онро фавран анҷом диҳед ё муҳлатро тағйир диҳед.';
    }

    final productCreated = _productCreatedPattern.firstMatch(message);
    if (productCreated != null) {
      return 'Моли "${productCreated[1]}" бомуваффақият илова шуд.';
    }

    final clientCreated = _clientCreatedPattern.firstMatch(message);
    if (clientCreated != null) {
      return 'Мизоҷи "${clientCreated[1]}" бомуваффақият ба қайд гирифта шуд.';
    }

    final dealCreated = _dealCreatedPattern.firstMatch(message);
    if (dealCreated != null) {
      return 'Муомилаи "${dealCreated[1]}" бомуваффақият кушода шуд.';
    }

    final employeeCreated = _employeeCreatedPattern.firstMatch(message);
    if (employeeCreated != null) {
      return 'Корманди "${employeeCreated[1]}" бомуваффақият ба кор қабул шуд.';
    }

    final payrollUpdated = _payrollUpdatedPattern.firstMatch(message);
    if (payrollUpdated != null) {
      return 'Ҳисоби корманди "${payrollUpdated[1]}" бомуваффақият нав шуд.';
    }

    final translated = message.replaceAllMapped(
      _tajikReplacementPattern,
      (match) => kTajikMessageReplacements[match.group(0)]!,
    );
    return translated;
  }

  String _rememberTajikMessage(String source, String translated) {
    if (_tajikMessageCache.length >= _messageCacheLimit &&
        !_tajikMessageCache.containsKey(source)) {
      _tajikMessageCache.remove(_tajikMessageCache.keys.first);
    }
    _tajikMessageCache[source] = translated;
    return translated;
  }

  String translate(String key, {Map<String, Object?> params = const {}}) {
    var value =
        kLocaleCatalogs[state.languageCode]?[key] ??
        kLocaleCatalogs['ru']?[key] ??
        key;
    for (final entry in params.entries) {
      value = value.replaceAll('{${entry.key}}', '${entry.value ?? ''}');
    }
    return value;
  }

  /// Resolves either a localization key (`error_*`) or a legacy Russian message.
  String resolveMessage(
    String message, {
    Map<String, Object?> params = const {},
  }) {
    final byKey = translate(message, params: params);
    if (byKey != message) return byKey;
    return translateMessage(message);
  }

  /// Selects a Russian-style one/few/many form and injects [count].
  ///
  /// Tajik catalog entries intentionally use the same noun form for all
  /// categories, while retaining symmetric keys with the Russian catalog.
  String translatePlural(
    String key,
    int count, {
    Map<String, Object?> params = const {},
  }) {
    final absoluteCount = count.abs();
    final mod10 = absoluteCount % 10;
    final mod100 = absoluteCount % 100;
    final category = mod10 == 1 && mod100 != 11
        ? 'one'
        : mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)
        ? 'few'
        : 'many';
    return translate(
      '${key}_$category',
      params: <String, Object?>{...params, 'count': count},
    );
  }

  static Set<String> get russianKeys =>
      Set.unmodifiable(kLocaleCatalogs['ru']!.keys);

  static Set<String> get tajikKeys =>
      Set.unmodifiable(kLocaleCatalogs['tg']!.keys);
}

/// Расширение для быстрого перевода в виджетах через `context.translate('key')`.
extension TranslationExtension on BuildContext {
  String translate(String key, {Map<String, Object?> params = const {}}) =>
      ReadContext(this).read<LanguageCubit>().translate(key, params: params);

  String resolveMessage(
    String message, {
    Map<String, Object?> params = const {},
  }) => ReadContext(
    this,
  ).read<LanguageCubit>().resolveMessage(message, params: params);
}
