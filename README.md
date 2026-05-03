# Speedreeder

Скорочтение (RSVP): слова по одному на экране. Веб и мобильные платформы Flutter.

**Прод:** [https://intellectshop.net/projects/speedreader/](https://intellectshop.net/projects/speedreader/)

## Возможности (MVP)

- Импорт **`.txt`** и **`.epub`** с устройства: EPUB разбирается на клиенте ([`epubx`](https://pub.dev/packages/epubx) + извлечение видимого текста из XHTML).
- Библиотека и **прогресс чтения** в `SharedPreferences` (без сервера).
- Скорость (слов/мин), размер и цвет слова, тема приложения (светлая / тёмная / как в системе).
- Боковое меню как у [«Алфавит»](https://intellectshop.net/alphabet/): язык **RU/EN**, тема, о приложении, советы, обратная связь (`/api-feedback`), Boosty, ссылка на проекты IntellectShop.
- Оформление в духе Telegram-темы alphabet.

## Ограничения хранилища

`SharedPreferences` не рассчитан на большие тексты: крупные **EPUB** после извлечения могут упереться в лимиты браузера/ОС. Для длинных книг лучше перейти на **Hive / Isar** и файлы на диске (на web — IndexedDB через готовые адаптеры).

## Дорожная карта

| Этап | Содержание |
|------|------------|
| ✓ | **EPUB (v2)** — распаковка и извлечение текста на клиенте |
| v3 | **PDF** — клиентский разбор или опциональный внешний сервис |
| ✓ | Локализация **RU/EN** (`easy_localization`, как в alphabet) |
| ✓ | Ссылка с [страницы проектов](https://intellectshop.net/projects/) (карточка во фронтенде) |

## CI/CD (GitHub Actions)

При пуше в `main` (изменения в `lib/`, `web/`, `test/`, `pubspec.*`) выполняется сборка `flutter build web --base-href /projects/speedreader/` и выкладка в каталог **`projects/speedreader`** на Timeweb.

**Секреты репозитория** (те же значения, что у [alphabet](https://github.com/unomat20b/alphabet), путь к сайту без суффикса приложения):

- `TIMEWEB_SSH_KEY`
- `TIMEWEB_HOST`
- `TIMEWEB_USER`
- `TIMEWEB_REMOTE_PATH` — корень `public_html` (например `/home/d/daysw/intellectshop.net/public_html`), **без** суффикса `/projects/speedreader` (он добавляется в workflow).

## Локальный запуск

```bash
flutter pub get
flutter run -d chrome
```

Веб-сборка с base-href как на сервере:

```bash
flutter build web --base-href /projects/speedreader/
```

## Первый push в новый репозиторий

```bash
cd speedreeder
git init
git add -A
git commit -m "Initial Speedreeder MVP + deploy workflow"
git branch -M main
git remote add origin https://github.com/<user>/speedreeder.git
git push -u origin main
```
