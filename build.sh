#!/bin/bash
echo "Сборка Android APK с локальным IP (192.168.1.130)..."

# Собираем APK с локальной конфигурацией
flutter build apk --dart-define=ENVIRONMENT=prod

echo "APK собран в build/app/outputs/flutter-apk/app-release.apk"
echo "Приложение настроено на использование локального IP: 192.168.1.130:3000" 