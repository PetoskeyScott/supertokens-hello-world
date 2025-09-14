import EmailPassword from "supertokens-auth-react/recipe/emailpassword";
import Session from "supertokens-auth-react/recipe/session";
import { EmailPasswordPreBuiltUI } from "supertokens-auth-react/recipe/emailpassword/prebuiltui";

export const SuperTokensConfig = {
    appInfo: {
        appName: "SuperTokens Hello World",
        apiDomain: process.env.REACT_APP_API_DOMAIN,
        websiteDomain: process.env.REACT_APP_WEBSITE_DOMAIN,
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
                                // Create account after successful signup
                                // For now, we'll create a default account name based on email
                                const email = input.formFields.find(
                                    (field: any) => field.id === "email"
                                )?.value;
                                
                                const accountName = email ? email.split('@')[0] : 'Default Account';

                                await fetch("/api/account", {
                                    method: "POST",
                                    headers: {
                                        "Content-Type": "application/json"
                                    },
                                    body: JSON.stringify({
                                        name: accountName
                                    })
                                });
                            }
                            return response;
                        }
                    };
                }
            }
        }),
        Session.init()
    ]
}; 