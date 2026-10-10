import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payk_ai_cfo_platform/core/localization/language_cubit.dart';
import 'package:payk_ai_cfo_platform/core/theme/app_theme.dart';
import 'package:payk_ai_cfo_platform/features/meta/domain/meta_models.dart';
import 'package:payk_ai_cfo_platform/features/meta/presentation/meta_attachments.dart';
import 'package:payk_ai_cfo_platform/features/meta/presentation/meta_chat_widgets.dart';

MetaMessage _msg(int id, DateTime at, {bool out = false, String text = 'x'}) =>
    MetaMessage(id: id, outgoing: out, text: text, createdAt: at);

void main() {
  final language = LanguageCubit(initialLanguageCode: 'ru');

  group('day labels and time (Asia/Dushanbe)', () {
    // 2026-10-10 07:00 UTC = 12:00 in Dushanbe.
    final now = DateTime.utc(2026, 10, 10, 7);

    test('today, yesterday and «d month»', () {
      expect(
        metaDayLabel(DateTime.utc(2026, 10, 10, 1), now, language),
        'Сегодня',
      );
      expect(
        metaDayLabel(DateTime.utc(2026, 10, 9, 10), now, language),
        'Вчера',
      );
      expect(
        metaDayLabel(DateTime.utc(2026, 10, 3, 10), now, language),
        '3 октября',
      );
      expect(
        metaDayLabel(DateTime.utc(2025, 12, 31, 10), now, language),
        '31 декабря 2025',
      );
    });

    test('store day boundary, not UTC: 19:30 UTC is already tomorrow', () {
      expect(
        metaDayLabel(DateTime.utc(2026, 10, 9, 19, 30), now, language),
        'Сегодня',
      );
    });

    test('bubble shows only HH:mm on the store clock', () {
      expect(metaBubbleTime(DateTime.utc(2026, 10, 10, 7, 17)), '12:17');
      expect(metaBubbleTime(DateTime.utc(2026, 10, 9, 19, 5)), '00:05');
    });
  });

  group('buildMetaChatEntries', () {
    test('adds a chip per day and groups the same side within 5 min', () {
      final d1 = DateTime.utc(2026, 10, 9, 5);
      final d2 = DateTime.utc(2026, 10, 10, 5);
      final entries = buildMetaChatEntries([
        _msg(1, d1),
        _msg(2, d1.add(const Duration(minutes: 1))),
        _msg(3, d1.add(const Duration(minutes: 2)), out: true),
        _msg(4, d2),
        _msg(5, d2.add(const Duration(minutes: 20))),
      ]);
      expect(entries.whereType<MetaDayEntry>().length, 2);
      final msgs = entries.whereType<MetaMessageEntry>().toList();
      expect(msgs[0].firstInGroup && !msgs[0].lastInGroup, isTrue);
      expect(!msgs[1].firstInGroup && msgs[1].lastInGroup, isTrue);
      expect(msgs[2].firstInGroup && msgs[2].lastInGroup, isTrue);
      expect(msgs[4].firstInGroup, isTrue, reason: 'gap over 5 minutes');
      expect(entries.first, isA<MetaDayEntry>());
      expect(entries[4], isA<MetaDayEntry>());
    });
  });

  testWidgets('bubbles: HH:mm only, read ticks without the word', (
    tester,
  ) async {
    final at = DateTime.utc(2026, 10, 10, 7, 17);
    await tester.pumpWidget(
      BlocProvider.value(
        value: language,
        child: MaterialApp(
          theme: LedgerTheme.light,
          home: Scaffold(
            body: MetaMessageList(
              now: () => DateTime.utc(2026, 10, 10, 8),
              peerReadAt: at.add(const Duration(minutes: 1)),
              messages: [
                _msg(1, at, text: 'Салом'),
                _msg(2, at, out: true, text: 'Здравствуйте'),
                _msg(
                  3,
                  at.add(const Duration(minutes: 3)),
                  out: true,
                  text: 'Ещё',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Сегодня'), findsOneWidget);
    expect(find.text('12:17'), findsNWidgets(2));
    expect(find.text('10.10.2026 12:17'), findsNothing);
    expect(find.text('Прочитано'), findsNothing);
    Finder label(String text) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.label == text,
    );
    expect(label('Прочитано'), findsOneWidget);
    expect(label('Отправлено'), findsOneWidget);
  });

  test('location label in text is not repeated next to the card', () {
    const place = MetaAttachment(
      kind: 'location',
      lat: 38.5,
      lng: 68.7,
      label: 'MSX Алмоси (тест PAYK)',
    );
    expect(metaTextWithoutLabels('MSX Алмоси (тест PAYK)', [place]), '');
  });

  group('voice media path', () {
    test('own files go through the API with a leading slash', () {
      expect(metaMediaRequestPath('files/abc.ogg'), '/files/abc.ogg');
      expect(metaMediaRequestPath('/files/abc.ogg'), '/files/abc.ogg');
    });

    test('external CDN links never get the PAYK token', () {
      expect(metaMediaRequestPath('https://cdn.fbsbx.com/v.mp4'), isNull);
      expect(metaMediaRequestPath('http://x/y.ogg'), isNull);
      expect(metaMediaRequestPath('  '), isNull);
    });

    test('temp file keeps the extension and is filesystem safe', () {
      expect(metaAudioCacheName('/files/a b.ogg'), 'meta_audio_a_b.ogg');
      expect(metaAudioCacheName('files/voice.ogg?x=1'), 'meta_audio_voice.ogg');
      expect(metaAudioCacheName('files/'), 'meta_audio_voice');
    });

    test('clock shows m:ss', () {
      expect(metaAudioClock(const Duration(seconds: 75)), '1:15');
      expect(metaAudioClock(null), '0:00');
    });
  });
}
