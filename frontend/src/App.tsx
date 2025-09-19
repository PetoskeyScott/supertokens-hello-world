import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import SuperTokens, { SuperTokensWrapper } from "supertokens-auth-react";
import { getSuperTokensRoutesForReactRouterDom } from "supertokens-auth-react/ui";
import { SessionAuth } from "supertokens-auth-react/recipe/session";
import { EmailPasswordPreBuiltUI } from "supertokens-auth-react/recipe/emailpassword/prebuiltui";
import { SuperTokensConfig } from './config/supertokensConfig';
import AppLayout from './app/layout/AppLayout';
import Home from './app/routes/Home';
import News from './app/routes/News';
import Games from './app/routes/Games';
import Settings from './app/routes/Settings';
import Admin from './app/routes/Admin';
import Guarded from './app/components/Guarded';
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

          {/* Protected app routes with shared layout */}
          <Route
            path="/"
            element={
              <SessionAuth>
                <AppLayout />
              </SessionAuth>
            }
          >
            <Route index element={<Navigate to="/home" replace />} />
            <Route path="home" element={<Guarded routeName="home"><Home /></Guarded>} />
            <Route path="news" element={<Guarded routeName="news"><News /></Guarded>} />
            <Route path="games" element={<Guarded routeName="games"><Games /></Guarded>} />
            <Route path="settings" element={<Guarded routeName="settings"><Settings /></Guarded>} />
            <Route path="admin" element={<Guarded routeName="admin"><Admin /></Guarded>} />
            <Route path="*" element={<Navigate to="/home" replace />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </SuperTokensWrapper>
  );
}

export default App; 