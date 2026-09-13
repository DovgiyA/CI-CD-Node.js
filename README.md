# items-api

Небольшое веб‑приложение: список записей (items) с проверкой «сервис жив».

Код проверяется в GitHub, упаковывается в контейнер, кладётся на Docker Hub и выкладывается на [Render](https://render.com): сначала тестовый адрес, потом боевой.

**Код:** https://github.com/DovgiyA/CI-CD-Node.js  
**Тестовый адрес:** https://items-api-latest.onrender.com  
**Боевой адрес:** https://items-api-production.onrender.com

## Возможности

- Создать, прочитать, изменить и удалить запись
- Поля записи: `id`, `title`, `createdAt`
- Адреса: `/items`, `/items/:id`, `/health`
- Стек: Node.js, Express, TypeScript, Postgres, Prisma

## Запуск на своём компьютере

> Если в имени папки есть символ `:`, некоторые команды npm на Mac/Linux могут сбоить. Лучше переименовать папку, например в `CI-CD-node`. В этом проекте скрипты уже обходят проблему.

Скопируйте настройки, поставьте зависимости и поднимите всё через Docker:

```bash
cp .env.example .env
npm ci
docker compose up --build
```

Проверка: откройте http://localhost:3000/health

Автопроверка (здоровье сервиса + создание и чтение записи; убеждается, что пароль к базе не зашит в контейнер):

```bash
npm run smoke:compose
```

Вариант без полного Docker‑стека (база в Docker, приложение на компьютере):

```bash
docker compose up -d db
npm ci
npx prisma migrate deploy
npm run dev
```

## Локальные проверки перед пушем

```bash
npm run lint
npm run typecheck
npm test
npm run build
```

## Настройки приложения

| Имя | Нужна ли | Зачем |
|-----|----------|--------|
| `PORT` | нет | Порт. По умолчанию `3000`. На Render задаётся сам |
| `DATABASE_URL` | да | Подключение к Postgres |
| `NODE_ENV` | нет | Обычно `production` на сервере |

Пароли и ключи не кладите в контейнер и не коммитьте в git. Строку к базе задайте в панели Render.

## Как устроена выкладка

| Когда | Что происходит |
|-------|----------------|
| Пуш или PR **не** в ветку `main` | Проверки кода (стиль, тесты, типы, Prisma, CodeQL). Контейнер **не** публикуется |
| Пуш в `main` | Те же проверки → проверка зависимостей → сборка контейнера → проверка безопасности (Trivy) → загрузка на Docker Hub → обновление **тестового** адреса на Render |
| Тег `v…` или ручной запуск workflow | Выкладка на **боевой** адрес. Нужно подтверждение человека в GitHub |

### CodeQL

Результаты уходят в GitHub. Чтобы «опасные» находки реально блокировали слияние PR, в настройках репозитория включите защиту ветки / правило для Code scanning. Сам шаг Actions из‑за находок с кодом ошибки не падает.

### Обновление схемы базы

На Render перед стартом новой версии выполняется:

```text
node ./node_modules/prisma/build/index.js migrate deploy
```

Локально в `docker compose` миграции тоже применяются при старте сервиса приложения. На сервере это делает команда перед выкладкой, а не сам процесс приложения при каждом запуске.

### Секреты в GitHub

Нужны для публикации контейнера и выкладки:

| Секрет | Смысл |
|--------|--------|
| `DOCKERHUB_USERNAME` | Логин Docker Hub |
| `DOCKERHUB_TOKEN` | Токен для загрузки образов |
| `RENDER_API_KEY` | Ключ API Render |
| `RENDER_STAGING_SERVICE_ID` | Id тестового сервиса (`srv-…`) |
| `RENDER_PRODUCTION_SERVICE_ID` | Id боевого сервиса (`srv-…`) |

Docker Hub:

```bash
export DOCKERHUB_USERNAME='…'
export DOCKERHUB_TOKEN='…'
sh scripts/setup-github-delivery-secrets.sh
```

Render (когда сервисы уже созданы):

```bash
export RENDER_API_KEY='rnd_…'
export RENDER_STAGING_SERVICE_ID='srv-…'
# export RENDER_PRODUCTION_SERVICE_ID='srv-…'
sh scripts/setup-render-secrets.sh
```

В GitHub заведены окружения `staging` и `production`. Для `production` требуется одобрение владельца репозитория.

Образы лежат публично: `ваш_логин/items-api`.  
Метки: `sha-…` (конкретная версия) и `latest` (только с ветки `main`).

## Один раз настроить Render (бесплатный тариф, карта не нужна)

1. Зарегистрируйтесь на [render.com](https://render.com).
2. Создайте бесплатную Postgres (например `items-api-db-staging`).
3. Создайте Web Service из готового образа с реестра:
   - URL образа: `docker.io/adolgov321/items-api:latest` (подставьте свой логин)
   - тариф Free
   - путь проверки здоровья: `/health`
4. В переменных сервиса задайте `NODE_ENV=production` и `DATABASE_URL` (или привяжите базу в интерфейсе).
5. В **Pre-Deploy Command** укажите:
   ```text
   node ./node_modules/prisma/build/index.js migrate deploy
   ```
6. Один раз запустите выкладку из панели Render.
7. Создайте API‑ключ в аккаунте и скопируйте Service ID сервиса.
8. Запишите секреты в GitHub скриптом `scripts/setup-render-secrets.sh`.

Боевой сервис делается так же отдельно (своя база / свой сервис) или через workflow `.github/workflows/bootstrap-render-production.yml`.

Дальше GitHub сам просит Render выложить нужную версию контейнера.

> На бесплатном тарифе сервис засыпает без запросов — первый ответ может идти около минуты. Бесплатная Postgres живёт 30 дней — для учёбы достаточно.

### Откат боевой версии

Отдельный процесс не нужен — снова запускаете **Production deploy**:

1. Найдите прошлую рабочую метку образа (`sha-…`) на Docker Hub или в истории выкладок.
2. Actions → **Production deploy** → Run workflow → введите эту метку.
3. Подтвердите окружение `production`.

Схему базы назад **не** откатываем. Меняется только контейнер приложения. Удобнее указывать метку `sha-…`, а не «сырой» digest.

## Как собран контейнер

- Сборка в несколько этапов, Node.js 22
- В финальном образе нет npm/npx (меньше размер и меньше замечаний сканера)
- Процесс идёт не от root
- Слушает адрес `0.0.0.0` и порт из `$PORT`

## Чего в проекте намеренно нет

- Kubernetes и свой кластер
- Terraform «на всё»
- Полноценный мониторинг и дежурства
- Постепенный canary / blue‑green по проценту трафика
- Несколько регионов и свой отказоустойчивый Postgres
- CDN, WAF, ограничение запросов на краю
- Отдельные хранилища секретов вроде Vault (кроме GitHub и Render)
- Fly.io
