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

export type ProtectedAction =
  | 'RUN_TEST_TEXT_EXTRACTION'
  | 'RUN_TEST_DATA_CLASSIFICATION'
  | 'VIEW_TENANT_CONSENT_STATUS'
  | 'SYNC_TENANT_ARTIFACTS';

export type AuthState = {
  session: AuthSession;
  pendingProtectedAction: ProtectedAction | null;
};

export type EntraAuthConfig = {
  clientId: string;
  authority: string;
  redirectUri: string;
  apiAudience: string;
};
