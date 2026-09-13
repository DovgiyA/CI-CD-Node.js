# items-api

Node.js API для работы с Items в production-образе: Docker Image → Docker Hub → **Render** (Staging + Production), с GitHub Actions для проверок, публикации, сканирования и Deploy.

**Репозиторий:** https://github.com/DovgiyA/CI-CD-Node.js  
**Staging (Render):** https://items-api-latest.onrender.com  
**Production (Render):** https://items-api-production.onrender.com

## Что это

- **Приложение:** Express + Prisma + Postgres + TypeScript
- **Item:** `id`, `title`, `createdAt`
- **API:** `GET/POST /items`, `GET/PATCH/DELETE /items/:id`, `GET /health`

## Быстрый старт (локально)

> Если каталог репозитория содержит `:` в имени, на macOS/Linux ломается `PATH` у npm. Скрипты в `package.json` вызывают бинарники через `node ./node_modules/...`, поэтому локальные команды всё равно работают; лучше переименовать папку (например, в `CI-CD-node`).

```bash
cp .env.example .env
npm ci
docker compose up --build
# API: http://localhost:3000/health
```

Повторяемый smoke (health + создание/чтение Item; проверяет, что `DATABASE_URL` не зашит в Image):

```bash
npm run smoke:compose
```

Только приложение на хосте (Postgres через compose):

```bash
docker compose up -d db
npm ci
npx prisma migrate deploy
npm run dev
```

## Проверки

```bash
npm run lint
npm run typecheck
npm test
npm run build
```

## Переменные окружения

| Переменная     | Обязательна | Примечание                                      |
|----------------|-------------|-------------------------------------------------|
| `PORT`         | нет         | По умолчанию `3000`; Render подставляет свой    |
| `DATABASE_URL` | да          | Строка подключения к Postgres                   |
| `NODE_ENV`     | нет         | `production` в Image / на Render                |

Секреты не кладите в Image и не коммитьте в git. `DATABASE_URL` задайте на Render (привязка Free Postgres).

## CI/CD

| Триггер | Что происходит |
|---------|----------------|
| PR / push (не `main`) | ESLint, Vitest, `tsc`, проверка Prisma, CodeQL |
| Push в `main` | Те же проверки + `npm audit` (critical) → сборка Image → **Trivy CRITICAL** → push `sha-<commit>` + `latest` в Docker Hub → Deploy **Staging** на Render |
| Тег `v*` или `workflow_dispatch` | Deploy **Production** (одобрение GitHub Environment) на закреплённый Image на Render |

**Шлюз CodeQL:** job анализа загружает результаты; GitHub помечает check **Code scanning** как failed для алертов уровня **error** и выше. После создания репозитория включите защиту merge / ruleset, чтобы нерешённые Error (и выше) блокировали merge — так «CodeQL валит Pipeline» на практике (сам Action не завершается с ненулевым кодом из‑за находок).

**Миграции:** Render **pre-deploy command** запускает `node ./node_modules/prisma/build/index.js migrate deploy`. Локальный compose — единственное место, где migrate идёт сразу перед стартом процесса.

### Секреты GitHub

- `DOCKERHUB_USERNAME` — пользователь Docker Hub
- `DOCKERHUB_TOKEN` — access token (для push)
- `RENDER_API_KEY` — API-ключ Render
- `RENDER_STAGING_SERVICE_ID` — id Staging web service (`srv-…`)
- `RENDER_PRODUCTION_SERVICE_ID` — id Production web service (`srv-…`)

Секреты Docker Hub:

```bash
export DOCKERHUB_USERNAME='…'
export DOCKERHUB_TOKEN='…'
# FLY_API_TOKEN больше не используется — удалите его из GitHub, если ещё есть
sh scripts/setup-github-delivery-secrets.sh
```

Секреты Render (после bootstrap ниже):

```bash
export RENDER_API_KEY='rnd_…'
export RENDER_STAGING_SERVICE_ID='srv-…'
# export RENDER_PRODUCTION_SERVICE_ID='srv-…'  # когда появится Production
sh scripts/setup-render-secrets.sh
```

### GitHub Environments

Окружения **`staging`** и **`production`** (у production обязательный reviewer — владелец репозитория).

### Docker Hub

Публичный репозиторий: `DOCKERHUB_USERNAME/items-api`  
Теги: `sha-<12-символьный-sha>` (неизменяемый), `latest` (только с `main`).

## Настройка Render (один раз, free — без карты)

1. Зарегистрируйтесь на [render.com](https://render.com) (можно через GitHub).
2. **New → Postgres** → Free → имя, например `items-api-db-staging`.
3. **New → Web Service** → **Deploy an existing image from a registry**:
   - Image URL: `docker.io/adolgov321/items-api:latest` (подставьте своего пользователя Hub)
   - Instance: **Free**
   - Health check path: `/health`
4. **Environment**:
   - Добавьте `NODE_ENV=production`
   - Добавьте `DATABASE_URL` из Postgres (или «Link database»)
5. **Pre-Deploy Command:**
   ```text
   node ./node_modules/prisma/build/index.js migrate deploy
   ```
6. Один раз задеплойте из дашборда (подтянет `latest`).
7. Account → API Keys → создайте ключ.  
   Service → Settings → скопируйте **Service ID** (`srv-…`).
8. Запишите секреты в GitHub через `scripts/setup-render-secrets.sh`.

Для Production повторите шаги 2–6 (отдельное имя БД / отдельный web service) или используйте `.github/workflows/bootstrap-render-production.yml`.

CI вызывает Render `POST /v1/services/{id}/deploys` с `imageUrl=docker.io/…/items-api:sha-…`.

> Free web service засыпает без трафика; первый запрос может занять ~1 минуту. Free Postgres живёт 30 дней — для учебки нормально.

### Rollback (Production)

Тот же gated-workflow **Production deploy** — отдельный Pipeline не нужен.

1. Найдите предыдущий хороший Image на Docker Hub / в прошлых Deploy
2. Actions → **Production deploy** → Run workflow → укажите тег `sha-…` (или digest `sha256:…`)
3. Одобрите Environment `production`

Миграции **не** откатываются (`prisma migrate down` никогда не входит в Deploy). Для Render `imageUrl` предпочтительнее теги `sha-…`, если есть и тег, и digest.

## Устройство Image

- Multi-stage сборка, Node 22 bookworm-slim
- `npm ci` + `prisma generate` + `tsc`; в runtime — `npm prune --omit=dev`
- npm/npx убраны из финального Image (меньше размер и поверхность для Trivy)
- Пользователь без root (`nodejs`, uid 1001)
- `NODE_ENV=production`, слушает `0.0.0.0:$PORT`

## Вне скоупа

Явно не входит в этот репозиторий:

- Kubernetes / своя кластерная оркестрация
- Terraform / полный IaC сверх Actions и API/дашборда хоста
- APM, метрики, алерты, on-call
- Canary / blue-green по проценту трафика
- Multi-region / самостоятельно управляемый HA Postgres
- CDN, WAF, edge rate limiting
- Внешние secret managers (Vault и т.п.) сверх GitHub + Render
- Fly.io
