export type AuthSession = {
  tenantId?: string;
  userId?: string;
  backendAccessToken?: string;
};

export function createAuthSessionSkeleton(): AuthSession {
  return {};
}
