require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const supertokens = require('supertokens-node');
const { middleware } = require('supertokens-node/framework/express');
const { errorHandler } = require('supertokens-node/framework/express');
const Session = require('supertokens-node/recipe/session');
const EmailPassword = require('supertokens-node/recipe/emailpassword');
const UserRoles = require('supertokens-node/recipe/userroles');
const { Pool } = require('pg');

// Initialize PostgreSQL connection pool
const pool = new Pool({
    connectionString: process.env.DATABASE_URL
});

// Configure SuperTokens
try {
    console.log('Initializing SuperTokens with config:', {
        connectionURI: process.env.SUPERTOKENS_CONNECTION_URI,
        apiDomain: process.env.API_DOMAIN,
        websiteDomain: process.env.WEBSITE_DOMAIN
    });
    
    supertokens.init({
        framework: "express",
        supertokens: {
            connectionURI: process.env.SUPERTOKENS_CONNECTION_URI,
        },
        appInfo: {
            appName: "SuperTokens Hello World",
            apiDomain: process.env.API_DOMAIN,
            websiteDomain: process.env.WEBSITE_DOMAIN,
        },
        recipeList: [
            EmailPassword.init(),
            Session.init(),
            UserRoles.init()
        ]
    });
    
    console.log('SuperTokens initialized successfully');
    
    // Test the connection to SuperTokens core
    console.log('Testing connection to SuperTokens core...');
    fetch(process.env.SUPERTOKENS_CONNECTION_URI + '/hello')
        .then(response => response.text())
        .then(data => console.log('SuperTokens core connection test successful:', data))
        .catch(error => console.error('SuperTokens core connection test failed:', error));
        
} catch (error) {
    console.error('Error initializing SuperTokens:', error);
    process.exit(1);
}

const app = express();

// Body parsing middleware - MUST be FIRST, before any other middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Test route to verify basic functionality
app.get('/test', (req, res) => {
    res.json({ message: 'Backend is working!' });
});

// Request logging middleware
app.use((req, res, next) => {
    console.log(`${req.method} ${req.path}`, {
        headers: req.headers,
        body: JSON.stringify(req.body, null, 2),
        query: req.query
    });
    next();
});

// Essential middleware
app.use(helmet());
app.use(cors({
    origin: process.env.FRONTEND_URL,
    allowedHeaders: ["content-type", ...supertokens.getAllCORSHeaders()],
    credentials: true,
}));

// Add error logging middleware
app.use((err, req, res, next) => {
    console.error('Error in middleware:', err);
    next(err);
});

// SuperTokens middleware
app.use(middleware());

// Initialize database tables
async function initDatabase() {
    const createAccountsTable = `
        CREATE TABLE IF NOT EXISTS accounts (
            id SERIAL PRIMARY KEY,
            name VARCHAR(255) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    `;

    const createUserAccountsTable = `
        CREATE TABLE IF NOT EXISTS user_accounts (
            user_id VARCHAR(255) NOT NULL,
            account_id INTEGER NOT NULL,
            role VARCHAR(50) NOT NULL,
            PRIMARY KEY (user_id, account_id),
            FOREIGN KEY (account_id) REFERENCES accounts(id)
        );
    `;

    try {
        await pool.query(createAccountsTable);
        await pool.query(createUserAccountsTable);
        console.log('Database tables initialized successfully');
    } catch (error) {
        console.error('Error initializing database tables:', error);
    }
}

// Routes
app.post('/api/account', async (req, res) => {
    let session = await Session.getSession(req, res);
    if (session === undefined) {
        return res.status(401).json({ error: 'Unauthorized' });
    }

    const userId = session.getUserId();
    const { name } = req.body;

    try {
        const result = await pool.query(
            'INSERT INTO accounts (name) VALUES ($1) RETURNING id',
            [name]
        );
        
        const accountId = result.rows[0].id;
        
        await pool.query(
            'INSERT INTO user_accounts (user_id, account_id, role) VALUES ($1, $2, $3)',
            [userId, accountId, 'admin']
        );

        res.json({ accountId });
    } catch (error) {
        res.status(500).json({ error: 'Failed to create account' });
    }
});

app.get('/api/account/:accountId/users', async (req, res) => {
    let session = await Session.getSession(req, res);
    if (session === undefined) {
        return res.status(401).json({ error: 'Unauthorized' });
    }

    const { accountId } = req.params;

    try {
        const result = await pool.query(
            'SELECT user_id, role FROM user_accounts WHERE account_id = $1',
            [accountId]
        );
        res.json(result.rows);
    } catch (error) {
        res.status(500).json({ error: 'Failed to fetch users' });
    }
});

// Error handling
app.use(errorHandler());

// Start server
const port = process.env.PORT || 3001;
app.listen(port, () => {
    console.log(`Server running on port ${port}`);
    initDatabase();
}); 