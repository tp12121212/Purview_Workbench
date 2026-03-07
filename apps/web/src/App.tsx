import { useEffect, useMemo, useState } from 'react';
import type {
  AuthSession,
  PatternDetail,
  PatternSummary,
  ProtectedAction,
  TenantConsentStatus
} from '@purview/contracts';
import { Navigate, NavLink, Outlet, Route, Routes, useLocation, useNavigate } from 'react-router-dom';

import { fetchPublicPatternDetail, fetchPublicPatterns } from './api/publicApi';
import { AuthStatus } from './auth/AuthStatus';
import { getAuthSession, signInSkeleton, signOutSkeleton } from './auth/msalClient';
import dashboardData from './mocks/design-pack-v0.1/dashboard.json';
import dlpLibraryData from './mocks/design-pack-v0.1/dlp-library.json';
import helpArticlesData from './mocks/design-pack-v0.1/help-articles.json';
import rulePacksData from './mocks/design-pack-v0.1/rule-packs.json';
import sitLibraryData from './mocks/design-pack-v0.1/sit-library.json';
import testResultData from './mocks/design-pack-v0.1/test-console-results.json';
import type {
  DashboardData,
  DlpLibraryData,
  HelpArticlesData,
  RulePacksData,
  SitLibraryData,
  TestConsoleResults
} from './types';

type GateRequest = { action: ProtectedAction; returnTo: string } | null;

type JobState = 'idle' | 'queued' | 'running' | 'completed' | 'failed';

const themeStorageKey = 'purview-theme';

function readStoredTheme(): 'light' | 'dark' | null {
  const storage = globalThis.localStorage as Storage | undefined;
  if (!storage || typeof storage.getItem !== 'function') {
    return null;
  }
  const value = storage.getItem(themeStorageKey);
  return value === 'dark' || value === 'light' ? value : null;
}

function writeStoredTheme(theme: 'light' | 'dark'): void {
  const storage = globalThis.localStorage as Storage | undefined;
  if (!storage || typeof storage.setItem !== 'function') {
    return;
  }
  storage.setItem(themeStorageKey, theme);
}

function useThemePreference() {
  const [theme, setTheme] = useState<'light' | 'dark'>(() => readStoredTheme() ?? 'light');

  useEffect(() => {
    document.documentElement.dataset.theme = theme;
    writeStoredTheme(theme);
  }, [theme]);

  return { theme, toggleTheme: () => setTheme((current) => (current === 'light' ? 'dark' : 'light')) };
}

function useProtectedActionGate(
  session: AuthSession,
  consent: TenantConsentStatus | null,
  setGateRequest: (request: GateRequest) => void
) {
  const location = useLocation();

  const requestAction = (action: ProtectedAction): 'allowed' | 'auth-required' | 'consent-required' => {
    if (!session.isAuthenticated) {
      setGateRequest({ action, returnTo: location.pathname });
      return 'auth-required';
    }
    if (!consent?.consentCompleted) {
      setGateRequest({ action, returnTo: '/settings/tenant' });
      return 'consent-required';
    }
    return 'allowed';
  };

  return { requestAction };
}

const navItems = [
  ['/', 'Home'],
  ['/sit-library', 'SIT Library'],
  ['/pattern-library', 'Pattern Library'],
  ['/dlp-library', 'DLP Library'],
  ['/rule-packs', 'Rule Packs'],
  ['/test-console', 'Test Console'],
  ['/help', 'Help'],
  ['/settings', 'Settings']
] as const;

