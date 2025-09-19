import React from 'react';
import { Navigate } from 'react-router-dom';
import { useCanAccess } from '../hooks/useRouteGuard';

type RouteName = 'home' | 'news' | 'games' | 'settings' | 'admin';

const Guarded: React.FC<{ routeName: RouteName; children: React.ReactNode }> = ({ routeName, children }) => {
  const ok = useCanAccess(routeName);
  if (!ok) return <Navigate to="/home" replace />;
  return <>{children}</>;
};

export default Guarded;


