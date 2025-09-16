// src/supertokensConfig.ts
import EmailPassword from "supertokens-auth-react/recipe/emailpassword";
import Session from "supertokens-auth-react/recipe/session";
import { EmailPasswordPreBuiltUI } from "supertokens-auth-react/recipe/emailpassword/prebuiltui";

// --- Small helper so TS sees strings (not string|undefined) and we fail fast at build time
function req(name: "REACT_APP_API_DOMAIN" | "REACT_APP_WEBSITE_DOMAIN"): string {
  const v = process.env[name];
  if (!v) {
    throw new Error(`Missing required environment variable ${name}`);
  }
  return v;
}

// API domain is still baked in at build time (from .env / compose build args)
const API_DOMAIN: string = req("REACT_APP_API_DOMAIN");

// WEBSITE domain should match whatever origin the page is currently on.
// Use runtime origin when in the browser; fall back to env for build/test.
const WEBSITE_DOMAIN: string = (() => {
  if (typeof window !== "undefined" && window.location?.origin) {
    // window.location.origin is a string (e.g., "http://98.87.215.3:3000")
    return window.location.origin;
  }
  // Fallback for non-browser contexts (tests/SSR/build-time type-check)
  return req("REACT_APP_WEBSITE_DOMAIN");
})();

export const SuperTokensConfig = {
  appInfo: {
    appName: "SuperTokens Hello World",
    apiDomain: API_DOMAIN,         // string
    websiteDomain: WEBSITE_DOMAIN, // string, dynamic at runtime in the browser
    // keep FE/BE aligned
    apiBasePath: "/auth",
    websiteBasePath: "/auth",
  },
  recipeList: [
    EmailPassword.init({
      override: {
        functions: (originalImplementation: any) => {
          return {
            ...originalImplementation,
            signUp: async function (input: any) {
              const response = await originalImplementation.signUp(input);
              if (response.status === "OK") {
                const email = input.formFields.find(
                  (f: any) => f.id === "email"
                )?.value;

                const accountName = email ? email.split("@")[0] : "Default Account";

                // Call backend via absolute API URL (no reverse proxy in front yet)
                await fetch(`${API_DOMAIN.replace(/\/$/, "")}/api/account`, {
                  method: "POST",
                  headers: { "Content-Type": "application/json" },
                  body: JSON.stringify({ name: accountName }),
                });
              }
              return response;
            },
          };
        },
      },
    }),
    Session.init(),
  ],
};

