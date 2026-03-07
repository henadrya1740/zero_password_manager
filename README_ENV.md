# Конфигурация окружений

Этот проект поддерживает три режима работы: **dev** (разработка), **prod** (продакшен) и **local** (локальный IP).

## Файлы конфигурации

- `env.dev` - конфигурация для разработки (localhost:3000)
- `env.prod` - конфигурация для продакшена (192.168.1.130:3000)
- `env.local` - конфигурация для локального IP (192.168.1.130:3000)

## Запуск приложения

### Режим разработки (dev)
```bash
./run_dev.sh
```
или
```bash
flutter run --dart-define=ENVIRONMENT=dev
```

### Режим продакшена (prod)
```bash
./run_prod.sh
```
или
```bash
flutter run --dart-define=ENVIRONMENT=prod
```

## Сборка Android APK

### Сборка с локальным IP (рекомендуется для тестирования)
```bash
./build_android_local.sh
```
или
```bash
flutter build apk --dart-define=ENVIRONMENT=dev
```

### Продакшен сборка
```bash
./build_android_prod.sh
```
или
```bash
flutter build apk --dart-define=ENVIRONMENT=prod
```

## Настройка IP адреса

### Для локального IP (env.local)
Отредактируйте файл `env.local`:
```bash
# Измените IP адрес на нужный
API_BASE_URL=http://YOUR_LOCAL_IP:3000
```

### Для продакшена (env.prod)
Отредактируйте файл `env.prod`:
```bash
# Измените IP адрес на нужный
API_BASE_URL=http://YOUR_IP_ADDRESS:3000
```

## Структура конфигурации

В файле `lib/config/app_config.dart` определены все URL эндпоинты:

- `AppConfig.loginUrl` - авторизация
- `AppConfig.registerUrl` - регистрация  
- `AppConfig.passwordsUrl` - список паролей
- `AppConfig.generatePasswordUrl` - генерация пароля
- `AppConfig.importPasswordsUrl` - импорт паролей
- `AppConfig.getPasswordUrl(siteUrl)` - операции с конкретным паролем

## Проверка текущего окружения

В коде можно проверить текущее окружение:

```dart
if (AppConfig.isDevelopment) {
  print('Работаем в режиме разработки');
} else if (AppConfig.isProduction) {
  print('Работаем в продакшен режиме');
}
```

## Важные замечания

1. **Для локального IP**: Убедитесь, что ваш API сервер запущен на указанном IP адресе и порту
2. **Сетевая доступность**: Устройство, на котором будет запускаться APK, должно иметь доступ к вашему локальному IP
3. **Файрвол**: Проверьте, что порт 3000 открыт в файрволе 