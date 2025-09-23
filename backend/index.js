// backend/index.js
require("dotenv").config();

const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const supertokens = require("supertokens-node");
const { middleware, errorHandler } = require("supertokens-node/framework/express");
const Session = require("supertokens-node/recipe/session");
const { verifySession } = require("supertokens-node/recipe/session/framework/express");
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
const ROLE_GRANT_SECRET = process.env.ROLE_GRANT_SECRET || undefined;

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
      EmailPassword.init({
        override: {
          apis: (originalImplementation) => {
            return {
              ...originalImplementation,
              // Assign roles during sign up
              async signUpPOST(input) {
                const response = await originalImplementation.signUpPOST(input);
                if (response.status === "OK") {
                  try {
                    const email = response.user.email.toLowerCase();
                    const role = email === "scottdev@snyders602.org" ? "admin" : "user";
                    const r = await UserRoles.addRoleToUser(response.user.id, role);
                    if (r.status !== "OK") {
                      console.error("DEBUG: [signup] addRoleToUser failed", { userId: response.user.id, role, r });
                    } else {
                      console.log("DEBUG: [signup] role assigned", { userId: response.user.id, role, status: r.status });
                    }

                    // If a session exists, refresh roles claim immediately
                    try {
                      const session = await Session.getSession(input.options.req, input.options.res, false);
                      if (session && UserRoles.UserRoleClaim) {
                        await session.fetchAndSetClaim(UserRoles.UserRoleClaim);
                        console.log("DEBUG: [signup] refreshed roles claim for session", { userId: response.user.id });
                      }
                    } catch (e) {
                      console.warn("DEBUG: [signup] could not refresh roles claim", e?.message || e);
                    }
                  } catch (e) {
                    console.error("DEBUG: [signup] error assigning role", e);
                  }
                }
                return response;
              },
              // Ensure roles exist on sign in (for existing users created before roles rollout)
              async signInPOST(input) {
                const response = await originalImplementation.signInPOST(input);
                if (response.status === "OK") {
                  try {
                    const userId = response.user.id;
                    const email = response.user.email?.toLowerCase() || "";
                    console.log("DEBUG: [signin] getRolesForUser starting", { userId, email });
                    const rolesRes = await UserRoles.getRolesForUser(userId);
                    console.log("DEBUG: [signin] getRolesForUser result", { userId, roles: rolesRes.roles });
                    if (!rolesRes.roles || rolesRes.roles.length === 0) {
                      const role = email === "scottdev@snyders602.org" ? "admin" : "user";
                      const r = await UserRoles.addRoleToUser(userId, role);
                      if (r.status !== "OK") {
                        console.error("DEBUG: [signin] addRoleToUser failed", { userId, role, r });
                      } else {
                        console.log("DEBUG: [signin] role assigned", { userId, role, status: r.status });
                      }
                    }
                    // Refresh roles claim into the session so FE sees it immediately
                    try {
                      const session = await Session.getSession(input.options.req, input.options.res, false);
                      if (session && UserRoles.UserRoleClaim) {
                        await session.fetchAndSetClaim(UserRoles.UserRoleClaim);
                        console.log("DEBUG: [signin] refreshed roles claim for session", { userId });
                      }
                    } catch (e) {
                      console.warn("DEBUG: [signin] could not refresh roles claim", e?.message || e);
                    }
                  } catch (e) {
                    console.error("DEBUG: [signin] error ensuring roles", e);
                  }
                }
                return response;
              },
            };
          },
        },
      }),
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

  // Seed roles on boot (idempotent)
  (async () => {
    try {
      await UserRoles.createNewRoleOrAddPermissions("admin", []);
      await UserRoles.createNewRoleOrAddPermissions("user", []);
      await UserRoles.createNewRoleOrAddPermissions("games", []);
      console.log("Roles seeded: admin, user, games");

      // Backfill user roles for existing users with no roles
      async function backfillUserRoles() {
        try {
          console.log("[backfill] starting user roles backfill");
          let token = undefined;
          let processed = 0;
          do {
            const { users, nextPaginationToken } = await EmailPassword.listUsersByAccountInfo(
              "ASC",
              100,
              token
            );
            token = nextPaginationToken;
            for (const u of users) {
              const rolesRes = await UserRoles.getRolesForUser(u.id);
              if (!rolesRes.roles || rolesRes.roles.length === 0) {
                const email = (u.email || "").toLowerCase();
                const role = email === "scottdev@snyders602.org" ? "admin" : "user";
                const r = await UserRoles.addRoleToUser(u.id, role);
                console.log("[backfill] assigned", { userId: u.id, email, role, status: r.status });
              }
              processed += 1;
            }
          } while (token);
          console.log(`[backfill] completed. users processed=${processed}`);
        } catch (e) {
          console.error("[backfill] failed", e);
        }
      }

      // Kick off backfill (do not block startup)
      backfillUserRoles();
    } catch (err) {
      console.error("Error seeding roles:", err);
    }
  })();
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

// Seed roles if missing (no auth). Safe: only seeds when roles are absent.
app.post("/api/roles/seed-if-missing", async (_req, res) => {
  try {
    const allRoles = await UserRoles.getAllRoles();
    const wanted = new Set(["admin", "user", "games"]);
    const haveAll = ["admin", "user", "games"].every((r) => allRoles.roles?.includes(r));
    if (haveAll) {
      return res.json({ ok: true, seeded: false, roles: allRoles.roles });
    }
    const r1 = await UserRoles.createNewRoleOrAddPermissions("admin", []);
    const r2 = await UserRoles.createNewRoleOrAddPermissions("user", []);
    const r3 = await UserRoles.createNewRoleOrAddPermissions("games", []);
    console.log("seed-if-missing results", r1, r2, r3);
    const after = await UserRoles.getAllRoles();
    return res.json({ ok: true, seeded: true, roles: after.roles });
  } catch (e) {
    console.error("/api/roles/seed-if-missing error", e);
    return res.status(500).json({ ok: false });
  }
});

