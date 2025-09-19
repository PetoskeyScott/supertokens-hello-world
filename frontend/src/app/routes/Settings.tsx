import React from 'react';

const Settings: React.FC = () => {
  const [profile, setProfile] = React.useState<{email: string; timeJoined: number | null; roles: string[]}>({email: '', timeJoined: null, roles: []});
  React.useEffect(() => {
    (async () => {
      try {
        const r = await fetch('/api/me', { credentials: 'include' });
        if (r.ok) {
          const j = await r.json();
          setProfile({ email: j.email || '', timeJoined: j.timeJoined || null, roles: j.roles || [] });
        }
      } catch {}
    })();
  }, []);
  const created = profile.timeJoined ? new Date(profile.timeJoined).toLocaleString() : '-';
  return (
    <div>
      <h1>Settings</h1>
      <div style={{ marginTop: 12 }}>
        <div><strong>Account name:</strong> {profile.email}</div>
        <div><strong>Date account created:</strong> {created}</div>
        <div><strong>Group membership:</strong> {profile.roles.join(', ') || '-'}</div>
      </div>
    </div>
  );
};

export default Settings;


