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

const API_DOMAIN = req("REACT_APP_API_DOMAIN");
const WEBSITE_DOMAIN = req("REACT_APP_WEBSITE_DOMAIN");

export const SuperTokensConfig = {
  appInfo: {
    appName: "SuperTokens Hello World",
    apiDomain: API_DOMAIN,             // <- guaranteed string
    websiteDomain: WEBSITE_DOMAIN,     // <- guaranteed string
    // strongly recommended to set these explicitly so FE/BE match
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

                // IMPORTANT:
                // In a production build served by nginx, "/api" won't proxy unless you add an nginx gateway.
                // Since you're exposing the backend on :3001 directly, call it via the absolute API domain:
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
