# Inbox RPi — Runbook

> Версия: 2025  
> Сервер: `user@your-rpi-ip` (RPi, WireGuard `10.8.0.x`)  
> Репозиторий: `~/inbox`

---

## Структура контейнеров

```
inbox-redis-1         – брокер очередей
inbox-transcriber-1   – Speech-to-Text (Parakeet v3)
inbox-web-1           – Rails web (порт 3000)
inbox-worker-1        – Sidekiq background jobs
```

Проверить статус:

```bash
docker compose ps
```

---

## 1. Обновление кода (git pull → перезапуск)

После `git push origin main` на локальной машине, на RPi:

```bash
cd ~/inbox
git pull origin main
docker compose -f docker-compose.yml -f docker-compose.production.yml --env-file .env.production build web worker
docker compose -f docker-compose.yml -f docker-compose.production.yml --env-file .env.production up -d web worker
```

Проверить, что поднялось:

```bash
docker compose ps
docker compose logs web --tail=30
```

---

## 2. Миграции базы данных

Запустить после обновления кода (когда в `db/migrate/` появились новые файлы):

```bash
docker compose exec web rails db:migrate
```

Проверить применённые миграции:

```bash
docker compose exec web rails db:migrate:status
```

Откат последней миграции (при необходимости):

```bash
docker compose exec web rails db:rollback
```

---

## 3. Перезапуск отдельных сервисов

```bash
# Только web
docker compose restart web

# Только worker (background jobs)
docker compose restart worker

# Только transcriber
docker compose restart transcriber

# Все сразу
docker compose restart
```

---

## 4. Просмотр логов

```bash
# Текущие логи web
docker compose logs web --tail=50 -f

# Логи worker (Sidekiq jobs)
docker compose logs worker --tail=50 -f

# Логи transcriber
docker compose logs transcriber --tail=30

# Все сервисы сразу
docker compose logs --tail=20
```

---

## 6. Запуск job вручную (для тестирования)

```bash
# Транскрибация (проверка)
docker compose exec web rails runner 'TranscribeAudioJob.perform_now("<path>")'

# Новости — fetch и digest
docker compose exec web rails runner 'FetchNewsJob.perform_now'
docker compose exec web rails runner 'SendNewsDigestJob.perform_now'

# Синхронизация Google Calendar
docker compose exec web rails runner 'GoogleCalendarSyncJob.perform_now'

# Напоминания (проверка)
docker compose exec web rails runner 'SendEventReminderJob.perform_now'
```

---

## 7. ENV переменные

Хранятся в `~/inbox/.env.production` на RPi.

Редактировать:

```bash
nano ~/inbox/.env.production
```

После изменения ENV — перезапустить соответствующий сервис:

```bash
docker compose up -d web worker   # пересоздаёт контейнеры с новыми ENV
```

> ⚠️ `docker compose restart` НЕ применяет изменения ENV — нужен `up -d`.

---

## 8. Полная пересборка (при изменении Gemfile или Dockerfile)

```bash
cd ~/inbox
git pull origin main
docker compose -f docker-compose.yml -f docker-compose.production.yml --env-file .env.production build --no-cache web worker
docker compose -f docker-compose.yml -f docker-compose.production.yml --env-file .env.production up -d
docker compose -f docker-compose.yml -f docker-compose.production.yml --env-file .env.production exec web bin/rails db:migrate
```

---

## 9. Добавление новой recurring job (SolidQueue)

1. Создать job-класс в `app/jobs/`
2. Добавить в `config/recurring.yml`:
   ```yaml
   production:
     my_new_job:
       class: MyNewJob
       schedule: every 15 minutes # или: at 2am every day
   ```
3. Перезапустить worker:
   ```bash
   docker compose restart worker
   ```
4. Проверить, что job появилась в расписании:
   ```bash
   docker compose exec web rails runner 'puts SolidQueue::RecurringTask.pluck(:key, :schedule)'
   ```

---

## 10. Rails console (отладка)

```bash
docker compose exec web rails console
```

Примеры:

```ruby
# Последний документ
Document.last

# Все CalendarEvent
CalendarEvent.order(:start_at).limit(10)

# Проверить тег
Tag.find_by(name: 'todo')
```

---

## 11. Transcriber — смена языка

По умолчанию Parakeet v3 определяет язык автоматически (25 языков, включая русский и английский).  
Принудительно задать язык (в `.env.production`):

```
TRANSCRIBER_LANGUAGE=ru
```

После — пересоздать контейнер:

```bash
docker compose up -d transcriber
```

---

## 12. Полный стоп / старт

```bash
# Стоп всего
docker compose down

# Старт всего
docker compose -f docker-compose.yml -f docker-compose.production.yml --env-file .env.production up -d

# Старт с логами (foreground)
docker compose -f docker-compose.yml -f docker-compose.production.yml --env-file .env.production up
```

---

## 13. Важно: всегда использовать `--env-file`

Docker Compose **по умолчанию читает `.env`**, но не `.env.production`.

**Всегда** используй полную команду:

```bash
docker compose -f docker-compose.yml -f docker-compose.production.yml --env-file .env.production <команда>
```

Без `--env-file .env.production` → `SECRET_KEY_BASE` не передаётся → Rails падает при старте.
