import type { TenantConsentStatus } from '@purview/contracts';

type ConsentStatusBannerProps = {
  status: TenantConsentStatus | null;
};

export function ConsentStatusBanner({ status }: ConsentStatusBannerProps) {
  if (!status) {
    return <p>Consent status unavailable.</p>;
  }

  if (status.consentCompleted) {
    return <p>Tenant consent complete.</p>;
  }

  return <p>Admin consent is required before using Purview worker features.</p>;
}
