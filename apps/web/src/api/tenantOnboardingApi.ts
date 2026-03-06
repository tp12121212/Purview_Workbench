import type { TenantConsentStatus } from '@purview/contracts';

const API_BASE = import.meta.env.VITE_API_BASE_URL ?? '';

export async function fetchConsentStatus(accessToken: string): Promise<TenantConsentStatus> {
  const response = await fetch(`${API_BASE}/api/v1/tenants/me/consent-status`, {
    headers: { Authorization: `Bearer ${accessToken}` }
  });
  if (!response.ok) {
    throw new Error('Unable to fetch consent status');
  }

  const data = (await response.json()) as {
    tenant_id: string;
    consent_completed: boolean;
    consent_completed_at: string | null;
  };

  return {
    tenantId: data.tenant_id,
    consentCompleted: data.consent_completed,
    consentCompletedAt: data.consent_completed_at
  };
}

export async function completeConsent(accessToken: string): Promise<TenantConsentStatus> {
  const response = await fetch(`${API_BASE}/api/v1/tenants/consent-complete`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ display_name: 'Connected tenant' })
  });
  if (!response.ok) {
    throw new Error('Unable to complete consent');
  }

  const data = (await response.json()) as {
    tenant_id: string;
    consent_completed: boolean;
    consent_completed_at: string | null;
  };

  return {
    tenantId: data.tenant_id,
    consentCompleted: data.consent_completed,
    consentCompletedAt: data.consent_completed_at
  };
}