export function App() {
  const navigate = useNavigate();
  const [session, setSession] = useState<AuthSession>(getAuthSession());
  const [consentStatus, setConsentStatus] = useState<TenantConsentStatus | null>(null);
  const [gateRequest, setGateRequest] = useState<GateRequest>(null);
  const [jobState, setJobState] = useState<JobState>('idle');
  const [error, setError] = useState<string | null>(null);
  const { theme, toggleTheme } = useThemePreference();

  const gate = useProtectedActionGate(session, consentStatus, setGateRequest);

  const data = useMemo(
    () => ({
      dashboard: dashboardData as DashboardData,
      sit: sitLibraryData as SitLibraryData,
      dlp: dlpLibraryData as DlpLibraryData,
      rules: rulePacksData as RulePacksData,
      help: helpArticlesData as HelpArticlesData,
      testResult: testResultData as TestConsoleResults
    }),
    []
  );

  const signInAndResume = () => {
    const nextSession = signInSkeleton();
    setSession(nextSession);
    if (!consentStatus) {
      setConsentStatus({
        tenantId: nextSession.user?.tenantExternalId ?? 'demo-tenant-id',
        consentCompleted: false,
        consentCompletedAt: null
      });
    }
    if (gateRequest) {
      navigate(gateRequest.returnTo);
    }
  };

  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand">Purview Workbench</div>
        <nav className="nav" aria-label="Primary">
          {navItems.map(([path, label]) => (
            <NavLink key={path} to={path} className={({ isActive }) => (isActive ? 'active' : '')} end={path === '/'}>
              {label}
            </NavLink>
          ))}
        </nav>
      </aside>
      <div className="main">
        <header className="topbar">
          <div>Public-first compliance automation shell</div>
          <div className="actions">
            <button className="btn" onClick={toggleTheme} type="button">
              Theme: {theme}
            </button>
            <AuthStatus
              session={session}
              onSignIn={signInAndResume}
              onSignOut={() => {
                signOutSkeleton();
                setSession(getAuthSession());
                setConsentStatus(null);
              }}
              compact
            />
          </div>
        </header>
        <main className="content">
          {error ? <div className="alert error">{error}</div> : null}
          {gateRequest && !session.isAuthenticated ? (
            <div className="alert" role="alert">
              Sign in required for protected action: {gateRequest.action}
            </div>
          ) : null}
          <Routes>
            <Route path="/" element={<HomePage data={data.dashboard} />} />
            <Route path="/sit-library" element={<SitLibraryPage data={data.sit} />} />
            <Route path="/pattern-library" element={<PatternLibraryPage />} />
            <Route path="/dlp-library" element={<DlpLibraryPage data={data.dlp} />} />
            <Route path="/rule-packs" element={<RulePacksPage data={data.rules} gate={gate} />} />
            <Route
              path="/test-console"
              element={<TestConsolePage data={data.testResult} gate={gate} jobState={jobState} setJobState={setJobState} />}
            />
            <Route path="/help" element={<HelpPage data={data.help} />} />
            <Route path="/settings" element={<SettingsGuard session={session} />}>
              <Route index element={<SettingsIndex consentStatus={consentStatus} />} />
              <Route
                path="tenant"
                element={
                  <TenantPage
                    consentStatus={consentStatus}
                    onConnect={() =>
                      setConsentStatus({
                        tenantId: session.user?.tenantExternalId ?? 'demo-tenant-id',
                        consentCompleted: true,
                        consentCompletedAt: null
                      })
                    }
                  />
                }
              />
              <Route path="consent" element={<ConsentPage consentStatus={consentStatus} />} />
            </Route>
            <Route path="/sit-editor" element={<PlaceholderPage title="SIT Editor" />} />
            <Route path="/dlp-builder" element={<PlaceholderPage title="DLP Builder" />} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </main>
      </div>
    </div>
  );
}

function PageHeader({ title, subtitle }: { title: string; subtitle: string }) {
  return (
    <header className="page-header">
      <h1>{title}</h1>
      <p>{subtitle}</p>
    </header>
  );
}

function HomePage({ data }: { data: DashboardData }) {
  return (
    <section>
      <PageHeader title="Home / Dashboard" subtitle="Browse public content and run tenant actions only when needed." />
      <div className="grid kpi">
        {data.kpis.map((kpi) => (
          <article className="card" key={kpi.id}>
            <div>{kpi.label}</div>
            <div className="kpi-value">{kpi.value}</div>
          </article>
        ))}
      </div>
      <div className="card" style={{ marginTop: 16 }}>
        <h3>Recently viewed templates</h3>
        {data.recentTemplates.map((item) => (
          <div key={item.id}>
            {item.name} <span className="badge">{item.type}</span>
          </div>
        ))}
      </div>
    </section>
  );
}

