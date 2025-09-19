import React from 'react';
import { Navigate } from 'react-router-dom';
import { useCanAccess } from '../hooks/useRouteGuard';

type RouteName = 'home' | 'news' | 'games' | 'settings' | 'admin';

const Guarded: React.FC<{ routeName: RouteName; children: React.ReactNode }> = ({ routeName, children }) => {
  const { allowed, loading } = useCanAccess(routeName);
  if (loading) return <div>Loading…</div>;
  // Allow home as a safe default if user lacks roles (old sessions)
  if (!allowed) {
    return routeName === 'home' ? <>{children}</> : <Navigate to="/home" replace />;
  }
  return <>{children}</>;
};

export default Guarded;


