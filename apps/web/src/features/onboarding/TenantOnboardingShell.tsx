import type { AuthSession, TenantConsentStatus } from '@purview/contracts';

import { ConsentStatusBanner } from './ConsentStatusBanner';

type TenantOnboardingShellProps = {
  session: AuthSession;
  consentStatus: TenantConsentStatus | null;
  onRefreshConsent: () => void;
  onCompleteConsent: () => void;
};

export function TenantOnboardingShell({
  session,
  consentStatus,
  onRefreshConsent,
  onCompleteConsent
}: TenantOnboardingShellProps) {
  if (!session.isAuthenticated || !session.user) {
    return null;
  }

  return (
    <section>
      <h2>Tenant onboarding</h2>
      <ConsentStatusBanner status={consentStatus} />
      <button onClick={onRefreshConsent} type="button">
        Refresh consent status
      </button>
      {!consentStatus?.consentCompleted && (
        <button onClick={onCompleteConsent} type="button">
          I completed admin consent
        </button>
      )}
    </section>
  );
}
