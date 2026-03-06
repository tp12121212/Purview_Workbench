import type { AuthSession, EntraAuthConfig } from '@purview/contracts';

let inMemorySession: AuthSession = {
  isAuthenticated: false,
  user: null,
  accessToken: null
};

export function getEntraAuthConfig(): EntraAuthConfig {
  return {
    clientId: import.meta.env.VITE_ENTRA_CLIENT_ID ?? '',
    authority: import.meta.env.VITE_ENTRA_AUTHORITY ?? '',
    redirectUri: import.meta.env.VITE_ENTRA_REDIRECT_URI ?? '',
    apiAudience: import.meta.env.VITE_API_AUDIENCE ?? ''
  };
}

function createDevToken(): string {
  const payload = {
    sub: 'demo-user-id',
    email: 'admin@example.com',
    name: 'Demo Admin',
    tenant_id: 'demo-tenant-id',
    is_admin: true
  };

  const encoded = btoa(JSON.stringify(payload))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');

  return `dev.${encoded}`;
}

export function getAuthSession(): AuthSession {
  return inMemorySession;
}

export function signInSkeleton(): AuthSession {
  inMemorySession = {
    isAuthenticated: true,
    accessToken: createDevToken(),
    user: {
      userId: 'demo-user-id',
      email: 'admin@example.com',
      displayName: 'Demo Admin',
      tenantExternalId: 'demo-tenant-id'
    }
  };

  return inMemorySession;
}

export function signOutSkeleton(): void {
  inMemorySession = {
    isAuthenticated: false,
    user: null,
    accessToken: null
  };
}
