import type { AuthSession } from '@purview/contracts';

type AuthStatusProps = {
  session: AuthSession;
  onSignIn: () => void;
  onSignOut: () => void;
};

export function AuthStatus({ session, onSignIn, onSignOut }: AuthStatusProps) {
  if (!session.isAuthenticated || !session.user) {
    return (
      <section>
        <h2>Authentication</h2>
        <p>Not signed in.</p>
        <button onClick={onSignIn} type="button">
          Sign in
        </button>
      </section>
    );
  }

  return (
    <section>
      <h2>Authentication</h2>
      <p>Signed in as {session.user.displayName}</p>
      <p>Tenant: {session.user.tenantExternalId}</p>
      <button onClick={onSignOut} type="button">
        Sign out
      </button>
    </section>
  );
}
