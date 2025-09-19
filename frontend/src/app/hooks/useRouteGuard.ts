import { useRoles } from './useRoles';

export function useCanAccess(route: 'home' | 'news' | 'games' | 'settings' | 'admin'): boolean {
  const roles = useRoles();
  const isAdmin = roles.includes('admin');
  if (isAdmin) return true;
  if (route === 'admin') return false;
  if (route === 'games') return roles.includes('games') && roles.includes('user');
  return roles.includes('user');
}


