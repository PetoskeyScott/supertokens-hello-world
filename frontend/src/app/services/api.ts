export const API_BASE: string = (process.env.REACT_APP_API_DOMAIN || '').replace(/\/$/, '');

export async function apiGet(path: string, init: RequestInit = {}) {
  const res = await fetch(`${API_BASE}${path}`, { credentials: 'include', ...init });
  return res;
}

export async function apiJson<T = any>(path: string, init: RequestInit = {}) {
  const res = await apiGet(path, init);
  if (!res.ok) throw new Error(`Request failed: ${res.status}`);
  return (await res.json()) as T;
}

export async function apiPost(path: string, body?: any) {
  return apiGet(path, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: body ? JSON.stringify(body) : undefined });
}

export async function apiDelete(path: string) {
  return apiGet(path, { method: 'DELETE' });
}


