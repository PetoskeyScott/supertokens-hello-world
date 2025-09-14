#!/bin/bash
set -e

# PostgreSQL initialization script for SuperTokens Hello World
# This script is idempotent and safe to run multiple times

# Create SuperTokens database and user (if they don't exist)
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create database if it doesn't exist
    SELECT 'CREATE DATABASE supertokens'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'supertokens')\gexec
    
    -- Create user if it doesn't exist, otherwise update password
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'supertokens_user') THEN
            CREATE USER supertokens_user WITH PASSWORD '$SUPERTOKENS_PASSWORD';
        ELSE
            ALTER USER supertokens_user WITH PASSWORD '$SUPERTOKENS_PASSWORD';
        END IF;
    END
    \$\$;
    
    GRANT ALL PRIVILEGES ON DATABASE supertokens TO supertokens_user;
EOSQL

# Create application database and user (if they don't exist)
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create database if it doesn't exist
    SELECT 'CREATE DATABASE supertokens_hello_world'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'supertokens_hello_world')\gexec
    
    -- Create user if it doesn't exist, otherwise update password
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'app_user') THEN
            CREATE USER app_user WITH PASSWORD '$APP_PASSWORD';
        ELSE
            ALTER USER app_user WITH PASSWORD '$APP_PASSWORD';
        END IF;
    END
    \$\$;
    
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
