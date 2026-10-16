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

## [2026-10-14]

### Added
- **`AvatarInitials`** (`5a59de2`) — универсальный виджет-заглушка
  (буквы имени/фамилии в кружке) с настройкой размера и цвета.
- **`formatPhoneDisplay`** (`6510abd`) — красивое отображение телефона
  с флагом страны и форматом: `🇷🇺 +7 (920) 854-81-51`.
- **`name_utils.dart`** (`a4648a1`) — единый источник имени из map
  (`name` → `first_name last_name` → `Сотрудник`), убирает
  дублирование `_shortName` / `_employeeName`.

### Changed
- **`AvatarInitials` применён** везде (`5a59de2`, `1e29a46`, `e5ee7e2`, `a4648a1`):
  - клиенты: `clients_screen`, `client_profile_sheet`, `business_reviews_screen`;
  - мастера: `service_detail_modal`, `master_slot_card`, `master_card`,
    `booking_masters_step`, `booking_master_services_step`,
    `booking_success_step`, `booking_master_assignment_step`;
  - сотрудники: `employees_screen`, `schedule_view_screen`, `month_view_screen`,
    `journal_screen`, `online_booking_screen`, `manual_notification_sheet`;
  - чаты/уведомления: `chat_screen`, `notifications_screen`, `access_screen`;
  - `create_booking_sheet`, `create_booking_for_client_sheet`.
- **`formatPhoneDisplay` применён** в: `create_booking_sheet`, `chat_screen`,
  `list_view_screen`, `booking_view_sheet`, `manual_notification_sheet`,
  `clients_screen`, `client_profile_sheet`, `business_reviews_screen`,
  `booking_confirm_step`, `access_screen`, `journal_screen`, `profile_screen`.
- **`schedule_view_screen`**, **`month_view_screen`** — убраны локальные
  `_shortName` / `_employeeName`, используются `extractName` / `extractShortName`.

### Fixed
- **Overflow в попапе отложенной отправки** (`e5ee7e2`) —
  `manual_notification_sheet`: `Container` → `Material` (ListTile ink
  splashes), `Flexible + ListView` + `maxHeight 70%` (overflow 49px).
- **`?` вместо инициалов** (`a4648a1`) — в `schedule_view_screen`
  использовался `e['name']` без fallback на `first_name`/`last_name`.

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