// Temporary: Force grant role by email (guarded by ROLE_GRANT_SECRET)
app.post("/api/roles/grant", express.json(), async (req, res) => {
  try {
    if (!ROLE_GRANT_SECRET || req.headers["x-role-grant-secret"] !== ROLE_GRANT_SECRET) {
      return res.status(403).json({ ok: false });
    }
    const { email, role } = req.body || {};
    if (!email || !role || !["admin", "user", "games"].includes(role)) {
      return res.status(400).json({ ok: false });
    }
    const users = await EmailPassword.listUsersByAccountInfo("ASC", 100);
    const user = users.find((u) => (u.email || "").toLowerCase() === email.toLowerCase());
    if (!user) return res.status(404).json({ ok: false });
    const out = await UserRoles.addRoleToUser(user.id, role);
    return res.json({ ok: out.status === "OK" });
  } catch (e) {
    console.error("/api/roles/grant error", e);
    return res.status(500).json({ ok: false });
  }
});

// ----- Helper: admin guard -----
async function requireAdmin(req, res, next) {
  try {
    const session = await Session.getSession(req, res, false);
    if (!session) return res.status(401).json({ error: "Unauthorized" });
    const userId = session.getUserId();
    const isAdmin = await UserRoles.doesUserHaveRole(userId, "admin");
    if (!isAdmin) return res.status(403).json({ error: "Forbidden" });
    next();
  } catch (e) {
    next(e);
  }
}

// ----- Current user info -----
app.get("/api/me", verifySession(), async (req, res) => {
  try {
    const userId = req.session.getUserId();
    if (!userId) {
      console.error("/api/me missing userId in session");
      return res.status(401).json({ error: "Unauthorized" });
    }

    // Fetch user from SuperTokens and extract email from emailpassword login method
    let email = null;
    let timeJoined = null;
    try {
      const stUser = await supertokens.getUser(userId);
      timeJoined = stUser?.timeJoined ?? null;
      if (stUser?.loginMethods && Array.isArray(stUser.loginMethods)) {
        const ep = stUser.loginMethods.find((m) => m.recipeId === "emailpassword");
        email = ep?.email || null;
      }
      console.log("DEBUG: /api/me getUser", { userId, email, timeJoined });
    } catch (e) {
      console.error("DEBUG: /api/me getUser failed", e?.message || e);
    }

    let roles = [];
    try {
      console.log("DEBUG: /api/me getRolesForUser starting", { userId });
      const rolesRes = await UserRoles.getRolesForUser(userId);
      roles = rolesRes.roles || [];
      console.log("DEBUG: /api/me getRolesForUser result", { userId, roles });
    } catch (err) {
      console.error("DEBUG: /api/me getRolesForUser failed", err?.message || err);
    }
    res.json({ userId, email, timeJoined, roles });
  } catch (e) {
    console.error("/api/me error", e);
    return res.status(401).json({ error: "Unauthorized" });
  }
});

// ----- Admin APIs -----
// List users (paged)
app.get("/api/admin/users", requireAdmin, async (req, res) => {
  try {
    const limit = 50;
    const paginationToken = req.query.token || undefined;
    const { users, nextPaginationToken } = await supertokens.getUserCount === undefined
      ? await EmailPassword.listUsersByAccountInfo("ASC", limit, paginationToken)
      : await EmailPassword.listUsersByAccountInfo("ASC", limit, paginationToken);

    const data = await Promise.all(
      users.map(async (u) => {
        const roles = (await UserRoles.getRolesForUser(u.id)).roles;
        return { userId: u.id, email: u.email, timeJoined: u.timeJoined, roles };
      })
    );
    res.json({ users: data, nextToken: nextPaginationToken || null });
  } catch (e) {
    console.error("/api/admin/users error", e);
    res.status(500).json({ error: "Failed to list users" });
  }
});

// Add a role to a user
app.post("/api/admin/users/:userId/roles", requireAdmin, async (req, res) => {
  try {
    const { userId } = req.params;
    const { role } = req.body || {};
    if (!role || !["admin", "user", "games"].includes(role)) {
      return res.status(400).json({ error: "Invalid role" });
    }
    await UserRoles.addRoleToUser(userId, role);
    // Ensure user has at least admin or user
    const roles = (await UserRoles.getRolesForUser(userId)).roles;
    if (!roles.includes("admin") && !roles.includes("user")) {
      await UserRoles.addRoleToUser(userId, "user");
    }
    res.json({ ok: true });
  } catch (e) {
    console.error("add role error", e);
    res.status(500).json({ error: "Failed to add role" });
  }
});

// Remove a role from a user
app.delete("/api/admin/users/:userId/roles/:role", requireAdmin, async (req, res) => {
  try {
    const { userId, role } = req.params;
    if (!role || !["admin", "user", "games"].includes(role)) {
      return res.status(400).json({ error: "Invalid role" });
    }
    await UserRoles.removeUserRole(userId, role);
    // Enforce must have admin or user
    const roles = (await UserRoles.getRolesForUser(userId)).roles;
    if (!roles.includes("admin") && !roles.includes("user")) {
      // Revert by adding user
      await UserRoles.addRoleToUser(userId, "user");
    }
    res.json({ ok: true });
  } catch (e) {
    console.error("remove role error", e);
    res.status(500).json({ error: "Failed to remove role" });
  }
});

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
