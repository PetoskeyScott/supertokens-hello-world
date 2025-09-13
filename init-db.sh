#!/bin/bash
set -e

# PostgreSQL initialization script for SuperTokens Hello World
# This script runs when the PostgreSQL container starts for the first time

# Create SuperTokens database and user
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE supertokens;
    CREATE USER supertokens_user WITH PASSWORD '$SUPERTOKENS_PASSWORD';
    GRANT ALL PRIVILEGES ON DATABASE supertokens TO supertokens_user;
EOSQL

# Create application database and user
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE supertokens_hello_world;
    CREATE USER app_user WITH PASSWORD '$APP_PASSWORD';
    GRANT ALL PRIVILEGES ON DATABASE supertokens_hello_world TO app_user;
EOSQL

# Connect to SuperTokens database and set up extensions
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "supertokens" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    
    -- Grant permissions to supertokens_user for the supertokens database
    GRANT ALL ON SCHEMA public TO supertokens_user;
    GRANT CREATE ON SCHEMA public TO supertokens_user;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO supertokens_user;
EOSQL

# Connect to application database and set up extensions
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "supertokens_hello_world" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    
    -- Grant schema creation permission to app_user
    GRANT CREATE ON DATABASE supertokens_hello_world TO app_user;
    GRANT USAGE ON SCHEMA public TO app_user;
    GRANT CREATE ON SCHEMA public TO app_user;
    
    -- Set search path for app_user
    ALTER USER app_user SET search_path TO public, supertokenapp;
EOSQL
