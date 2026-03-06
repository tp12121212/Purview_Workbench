import { useEffect, useState } from 'react';
import type {
  AuthState,
  ProtectedAction,
  PublicAppMetadata,
  PublicLibraryItem,
  TenantConsentStatus
} from '@purview/contracts';

import { fetchPublicDlpLibrary, fetchPublicMetadata, fetchPublicSitLibrary } from './api/publicApi';
import {
  fetchJobStatus,
  runTestDataClassification,
  runTestTextExtraction
} from './api/protectedJobsApi';
import { fetchConsentStatus } from './api/tenantOnboardingApi';
import { AuthStatus } from './auth/AuthStatus';
import { getAuthSession, getEntraAuthConfig, signInSkeleton, signOutSkeleton } from './auth/msalClient';

const NAV_ITEMS = ['home', 'sit-library', 'dlp-library', 'rule-packs', 'test-console', 'help'] as const;
type NavItem = (typeof NAV_ITEMS)[number];

export function App() {
  const [authState, setAuthState] = useState<AuthState>({
    session: getAuthSession(),
    pendingProtectedAction: null
  });
  const [activePage, setActivePage] = useState<NavItem>('home');
  const [consentStatus, setConsentStatus] = useState<TenantConsentStatus | null>(null);
  const [publicSitItems, setPublicSitItems] = useState<PublicLibraryItem[]>([]);
  const [publicDlpItems, setPublicDlpItems] = useState<PublicLibraryItem[]>([]);
  const [metadata, setMetadata] = useState<PublicAppMetadata | null>(null);
  const [jobMessage, setJobMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const authConfig = getEntraAuthConfig();

  useEffect(() => {
    void fetchPublicMetadata().then(setMetadata).catch((err: Error) => setError(err.message));
    void fetchPublicSitLibrary().then(setPublicSitItems).catch((err: Error) => setError(err.message));
    void fetchPublicDlpLibrary().then(setPublicDlpItems).catch((err: Error) => setError(err.message));
  }, []);

  useEffect(() => {
    if (!authState.session.isAuthenticated || !authState.session.accessToken) {
      setConsentStatus(null);
      return;
    }

    if (
      authState.pendingProtectedAction === 'VIEW_TENANT_CONSENT_STATUS' ||
      authState.pendingProtectedAction === 'RUN_TEST_TEXT_EXTRACTION' ||
      authState.pendingProtectedAction === 'RUN_TEST_DATA_CLASSIFICATION'
    ) {
      void fetchConsentStatus(authState.session.accessToken)
        .then((status) => {
          setConsentStatus(status);
          setError(null);
        })
        .catch((err: Error) => setError(err.message));
    }
  }, [authState.pendingProtectedAction, authState.session.accessToken, authState.session.isAuthenticated]);

  async function runProtectedAction(action: ProtectedAction) {
    if (!authState.session.isAuthenticated || !authState.session.accessToken || !authState.session.user) {
      setAuthState((current) => ({
        ...current,
        pendingProtectedAction: action
      }));
      return;
    }

    if (!consentStatus?.consentCompleted) {
      setAuthState((current) => ({ ...current, pendingProtectedAction: action }));
      return;
    }

    if (action === 'RUN_TEST_TEXT_EXTRACTION') {
      const queued = await runTestTextExtraction(authState.session.accessToken, {
        tenantId: authState.session.user.tenantExternalId,
        fileName: 'sample.txt',
        textSample: 'This is a placeholder extraction sample.'
      });
      const status = await fetchJobStatus(authState.session.accessToken, queued.jobId);
      setJobMessage(`${status.jobType} job ${status.jobId} is ${status.status}`);
      return;
    }

    if (action === 'RUN_TEST_DATA_CLASSIFICATION') {
      const queued = await runTestDataClassification(authState.session.accessToken, {
        tenantId: authState.session.user.tenantExternalId,
        textSample: 'Sample classified text payload',
        expectedLabels: ['Confidential']
      });
      const status = await fetchJobStatus(authState.session.accessToken, queued.jobId);
      setJobMessage(`${status.jobType} job ${status.jobId} is ${status.status}`);
    }
  }


  useEffect(() => {
    if (authState.session.isAuthenticated && authState.pendingProtectedAction) {
      setActivePage('test-console');
    }
  }, [authState.pendingProtectedAction, authState.session.isAuthenticated]);

  const signInAndResume = async () => {
    const nextSession = signInSkeleton();
    setAuthState((current) => ({
      ...current,
      session: nextSession
    }));
  };

  const renderPage = () => {
    if (activePage === 'home') {
      return <p>Public dashboard for browsing templates and learning how protected tenant actions work.</p>;
    }
    if (activePage === 'sit-library') {
      return (
        <section>
          <h2>Public SIT templates</h2>
          <ul>
            {publicSitItems.map((item) => (
              <li key={item.id}>
                <strong>{item.title}</strong>: {item.summary}
              </li>
            ))}
          </ul>
        </section>
      );
    }
    if (activePage === 'dlp-library') {
      return (
        <section>
          <h2>Public DLP templates</h2>
          <ul>
            {publicDlpItems.map((item) => (
              <li key={item.id}>
                <strong>{item.title}</strong>: {item.summary}
              </li>
            ))}
          </ul>
        </section>
      );
    }
    if (activePage === 'rule-packs') {
      return <p>Rule packs can be imported/exported after signing in and connecting tenant consent.</p>;
    }
    if (activePage === 'help') {
      return <p>How it works: browse publicly, then authenticate only when running tenant-protected actions.</p>;
    }

    return (
      <section>
        <h2>Protected test console</h2>
        <p>Viewable publicly. Running tests requires auth and tenant consent.</p>
        <button onClick={() => void runProtectedAction('RUN_TEST_TEXT_EXTRACTION')} type="button">
          Run Test-TextExtraction
        </button>
        <button onClick={() => void runProtectedAction('RUN_TEST_DATA_CLASSIFICATION')} type="button">
          Run Test-DataClassification
        </button>
        {jobMessage && <p>{jobMessage}</p>}
      </section>
    );
  };

  return (
    <main>
      <h1>Purview Workbench</h1>
      <p>Phase 2 public-first shell with protected action gating.</p>
      <p>
        Entra authority: <code>{authConfig.authority || 'not configured'}</code>
      </p>
      {metadata && (
        <p>
          {metadata.productName} · support: {metadata.supportEmail}
        </p>
      )}

      <AuthStatus
        session={authState.session}
        onSignIn={() => void signInAndResume()}
        onSignOut={() => {
          signOutSkeleton();
          setAuthState({ session: getAuthSession(), pendingProtectedAction: null });
          setConsentStatus(null);
          setJobMessage(null);
        }}
      />

      {authState.pendingProtectedAction && !authState.session.isAuthenticated && (
        <section role="alert">
          <p>Sign in required for protected action: {authState.pendingProtectedAction}</p>
          <button onClick={() => void signInAndResume()} type="button">
            Continue with sign in
          </button>
        </section>
      )}

      {authState.session.isAuthenticated && authState.pendingProtectedAction && consentStatus && !consentStatus.consentCompleted && (
        <section role="alert">
          <p>Tenant admin consent is required before running protected tenant operations.</p>
        </section>
      )}

      <nav aria-label="Public navigation">
        {NAV_ITEMS.map((item) => (
          <button key={item} onClick={() => setActivePage(item)} type="button">
            {item}
          </button>
        ))}
      </nav>

      {error && <p role="alert">{error}</p>}
      {renderPage()}
    </main>
  );
}