function SitLibraryPage({ data }: { data: SitLibraryData }) {
  const [query, setQuery] = useState('');
  const items = data.items.filter(
    (item) => item.name.toLowerCase().includes(query.toLowerCase()) || item.category.toLowerCase().includes(query.toLowerCase())
  );
  return (
    <section>
      <PageHeader title="Public SIT Library" subtitle="Search deterministic templates by region and category." />
      <div className="card">
        <div className="toolbar">
          <input className="input" value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search SIT templates" />
        </div>
        <table className="table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Category</th>
              <th>Region</th>
              <th>Patterns</th>
              <th>Keywords</th>
            </tr>
          </thead>
          <tbody>
            {items.map((item) => (
              <tr key={item.id}>
                <td>{item.name}</td>
                <td>{item.category}</td>
                <td>{item.region}</td>
                <td>{item.patterns}</td>
                <td>{item.keywords.join(', ')}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}

function PatternLibraryPage() {
  const [query, setQuery] = useState('');
  const [typeFilter, setTypeFilter] = useState('');
  const [jurisdictionFilter, setJurisdictionFilter] = useState('');
  const [regulationFilter, setRegulationFilter] = useState('');
  const [exportFilter, setExportFilter] = useState('');

  const [items, setItems] = useState<PatternSummary[]>([]);
  const [total, setTotal] = useState(0);
  const [selectedSlug, setSelectedSlug] = useState<string>('');
  const [detail, setDetail] = useState<PatternDetail | null>(null);
  const [loading, setLoading] = useState(false);
  const [loadingDetail, setLoadingDetail] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);

    fetchPublicPatterns({
      q: query || undefined,
      type: typeFilter || undefined,
      jurisdiction: jurisdictionFilter || undefined,
      regulation: regulationFilter || undefined,
      export: exportFilter || undefined,
      limit: 100
    })
      .then((response) => {
        if (cancelled) {
          return;
        }
        setItems(response.items);
        setTotal(response.total);

        if (!selectedSlug && response.items.length > 0) {
          setSelectedSlug(response.items[0].slug);
        }
        if (selectedSlug && !response.items.some((item) => item.slug === selectedSlug)) {
          setSelectedSlug(response.items.length > 0 ? response.items[0].slug : '');
        }
      })
      .catch((err: unknown) => {
        if (cancelled) {
          return;
        }
        setItems([]);
        setTotal(0);
        setSelectedSlug('');
        setDetail(null);
        setError(err instanceof Error ? err.message : 'Unable to load patterns');
      })
      .finally(() => {
        if (!cancelled) {
          setLoading(false);
        }
      });

    return () => {
      cancelled = true;
    };
  }, [query, typeFilter, jurisdictionFilter, regulationFilter, exportFilter, selectedSlug]);

  useEffect(() => {
    if (!selectedSlug) {
      setDetail(null);
      return;
    }

    let cancelled = false;
    setLoadingDetail(true);

    fetchPublicPatternDetail(selectedSlug)
      .then((result) => {
        if (!cancelled) {
          setDetail(result);
        }
      })
      .catch(() => {
        if (!cancelled) {
          setDetail(null);
        }
      })
      .finally(() => {
        if (!cancelled) {
          setLoadingDetail(false);
        }
      });

    return () => {
      cancelled = true;
    };
  }, [selectedSlug]);

  return (
    <section>
      <PageHeader
        title="Pattern Library"
        subtitle="Browse, filter, and inspect imported pattern/template entities with structured detail sections."
      />
      <div className="card" style={{ marginBottom: 16 }}>
        <div className="toolbar" style={{ display: 'grid', gridTemplateColumns: 'repeat(5, minmax(120px, 1fr))', gap: 8 }}>
          <input className="input" value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search" />
          <input className="input" value={typeFilter} onChange={(e) => setTypeFilter(e.target.value)} placeholder="Type" />
          <input
            className="input"
            value={jurisdictionFilter}
            onChange={(e) => setJurisdictionFilter(e.target.value)}
            placeholder="Jurisdiction"
          />
          <input
            className="input"
            value={regulationFilter}
            onChange={(e) => setRegulationFilter(e.target.value)}
            placeholder="Regulation"
          />
          <input className="input" value={exportFilter} onChange={(e) => setExportFilter(e.target.value)} placeholder="Export" />
        </div>
      </div>

      {error ? <div className="alert error">{error}</div> : null}

      <div className="grid two">
        <div className="card">
          <h3>Patterns ({total})</h3>
          {loading ? <p>Loading patterns...</p> : null}
          {!loading && items.length === 0 ? <p>No patterns found.</p> : null}
          <table className="table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Type</th>
                <th>Risk</th>
                <th>Engine</th>
              </tr>
            </thead>
            <tbody>
              {items.map((item) => (
                <tr
                  key={item.id}
                  onClick={() => setSelectedSlug(item.slug)}
                  style={{ cursor: 'pointer', background: selectedSlug === item.slug ? 'rgba(89, 133, 255, 0.1)' : undefined }}
                >
                  <td>{item.name}</td>
                  <td>{item.pattern_type}</td>
                  <td>{item.risk_rating ?? '-'}</td>
                  <td>{item.engine}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="card">
          <h3>Pattern Detail</h3>
          {loadingDetail ? <p>Loading detail...</p> : null}
          {!loadingDetail && !detail ? <p>Select a pattern to inspect structured metadata.</p> : null}
          {detail ? <PatternDetailPanel detail={detail} /> : null}
        </div>
      </div>
    </section>
  );
}

function PatternDetailPanel({ detail }: { detail: PatternDetail }) {
  const renderEntityList = (title: string, entities: Array<{ id: string; payload: Record<string, unknown> }>) => (
    <div style={{ marginTop: 12 }}>
      <h4>{title} ({entities.length})</h4>
      {entities.length === 0 ? <p>-</p> : null}
      {entities.slice(0, 8).map((entity) => (
        <pre key={entity.id} className="code" style={{ whiteSpace: 'pre-wrap' }}>
          {JSON.stringify(entity.payload, null, 2)}
        </pre>
      ))}
    </div>
  );

  return (
    <div>
      <p>
        <strong>{detail.name}</strong> <span className="badge">{detail.pattern_type}</span>{' '}
        <span className="badge">{detail.confidence}</span>
      </p>
      <p>{detail.description}</p>
      <p>
        Scope: {detail.scope} | Engine: {detail.engine} | Risk: {detail.risk_rating ?? '-'}
      </p>
      <p>
        Jurisdictions: {detail.jurisdictions.join(', ') || '-'}
        <br />
        Regulations: {detail.regulations.join(', ') || '-'}
        <br />
        Categories: {detail.data_categories.join(', ') || '-'}
        <br />
        Exports: {detail.exports.join(', ') || '-'}
      </p>

      {renderEntityList('Regexes', detail.regexes)}
      {renderEntityList('Keyword Groups', detail.keyword_groups)}
      {renderEntityList('Validators', detail.validators)}
      {renderEntityList('Filters', detail.filters)}
      {renderEntityList('Pattern Tiers', detail.pattern_tiers)}
      {renderEntityList('Test Cases', detail.test_cases)}
      {renderEntityList('False Positives / Mitigation', detail.false_positives)}

      <div style={{ marginTop: 12 }}>
        <h4>Purview Configuration</h4>
        <pre className="code" style={{ whiteSpace: 'pre-wrap' }}>
          {JSON.stringify(detail.purview, null, 2)}
        </pre>
      </div>
    </div>
  );
}

function DlpLibraryPage({ data }: { data: DlpLibraryData }) {
  const [query, setQuery] = useState('');
  const items = data.items.filter(
    (item) => item.name.toLowerCase().includes(query.toLowerCase()) || item.workloads.join(' ').toLowerCase().includes(query.toLowerCase())
  );
  return (
    <section>
      <PageHeader title="Public DLP Library" subtitle="Browse policy templates by workload and mode." />
      <div className="card">
        <div className="toolbar">
          <input className="input" value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search DLP templates" />
        </div>
        <table className="table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Workloads</th>
              <th>Severity</th>
              <th>Mode</th>
              <th>Rules</th>
            </tr>
          </thead>
          <tbody>
            {items.map((item) => (
              <tr key={item.id}>
                <td>{item.name}</td>
                <td>{item.workloads.join(', ')}</td>
                <td>
                  <span className={`badge ${item.severity === 'high' ? 'error' : 'warning'}`}>{item.severity}</span>
                </td>
                <td>{item.mode}</td>
                <td>{item.rules}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}

function RulePacksPage({
  data,
  gate
}: {
  data: RulePacksData;
  gate: { requestAction: (action: ProtectedAction) => 'allowed' | 'auth-required' | 'consent-required' };
}) {
  return (
    <section>
      <PageHeader title="Rule Packs" subtitle="Learn the pack model and gate import/export tenant actions." />
      <div className="grid two">
        {data.items.map((item) => (
          <article className="card" key={item.id}>
            <h3>{item.name}</h3>
            <p>{item.summary}</p>
            <p>
              <span className="badge">SIT {item.sitCount}</span> <span className="badge">DLP {item.dlpCount}</span>
            </p>
          </article>
        ))}
      </div>
      <div className="card" style={{ marginTop: 16 }}>
        <button className="btn primary" onClick={() => gate.requestAction('SYNC_TENANT_ARTIFACTS')} type="button">
          Protected: Import/Export
        </button>
      </div>
    </section>
  );
}

function TestConsolePage({
  data,
  gate,
  jobState,
  setJobState
}: {
  data: TestConsoleResults;
  gate: { requestAction: (action: ProtectedAction) => 'allowed' | 'auth-required' | 'consent-required' };
  jobState: JobState;
  setJobState: (state: JobState) => void;
}) {
  const navigate = useNavigate();
  const [input, setInput] = useState('SSN 078-05-1120 and ABA 021000021');
  const onRun = () => {
    const result = gate.requestAction('RUN_TEST_DATA_CLASSIFICATION');
    if (result === 'consent-required') {
      navigate('/settings/tenant');
      return;
    }
    if (result !== 'allowed') {
      return;
    }
    setJobState('queued');
    setTimeout(() => setJobState('running'), 50);
    setTimeout(() => setJobState('completed'), 100);
  };
  return (
    <section>
      <PageHeader
        title="Test Console"
        subtitle="Prepare input publicly and execute with protected tenant auth and consent."
      />
      <div className="grid two">
        <div className="card">
          <h3>Input</h3>
          <textarea className="textarea" value={input} onChange={(e) => setInput(e.target.value)} />
          <div style={{ marginTop: 10 }}>
            <button className="btn primary" onClick={onRun} type="button">
              Run Test-DataClassification
            </button>
          </div>
        </div>
        <div className="card">
          <h3>Result + Job timeline</h3>
          <p>
            <span className={`badge ${jobState === 'completed' ? 'success' : jobState === 'failed' ? 'error' : 'warning'}`}>
              State: {jobState === 'idle' ? data.job.state : jobState}
            </span>
          </p>
          <p>Job ID: {data.job.id}</p>
          <table className="table">
            <thead>
              <tr>
                <th>Template</th>
                <th>Match</th>
                <th>Confidence</th>
              </tr>
            </thead>
            <tbody>
              {data.detections.map((det) => (
                <tr key={det.id}>
                  <td>{det.templateId}</td>
                  <td>{det.matchText}</td>
                  <td>{det.confidence}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </section>
  );
}

function HelpPage({ data }: { data: HelpArticlesData }) {
  return (
    <section>
      <PageHeader title="Help / Docs / How it works" subtitle="Understand auth-on-demand and consent requirements." />
      <div className="grid two">
        {data.articles.map((article) => (
          <article className="card" key={article.id}>
            <h3>{article.title}</h3>
            <p>{article.summary}</p>
          </article>
        ))}
      </div>
    </section>
  );
}

function SettingsGuard({ session }: { session: AuthSession }) {
  const location = useLocation();
  if (!session.isAuthenticated) {
    return (
      <div className="alert">
        Settings requires sign in. Return to public pages and authenticate when ready. ({location.pathname})
      </div>
    );
  }
  return <Outlet />;
}

function SettingsIndex({ consentStatus }: { consentStatus: TenantConsentStatus | null }) {
  return (
    <section>
      <PageHeader title="Settings" subtitle="Tenant-scoped session and connection controls." />
      <div className="card">Consent state: {consentStatus?.consentCompleted ? 'Connected' : 'Consent required'}</div>
    </section>
  );
}

function TenantPage({
  consentStatus,
  onConnect
}: {
  consentStatus: TenantConsentStatus | null;
  onConnect: () => void;
}) {
  return (
    <section>
      <PageHeader title="Tenant Connection" subtitle="Complete admin consent to unlock protected actions." />
      <div className="card">
        <p>
          Status:{' '}
          <span className={`badge ${consentStatus?.consentCompleted ? 'success' : 'warning'}`}>
            {consentStatus?.consentCompleted ? 'Consent complete' : 'Consent required'}
          </span>
        </p>
        {!consentStatus?.consentCompleted ? (
          <button className="btn primary" onClick={onConnect} type="button">
            Mark consent complete
          </button>
        ) : null}
      </div>
    </section>
  );
}

function ConsentPage({ consentStatus }: { consentStatus: TenantConsentStatus | null }) {
  return (
    <section>
      <PageHeader title="Consent Status" subtitle="Review why consent is required for tenant execution." />
      <div className="card">
        {consentStatus?.consentCompleted
          ? 'All tenant scopes approved.'
          : 'Missing admin consent for protected execution. Go to Tenant Connection.'}
      </div>
    </section>
  );
}

function PlaceholderPage({ title }: { title: string }) {
  return (
    <section>
      <PageHeader title={title} subtitle="Future module placeholder for later phase." />
      <div className="card">This area remains intentionally non-functional in Phase A.</div>
    </section>
  );
}
