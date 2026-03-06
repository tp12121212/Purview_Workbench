import type { AuthSession } from '@purview/contracts';

type AuthStatusProps = {
  session: AuthSession;
  onSignIn: () => void;
  onSignOut: () => void;
  compact?: boolean;
};

export function AuthStatus({ session, onSignIn, onSignOut, compact = false }: AuthStatusProps) {
  if (!session.isAuthenticated || !session.user) {
    return compact ? (
      <button className="btn primary" onClick={onSignIn} type="button">
        Sign in
      </button>
    ) : (
      <section>
        <h2>Authentication</h2>
        <p>Not signed in.</p>
        <button className="btn primary" onClick={onSignIn} type="button">
          Sign in
        </button>
      </section>
    );
  }

  return compact ? (
    <>
      <span>Signed in as {session.user.displayName}</span>
      <button className="btn" onClick={onSignOut} type="button">
        Sign out
      </button>
    </>
  ) : (
    <section>
      <h2>Authentication</h2>
      <p>Signed in as {session.user.displayName}</p>
      <p>Tenant: {session.user.tenantExternalId}</p>
      <button className="btn" onClick={onSignOut} type="button">
        Sign out
      </button>
    </section>
  );
}
