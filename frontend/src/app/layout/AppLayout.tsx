import React from 'react';
import { NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom';
import Session from "supertokens-auth-react/recipe/session";
import { useCanAccess } from '../hooks/useRouteGuard';

function useRoles(): string[] {
  const [roles, setRoles] = React.useState<string[]>([]);
  React.useEffect(() => {
    (async () => {
      try {
        const payload: any = await Session.getAccessTokenPayloadSecurely();
        const claim = payload?.st?.ur; // user roles claim path used by SuperTokens
        if (Array.isArray(claim)) {
          setRoles(claim as string[]);
        } else {
          setRoles([]);
        }
      } catch {
        setRoles([]);
      }
    })();
  }, []);
  return roles;
}

function canAccess(route: string, roles: string[]): boolean {
  // Keep simple: admin full access. Otherwise rely on role presence as in useRouteGuard
  const isAdmin = roles.includes('admin');
  if (isAdmin) return true;
  if (route === 'admin') return false;
  if (route === 'games') return roles.includes('games') && roles.includes('user');
  return roles.includes('user');
}

const TopNav: React.FC<{ roles: string[] }> = ({ roles }) => {
  const navItems = [
    { to: '/home', label: 'Home' },
    { to: '/news', label: 'News' },
    { to: '/games', label: 'Games' },
    { to: '/settings', label: 'Settings' },
    { to: '/admin', label: 'Admin' },
  ];
  const navigate = useNavigate();
  return (
    <div className="app-nav" style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 16px' }}>
      <div className="stack-row" style={{ gap: 8 }}>
        {navItems.filter(n => canAccess(n.to.replace('/', ''), roles)).map((n) => (
          <NavLink key={n.to} to={n.to} className={({ isActive }) => `nav-link${isActive ? ' active' : ''}`}>{n.label}</NavLink>
        ))}
      </div>
      <UserMenu />
    </div>
  );
};

const UserMenu: React.FC = () => {
  const [email, setEmail] = React.useState<string>('');
  React.useEffect(() => {
    (async () => {
      try {
        const r = await fetch('/api/me', { credentials: 'include' });
        if (r.ok) {
          const j = await r.json();
          setEmail(j.email || '');
        }
      } catch {}
    })();
  }, []);
  const onSignOut = async () => {
    const { signOut } = await import('supertokens-auth-react/recipe/emailpassword');
    await signOut();
    window.location.href = '/auth';
  };
  return (
    <div className="stack-row" style={{ gap: 12 }}>
      <span style={{ fontSize: 14, color: '#6b7280' }}>{email}</span>
      <button className="btn" onClick={onSignOut}>Sign out</button>
    </div>
  );
};

const ModuleSidebar: React.FC = () => {
  const location = useLocation();
  const pathname = location.pathname;
  const section = pathname.split('/')[1] || 'home';
  const items: Record<string, string[]> = {
    home: ['Overview', 'Updates'],
    news: ['Top stories', 'Tech', 'Sports'],
    games: ['Arcade', 'Puzzles'],
    settings: ['Profile', 'Security'],
    admin: ['Users', 'Roles'],
  };
  const list = items[section] || [];
  return (
    <div className="app-sidebar" style={{ padding: 16 }}>
      <div className="stack-col">
        {list.map((label) => (
          <div key={label} style={{ padding: '6px 8px', borderRadius: 6, cursor: 'default' }}>{label}</div>
        ))}
      </div>
    </div>
  );
};

const Footer: React.FC = () => (
  <div className="app-footer" style={{ display: 'flex', alignItems: 'center', padding: '0 16px', fontSize: 12, color: '#6b7280' }}>
    <span>© 2025 • <a href="#" rel="noreferrer">Privacy</a> • <a href="#" rel="noreferrer">Help</a></span>
  </div>
);

const AppLayout: React.FC = () => {
  const roles = useRoles();
  return (
    <div className="app-grid">
      <TopNav roles={roles} />
      <ModuleSidebar />
      <main className="app-content" style={{ padding: 16 }}>
        <Outlet />
      </main>
      <Footer />
    </div>
  );
};

export default AppLayout;


