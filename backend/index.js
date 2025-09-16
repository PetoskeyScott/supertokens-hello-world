// backend/index.js
require("dotenv").config();

const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const supertokens = require("supertokens-node");
const { middleware, errorHandler } = require("supertokens-node/framework/express");
const Session = require("supertokens-node/recipe/session");
const EmailPassword = require("supertokens-node/recipe/emailpassword");
const UserRoles = require("supertokens-node/recipe/userroles");
const { Pool } = require("pg");

// ---------- Environment ----------
const PORT = process.env.PORT || 3001;
const API_DOMAIN = process.env.API_DOMAIN;                     // e.g. http://98.87.215.3:3001
const WEBSITE_DOMAIN = process.env.WEBSITE_DOMAIN || process.env.FRONTEND_URL; // prefer WEBSITE_DOMAIN
const SUPERTOKENS_CONNECTION_URI = process.env.SUPERTOKENS_CONNECTION_URI;     // e.g. http://supertokens-core:3567
const SUPERTOKENS_API_KEY = process.env.SUPERTOKENS_API_KEY || undefined;
const DATABASE_URL = process.env.DATABASE_URL;

["API_DOMAIN", "WEBSITE_DOMAIN", "SUPERTOKENS_CONNECTION_URI"].forEach((k) => {
  if (!process.env[k]) console.warn(`[warn] ${k} is not set`);
});

// ---------- PostgreSQL ----------
const pool = new Pool({ connectionString: DATABASE_URL });

// ---------- SuperTokens init ----------
try {
  console.log("Initializing SuperTokens with config:", {
    connectionURI: SUPERTOKENS_CONNECTION_URI,
    apiDomain: API_DOMAIN,
    websiteDomain: WEBSITE_DOMAIN,
  });

  supertokens.init({
    framework: "express",
    supertokens: {
      connectionURI: SUPERTOKENS_CONNECTION_URI,
      apiKey: SUPERTOKENS_API_KEY, // optional
    },
    appInfo: {
      appName: "SuperTokens Hello World",
      apiDomain: API_DOMAIN,
      websiteDomain: WEBSITE_DOMAIN,
      // keep FE/BE aligned explicitly in dev
      apiBasePath: "/auth",
      websiteBasePath: "/auth",
    },
    recipeList: [
      EmailPassword.init(),
      UserRoles.init(),
      Session.init({
        // Dev over HTTP + bare IP:
        cookieSecure: false,    // must be false on http
        cookieSameSite: "lax",  // FE and BE are same-site here
        // DO NOT set cookieDomain when using an IP host
        // cookieDomain: undefined
      }),
    ],
  });

  console.log("SuperTokens initialized successfully");

  // Test the connection to SuperTokens core
  console.log("Testing connection to SuperTokens core...");
  // Node 18+ has global fetch
  fetch(`${SUPERTOKENS_CONNECTION_URI.replace(/\/$/, "")}/hello`)
    .then((r) => r.text())
    .then((txt) => console.log("SuperTokens core connection test successful:", txt))
    .catch((err) => console.error("SuperTokens core connection test failed:", err));
} catch (error) {
  console.error("Error initializing SuperTokens:", error);
  process.exit(1);
}

// ---------- Express app ----------
const app = express();

// Body parsers first
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Simple test route (yours)
app.get("/test", (req, res) => {
  res.json({ message: "Backend is working!" });
});

// Request logging (yours)
app.use((req, _res, next) => {
  console.log(`${req.method} ${req.path}`, {
    headers: req.headers,
    body: JSON.stringify(req.body, null, 2),
    query: req.query,
  });
  next();
});

// Helmet (relaxed so it doesn't conflict in dev)
app.use(
  helmet({
    contentSecurityPolicy: false, // FE/nginx can own CSP if needed
    crossOriginResourcePolicy: { policy: "same-site" },
  })
);

// CORS must allow ST headers + credentials
app.use(
  cors({
    origin: WEBSITE_DOMAIN, // align with SuperTokens appInfo.websiteDomain
    credentials: true,
    allowedHeaders: ["content-type", ...supertokens.getAllCORSHeaders()],
    methods: ["GET", "PUT", "POST", "DELETE", "OPTIONS"],
  })
);

// Error logging (yours)
app.use((err, _req, _res, next) => {
  console.error("Error in middleware:", err);
  next(err);
});

// SuperTokens middleware (exposes /auth/*)
app.use(middleware());

// ---------- DB bootstrap ----------
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
    console.log("Database tables initialized successfully");
  } catch (error) {
    console.error("Error initializing database tables:", error);
  }
}

// ---------- Routes ----------
app.get("/api/health", (_req, res) => res.json({ ok: true }));

app.post("/api/account", async (req, res) => {
  // In Express, pass `false` to avoid throwing on missing session:
  let session = await Session.getSession(req, res, false);
  if (!session) {
    return res.status(401).json({ error: "Unauthorized" });
  }

  const userId = session.getUserId();
  const { name } = req.body;

  try {
    const result = await pool.query(
      "INSERT INTO accounts (name) VALUES ($1) RETURNING id",
      [name]
    );

    const accountId = result.rows[0].id;

    await pool.query(
      "INSERT INTO user_accounts (user_id, account_id, role) VALUES ($1, $2, $3)",
      [userId, accountId, "admin"]
    );

    res.json({ accountId });
  } catch (error) {
    console.error("Error creating account:", error);
    res.status(500).json({ error: "Failed to create account" });
  }
});

app.get("/api/account/:accountId/users", async (req, res) => {
  let session = await Session.getSession(req, res, false);
  if (!session) {
    return res.status(401).json({ error: "Unauthorized" });
  }

  const { accountId } = req.params;

  try {
    const result = await pool.query(
      "SELECT user_id, role FROM user_accounts WHERE account_id = $1",
      [accountId]
    );
    res.json(result.rows);
  } catch (error) {
    console.error("Error fetching users for account:", error);
    res.status(500).json({ error: "Failed to fetch users" });
  }
});

// SuperTokens error handler MUST be last
app.use(errorHandler());

// ---------- Start server ----------
app.listen(PORT, () => {
  console.log(
    `[backend] listening on ${PORT}\n` +
      `  API_DOMAIN=${API_DOMAIN}\n` +
      `  WEBSITE_DOMAIN=${WEBSITE_DOMAIN}\n` +
      `  SUPERTOKENS_CONNECTION_URI=${SUPERTOKENS_CONNECTION_URI}`
  );
  initDatabase();
});
