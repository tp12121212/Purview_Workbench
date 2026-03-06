export type AuthUser = {
  userId: string;
  email: string;
  displayName: string;
  tenantExternalId: string;
};

export type AuthSession = {
  isAuthenticated: boolean;
  user: AuthUser | null;
  accessToken: string | null;
};

export type EntraAuthConfig = {
  clientId: string;
  authority: string;
  redirectUri: string;
  apiAudience: string;
};
