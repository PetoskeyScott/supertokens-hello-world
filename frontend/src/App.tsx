import React from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import SuperTokens, { SuperTokensWrapper } from "supertokens-auth-react";
import { getSuperTokensRoutesForReactRouterDom } from "supertokens-auth-react/ui";
import { SessionAuth } from "supertokens-auth-react/recipe/session";
import { EmailPasswordPreBuiltUI } from "supertokens-auth-react/recipe/emailpassword/prebuiltui";
import { SuperTokensConfig } from './config/supertokensConfig';
import Home from './components/Home';
import './App.css';

// Initialize SuperTokens
SuperTokens.init(SuperTokensConfig);

function App() {
  return (
    <SuperTokensWrapper>
      <BrowserRouter>
        <Routes>
          {/* This renders the login UI on the /auth route */}
          {getSuperTokensRoutesForReactRouterDom(require("react-router-dom"), [EmailPasswordPreBuiltUI])}
          
          {/* Protected route */}
          <Route
            path="/"
            element={
              <SessionAuth>
                <Home />
              </SessionAuth>
            }
          />
        </Routes>
      </BrowserRouter>
    </SuperTokensWrapper>
  );
}

export default App; 