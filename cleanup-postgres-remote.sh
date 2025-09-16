#!/bin/bash
set -e

echo "🛑 Stopping all Docker containers..."
cd /home/ubuntu/supertokens-hello-world
docker-compose -f docker-compose.dev.yml down

echo "🗑️  Removing PostgreSQL volume..."
docker volume rm supertokens-hello-world_postgres_data 2>/dev/null || echo "Volume may not exist or already removed"

echo "🧹 Cleaning up any orphaned containers and networks..."
docker system prune -f

echo "🔄 Starting services with fresh database..."
docker-compose -f docker-compose.dev.yml up -d --force-recreate

echo "⏳ Waiting for services to start..."
sleep 10

echo "📊 Checking service status..."
docker-compose -f docker-compose.dev.yml ps

echo "✅ PostgreSQL volume cleanup completed!"
echo "The database has been recreated with the new passwords from the .env file"
