import React from 'react';
import Session from "supertokens-auth-react/recipe/session";

export function useRoles(): string[] {
  const [roles, setRoles] = React.useState<string[]>([]);
  React.useEffect(() => {
    (async () => {
      try {
        const payload: any = await Session.getAccessTokenPayloadSecurely();
        const claim = payload?.st?.ur;
        if (Array.isArray(claim) && claim.length > 0) {
          setRoles(claim as string[]);
          return;
        }
        // Fallback to API if claim is missing
        const r = await fetch('/api/me', { credentials: 'include' });
        if (r.ok) {
          const j = await r.json();
          if (Array.isArray(j.roles)) {
            setRoles(j.roles as string[]);
            return;
          }
        }
        setRoles([]);
      } catch {
        setRoles([]);
      }
    })();
  }, []);
  return roles;
}


