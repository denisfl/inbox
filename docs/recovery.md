# Database Recovery from Backup

## Prerequisites

- Docker access to the production environment
- Access to the backup storage (local path or S3 bucket)

## Step 1: Locate the Latest Backup

### Local storage

```bash
ls -la /app/storage/backups/
# or from outside Docker:
docker compose -f docker-compose.yml -f docker-compose.production.yml exec web ls -la storage/backups/
```

### S3 storage

```bash
aws s3 ls s3://YOUR_BUCKET/backups/ --endpoint-url YOUR_ENDPOINT
```

The most recent file named `backup_YYYYMMDD_HHMMSS.sql.gz` is your latest backup.

## Step 2: Download the Backup (if on S3)

```bash
aws s3 cp s3://YOUR_BUCKET/backups/backup_20260321_030000.sql.gz ./backup.sql.gz \
  --endpoint-url YOUR_ENDPOINT
```

## Step 3: Decompress

```bash
gunzip backup_20260321_030000.sql.gz
# Result: backup_20260321_030000.sql
```

## Step 4: Stop the Application

```bash
docker compose -f docker-compose.yml -f docker-compose.production.yml stop web sidekiq
```

## Step 5: Backup the Current (Corrupt) Database

```bash
docker compose -f docker-compose.yml -f docker-compose.production.yml exec web \
  cp storage/production.sqlite3 storage/production.sqlite3.corrupt
```

## Step 6: Restore from Backup

```bash
# Copy the SQL dump into the container
docker cp backup_20260321_030000.sql CONTAINER_NAME:/app/tmp/restore.sql

# Remove the current database and restore
docker compose -f docker-compose.yml -f docker-compose.production.yml exec web \
  sh -c 'rm -f storage/production.sqlite3 && sqlite3 storage/production.sqlite3 < /app/tmp/restore.sql'
```

## Step 7: Verify Data Integrity

```bash
docker compose -f docker-compose.yml -f docker-compose.production.yml exec web \
  sqlite3 storage/production.sqlite3 "PRAGMA integrity_check;"
# Expected output: ok

docker compose -f docker-compose.yml -f docker-compose.production.yml exec web \
  bin/rails runner 'puts "Documents: #{Document.count}, Tasks: #{Task.count}, Events: #{CalendarEvent.count}"'
```

## Step 8: Restart the Application

```bash
docker compose -f docker-compose.yml -f docker-compose.production.yml up -d web sidekiq
```

## Step 9: Verify Application

1. Visit the application in a browser
2. Check that documents, tasks, and calendar events are present
3. Check the health endpoint: `curl http://localhost:3000/api/health`

## Notes

- Backups are SQL dumps, so they are portable across SQLite versions
- Active Storage attachments (images, audio files) are NOT included in database backups — they live in `storage/` directory separately
- Backup metadata (`backup_records` table) will be restored to the state at backup time
