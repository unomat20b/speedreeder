# Speedreeder

Скорочтение (RSVP): слова по одному на экране. Веб и мобильные платформы Flutter.

**Прод:** [https://intellectshop.net/projects/speedreader/](https://intellectshop.net/projects/speedreader/)

## Возможности (MVP)

- Импорт **`.txt`** с устройства (текст хранится локально).
- Библиотека и **прогресс чтения** в `SharedPreferences` (без сервера).
- Скорость (слов/мин), размер и цвет слова, тема приложения (светлая / тёмная / как в системе).
- Оформление в духе проекта [«Алфавиты»](https://intellectshop.net/alphabet/).

## Ограничения хранилища

`SharedPreferences` не рассчитан на большие тексты. Для длинных книг и **EPUB** лучше перейти на **Hive / Isar** и файлы на диске (на web — IndexedDB через готовые адаптеры).

## Дорожная карта

| Этап | Содержание |
|------|------------|
| v2 | **EPUB** — распаковка и извлечение текста на клиенте |
| v3 | **PDF** — клиентский разбор или опциональный внешний сервис |
| — | Локализация (как `easy_localization` в alphabet) |
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
