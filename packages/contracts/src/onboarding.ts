export type TenantSummary = {
  id: string;
  externalTenantId: string;
  displayName: string;
  consentCompleted: boolean;
};

export type TenantConsentStatus = {
  tenantId: string;
  consentCompleted: boolean;
  consentCompletedAt: string | null;
};
