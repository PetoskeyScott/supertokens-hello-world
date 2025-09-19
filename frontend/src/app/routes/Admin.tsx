import React from 'react';

type UserRow = { userId: string; email: string; timeJoined: number; roles: string[] };

const allRoles = ["admin", "user", "games"] as const;

const Admin: React.FC = () => {
  const [users, setUsers] = React.useState<UserRow[]>([]);
  const [loading, setLoading] = React.useState<boolean>(false);
  const [error, setError] = React.useState<string>('');

  const load = React.useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const r = await fetch('/api/admin/users', { credentials: 'include' });
      if (!r.ok) throw new Error('Failed');
      const j = await r.json();
      setUsers(j.users || []);
    } catch (e: any) {
      setError(e?.message || 'Failed to load users');
    } finally {
      setLoading(false);
    }
  }, []);

  React.useEffect(() => { load(); }, [load]);

  const toggleRole = async (userId: string, role: typeof allRoles[number], has: boolean) => {
    try {
      if (has) {
        const r = await fetch(`/api/admin/users/${userId}/roles/${role}`, { method: 'DELETE', headers: { 'Content-Type': 'application/json' }, credentials: 'include' });
        if (!r.ok) throw new Error('Failed to remove role');
      } else {
        const r = await fetch(`/api/admin/users/${userId}/roles`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, credentials: 'include', body: JSON.stringify({ role }) });
        if (!r.ok) throw new Error('Failed to add role');
      }
      await load();
    } catch (e: any) {
      alert(e?.message || 'Action failed');
    }
  };

  return (
    <div>
      <h1>Admin</h1>
      {error && <div style={{ color: 'red' }}>{error}</div>}
      {loading ? <div>Loading…</div> : (
        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr>
                <th style={{ textAlign: 'left', borderBottom: '1px solid #e5e7eb', padding: 8 }}>Email</th>
                <th style={{ textAlign: 'left', borderBottom: '1px solid #e5e7eb', padding: 8 }}>Created</th>
                <th style={{ textAlign: 'left', borderBottom: '1px solid #e5e7eb', padding: 8 }}>Roles</th>
              </tr>
            </thead>
            <tbody>
              {users.map(u => (
                <tr key={u.userId}>
                  <td style={{ padding: 8 }}>{u.email}</td>
                  <td style={{ padding: 8 }}>{new Date(u.timeJoined).toLocaleString()}</td>
                  <td style={{ padding: 8 }}>
                    <div className="stack-row" style={{ gap: 8, flexWrap: 'wrap' }}>
                      {allRoles.map(r => {
                        const has = u.roles.includes(r);
                        return (
                          <label key={r} style={{ display: 'inline-flex', alignItems: 'center', gap: 6, border: '1px solid #e5e7eb', padding: '4px 8px', borderRadius: 6 }}>
                            <input type="checkbox" checked={has} onChange={() => toggleRole(u.userId, r, has)} />
                            {r}
                          </label>
                        );
                      })}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
};

export default Admin;


