import type { AuthSession, EntraAuthConfig } from '@purview/contracts';

const SESSION_STORAGE_KEY = 'purview.auth.session';

type StoredSession = {
  userId: string;
  email: string;
  displayName: string;
  tenantExternalId: string;
};

export function getEntraAuthConfig(): EntraAuthConfig {
  return {
    clientId: import.meta.env.VITE_ENTRA_CLIENT_ID ?? '',
    authority: import.meta.env.VITE_ENTRA_AUTHORITY ?? '',
    redirectUri: import.meta.env.VITE_ENTRA_REDIRECT_URI ?? '',
    apiAudience: import.meta.env.VITE_API_AUDIENCE ?? ''
  };
}

function readStoredSession(): StoredSession | null {
  const raw = window.localStorage.getItem(SESSION_STORAGE_KEY);
  if (!raw) {
    return null;
  }

  try {
    return JSON.parse(raw) as StoredSession;
  } catch {
    return null;
  }
}

export function getAuthSession(): AuthSession {
  const stored = readStoredSession();
  if (!stored) {
    return { isAuthenticated: false, user: null, accessToken: null };
  }

  return {
    isAuthenticated: true,
    accessToken: 'dev-token-placeholder',
    user: {
      userId: stored.userId,
      email: stored.email,
      displayName: stored.displayName,
      tenantExternalId: stored.tenantExternalId
    }
  };
}

export function signInSkeleton(): AuthSession {
  const seededSession: StoredSession = {
    userId: 'demo-user-id',
    email: 'admin@example.com',
    displayName: 'Demo Admin',
    tenantExternalId: 'demo-tenant-id'
  };
  window.localStorage.setItem(SESSION_STORAGE_KEY, JSON.stringify(seededSession));
  return getAuthSession();
}

export function signOutSkeleton(): void {
  window.localStorage.removeItem(SESSION_STORAGE_KEY);
}
