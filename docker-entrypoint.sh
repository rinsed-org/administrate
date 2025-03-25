#!/bin/bash
set -e

# Wait for Postgres to be ready
until PGPASSWORD=$PGPASSWORD psql -h $PGHOST -U $PGUSER -c '\q'; do
  echo "Postgres is unavailable - sleeping"
  sleep 1
done

echo "Postgres is up - executing command"

# Setup environment
echo "Setting up environment..."
cp .sample.env .env
cp spec/example_app/config/database.yml.sample spec/example_app/config/database.yml

# Setup database
echo "Setting up database..."
bundle exec rake db:setup

# Then exec the container's main process (what's set as CMD in the Dockerfile)
exec "$@"