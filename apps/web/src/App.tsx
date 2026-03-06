import { useEffect, useState } from 'react';
import type { AuthSession, TenantConsentStatus } from '@purview/contracts';

import { fetchConsentStatus, completeConsent } from './api/tenantOnboardingApi';
import { AuthStatus } from './auth/AuthStatus';
import { getAuthSession, getEntraAuthConfig, signInSkeleton, signOutSkeleton } from './auth/msalClient';
import { TenantOnboardingShell } from './features/onboarding/TenantOnboardingShell';

export function App() {
  const [session, setSession] = useState<AuthSession>(() => getAuthSession());
  const [consentStatus, setConsentStatus] = useState<TenantConsentStatus | null>(null);
  const [error, setError] = useState<string | null>(null);

  const authConfig = getEntraAuthConfig();

  const refreshConsentStatus = async () => {
    if (!session.accessToken) {
      return;
    }

    try {
      const nextStatus = await fetchConsentStatus(session.accessToken);
      setConsentStatus(nextStatus);
      setError(null);
    } catch (err) {
      setError((err as Error).message);
    }
  };

  const handleConsentComplete = async () => {
    if (!session.accessToken) {
      return;
    }

    try {
      const nextStatus = await completeConsent(session.accessToken);
      setConsentStatus(nextStatus);
      setError(null);
    } catch (err) {
      setError((err as Error).message);
    }
  };

  useEffect(() => {
    if (session.isAuthenticated) {
      void refreshConsentStatus();
    } else {
      setConsentStatus(null);
      setError(null);
    }
  }, [session.isAuthenticated]);

  return (
    <main>
      <h1>Purview Workbench</h1>
      <p>Phase 1 auth + tenant onboarding scaffold.</p>
      <p>
        Entra authority: <code>{authConfig.authority || 'not configured'}</code>
      </p>
      <AuthStatus
        session={session}
        onSignIn={() => setSession(signInSkeleton())}
        onSignOut={() => {
          signOutSkeleton();
          setSession(getAuthSession());
        }}
      />
      {error && <p role="alert">{error}</p>}
      <TenantOnboardingShell
        session={session}
        consentStatus={consentStatus}
        onRefreshConsent={refreshConsentStatus}
        onCompleteConsent={handleConsentComplete}
      />
    </main>
  );
}
