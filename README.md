# SuperTokens Hello World Application

This is a multi-user Hello World application that demonstrates the use of SuperTokens for authentication. The application consists of a React frontend and Node.js backend, with PostgreSQL as the database.

## Prerequisites

- Node.js (v14 or higher)
- PostgreSQL
- Docker (for running SuperTokens core)
- AWS EC2 instance with Linux (for SuperTokens core)

## Project Structure

```
supertokens-hello-world/
├── backend/             # Node.js backend
├── frontend/           # React frontend
└── README.md
```

## Setup Instructions

### 1. SuperTokens Core Setup (on AWS EC2)

```bash
docker run -d \
    --restart=always \
    -p 3567:3567 \
    -e POSTGRESQL_CONNECTION_URI="postgresql://username:password@localhost:5432/supertokens" \
    registry.supertokens.io/supertokens/supertokens-postgresql
```

### 2. Backend Setup

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Create a `.env` file with the following content:
   ```
   PORT=3001
   SUPERTOKENS_CONNECTION_URI=http://localhost:3567
   SUPERTOKENS_API_KEY=your-api-key
   DATABASE_URL=postgresql://postgres:your-password@localhost:5432/supertokens_hello_world
   FRONTEND_URL=http://localhost:3000
   API_DOMAIN=http://localhost:3001
   WEBSITE_DOMAIN=http://localhost:3000
   ```

4. Start the backend server:
   ```bash
   npm start
   ```

### 3. Frontend Setup

1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Start the frontend development server:
   ```bash
   npm start
   ```

## Features

- User authentication (sign up, sign in, sign out)
- Account management
- Role-based access control (Admin and User roles)
- Protected routes
- Session management

## Usage

1. Access the application at `http://localhost:3000`
2. Sign up for a new account
3. The first user of an account automatically becomes an Admin
4. Admin users can add additional users to their account
5. Additional users are assigned the User role by default

## Security Notes

- Never commit `.env` files to version control
- Keep your SuperTokens API keys secure
- Use HTTPS in production
- Follow security best practices for your AWS EC2 instance

## License

MIT 