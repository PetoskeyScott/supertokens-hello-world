import { useRoles } from './useRoles';

export function useCanAccess(route: 'home' | 'news' | 'games' | 'settings' | 'admin'): { allowed: boolean; loading: boolean } {
  const { roles, loading } = useRoles();
  if (loading) return { allowed: false, loading: true };
  const isAdmin = roles.includes('admin');
  if (isAdmin) return { allowed: true, loading: false };
  if (route === 'admin') return { allowed: false, loading: false };
  if (route === 'games') return { allowed: roles.includes('games'), loading: false };
  // home, news, settings
  return { allowed: true, loading: false };
}


