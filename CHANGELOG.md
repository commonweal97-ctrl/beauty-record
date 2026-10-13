# Changelog

Все значимые изменения проекта Б-Запись (Flutter-клиент).
Формат основан на [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/).

## [Unreleased]

### Planned
- Телефония: подключить реальный провайдер (webhook `/api/auth/call-verification`) — сейчас работает только через curl-тест.
- Firebase keys → ENV (сейчас захардкожены в `main.dart`).
- `badCertificateCallback = true` — MITM-риск, отключить.
- WebAuthn на клиенте (backend готов).
- «Крупный шрифт» / accessibility-режим.
- Вычитка UI-текстов (канцелярит, шаблоны «Ошибка...», «Нет...»).
- Email не приходит — разобраться с MailService / SMTP / логами (на сервере).

---

## [2026-10-13]

### Added
- **Кнопка «Выйти из аккаунта»** на `PinLoginScreen` (`89d5837`) — раньше был тупик, если забыл PIN.
- **Сохранение `user_phone` в SharedPreferences** (`f5197ba`) — `AuthService.saveLogin` / `getSavedLogin` / `clearLogin`.
- **Поле `phone` в `PinLoginScreen`** (`f5197ba`) — передаётся в `OtpScreen`.

### Changed
- **`UserProvider.setUser`** (`f5197ba`) — принимает опциональный `phone`, прокидывает в `saveLogin`.
- **`login_screen.dart`** (`f5197ba`) — передаёт `phone` в `PinLoginScreen` при `hasPin=true` и в auto-login.
- **Маска email на OTP-экране** (`bfda988`) — формат `ro*****12@gmail.com` (2 символа + 5 звёздочек + 2 символа до `@`).
- **Текст на OTP-экране** (`bfda988`) — добавлено «и в приложение Б-Рощи».

### Fixed
- **Чёрный экран при «Назад» с OTP** (`89d5837`) — `Navigator.pop` при пустом стеке (`pushReplacement` / `pushAndRemoveUntil`). Теперь — безопасный `canPop` + fallback на `LoginScreen`.
- **Пустой email на OTP-экране** (`bfda988`, `9838969` сервер) — `/api/auth/check` теперь возвращает `user_email` и `user_phone`.
- **Кнопка «Подтвердить по звонку» неактивна** (`f5197ba`) — `phone` теперь передаётся из `PinLoginScreen` и из `SharedPreferences`.

### Removed
- **Offline-баннер «Нет подключения к интернету»** (`dc10cbe`) — показывался некорректно, загораживал UI, текст-канцелярит.
- **`ConnectivityService`** (`dc10cbe`) — удалён целиком.
- **`connectivity_plus`** (`dc10cbe`) — удалён из `pubspec.yaml`.

### Docs
- **`CHANGELOG.md`** — создан.

---

## [2026-10-12]

### Added
- **Flutter-проект** — init (ранее).

### Changed
- **Б-Запись** — миграция на `feature/single-screen-booking`.

### Fixed
- **`feat(booking): экран назначения мастеров`** (`14cecc2`) — `BookingMasterAssignmentStep`.

---

## Ссылки

- Сервер (backend SAS): `~/zapisj.bjyutiroscha.rf/public_html`
- Flutter-эталон (Б-Роща): `~/Documents/beauty_rosha`
- Серверный эталон (razrabotka): `~/razrabotka/public_html`

### Серверные коммиты (SAS)
- `9838969` fix(auth): возвращать user_email и user_phone из `/api/auth/check`
- `44977d6` docs(changelog): CSP-фиксы
- `cf2c94e` fix(twig): nonce для инлайн-скриптов
- `d19c663` fix(twig): вынести CSS статических страниц в `assets/css/pages/`
