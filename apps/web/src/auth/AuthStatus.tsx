import { createAuthSessionSkeleton } from './msalClient';

export function AuthStatus() {
  const session = createAuthSessionSkeleton();
  return (
    <section>
      <h2>Authentication</h2>
      <p>Skeleton only. Tenant: {session.tenantId ?? 'not connected'}</p>
    </section>
  );
}
