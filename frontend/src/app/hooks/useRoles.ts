import React from 'react';
import Session from "supertokens-auth-react/recipe/session";
import { apiJson } from '../services/api';

export function useRoles(): { roles: string[]; loading: boolean } {
  const [roles, setRoles] = React.useState<string[]>([]);
  const [loading, setLoading] = React.useState<boolean>(true);
  React.useEffect(() => {
    (async () => {
      try {
        const payload: any = await Session.getAccessTokenPayloadSecurely();
        const claim = payload?.["st-ur"];
        if (Array.isArray(claim) && claim.length > 0) {
          setRoles(claim as string[]);
          setLoading(false);
          return;
        }
        // Fallback to API if claim is missing
        const j = await apiJson('/api/me');
        if (Array.isArray(j.roles)) {
          setRoles(j.roles as string[]);
          setLoading(false);
          return;
        }
        setRoles([]);
        setLoading(false);
      } catch {
        setRoles([]);
        setLoading(false);
      }
    })();
  }, []);
  return { roles, loading };
}


