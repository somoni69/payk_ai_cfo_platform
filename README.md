# PAYK CFO

Flutter-клиент финансовой платформы PAYK CFO. Интерфейс полностью поддерживает русский (`ru`) и таджикский (`tg`) языки, включая системный запрос Face ID на iOS.

## Локальный запуск

Требуются Flutter stable и Java 17.

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=https://api.example.com/api
```

По умолчанию используется настроенный production API. Другой адрес обязан использовать HTTPS. Для локального HTTP-сервера можно явно добавить `--dart-define=ALLOW_INSECURE_API=true`; этот флаг нельзя использовать в production.

В production также задайте ожидаемые JWT claims:

```text
--dart-define=JWT_ISSUER=<issuer>
--dart-define=JWT_AUDIENCE=<audience>
```

## Проверка качества

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Эти же проверки и debug APK выполняются в `.github/workflows/flutter_quality.yml`.

## Android release

1. Скопируйте `android/key.properties.example` в `android/key.properties`.
2. Укажите настоящий upload keystore и секреты. Не добавляйте их в Git.
3. Задайте неизменяемый production application ID через `PAYK_APPLICATION_ID`.
4. Соберите подписанный AAB:

```powershell
$env:PAYK_APPLICATION_ID = 'tj.yourcompany.paykcfo'
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.example.com/api
```

Release-сборка намеренно остановится при тестовом `com.example.*`, отсутствующем keystore или неполных параметрах подписи. `-PallowUnsafeRelease=true` предназначен только для локальной проверки компиляции и создаёт недистрибутивный APK с debug-подписью.

## iOS release

В Xcode откройте `ios/Runner.xcworkspace`, затем задайте настоящий Bundle Identifier и Apple Development Team для Runner. После этого соберите архив:

```text
flutter build ipa --release --dart-define=API_BASE_URL=https://api.example.com/api
```

Device release с `com.example.*` или без Development Team блокируется. `PAYK_ALLOW_UNSAFE_RELEASE=1` разрешён только для локальной проверки сборки, не для публикации.

Перед выпуском отдельно подтвердите production API, серверные RBAC/idempotency правила, Bundle/Application ID и ключи подписи.
