-- PostgreSQL initialization script for SuperTokens Hello World
-- This script runs when the PostgreSQL container starts for the first time

-- Create SuperTokens database and user
CREATE DATABASE supertokens;
CREATE USER supertokens_user WITH PASSWORD '${SUPERTOKENS_PASSWORD}';
GRANT ALL PRIVILEGES ON DATABASE supertokens TO supertokens_user;

-- Create application database and user
CREATE DATABASE supertokens_hello_world;
CREATE USER app_user WITH PASSWORD '${APP_PASSWORD}';
GRANT ALL PRIVILEGES ON DATABASE supertokens_hello_world TO app_user;

-- Connect to SuperTokens database and set up extensions
\c supertokens;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Connect to application database and set up extensions
\c supertokens_hello_world;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Grant schema creation permission to app_user
GRANT CREATE ON DATABASE supertokens_hello_world TO app_user;
GRANT USAGE ON SCHEMA public TO app_user;
GRANT CREATE ON SCHEMA public TO app_user;

-- Set search path for app_user
ALTER USER app_user SET search_path TO public, supertokenapp;
