/** @vitest-environment jsdom */

import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { App } from './App';

const mockFetch = vi.fn();

vi.stubGlobal('fetch', mockFetch);

describe('Phase 2 public-first shell', () => {
  afterEach(() => {
    cleanup();
  });

  beforeEach(() => {
    mockFetch.mockReset();
    mockFetch.mockImplementation(async (input: RequestInfo | URL) => {
      const url = input.toString();
      if (url.includes('/api/v1/public/metadata')) {
        return {
          ok: true,
          json: async () => ({
            productName: 'Purview Workbench',
            docsUrl: '/docs',
            supportEmail: 'support@example.com'
          })
        };
      }
      if (url.includes('/api/v1/public/library/sit')) {
        return {
          ok: true,
          json: async () => [{ id: 'sit-1', title: 'PAN detector', summary: 'Detect payment cards', category: 'SIT' }]
        };
      }
      if (url.includes('/api/v1/public/library/dlp')) {
        return {
          ok: true,
          json: async () => [{ id: 'dlp-1', title: 'PII baseline', summary: 'Baseline PII policy', category: 'DLP' }]
        };
      }
      if (url.includes('/api/v1/tenants/me/consent-status')) {
        return {
          ok: true,
          json: async () => ({
            tenant_id: 'tenant-1',
            consent_completed: false,
            consent_completed_at: null
          })
        };
      }
      if (url.includes('/api/v1/jobs/test-text-extraction') || url.includes('/api/v1/jobs/test-data-classification')) {
        return {
          ok: true,
          json: async () => ({ jobId: 'job-1', status: 'QUEUED', jobType: 'TEST_TEXT_EXTRACTION' })
        };
      }
      if (url.includes('/api/v1/jobs/job-1')) {
        return {
          ok: true,
          json: async () => ({
            jobId: 'job-1',
            tenantId: 'demo-tenant-id',
            jobType: 'TEST_TEXT_EXTRACTION',
            status: 'QUEUED',
            result: null
          })
        };
      }

      return { ok: false, json: async () => ({}) };
    });
  });

  it('renders public shell for anonymous users', async () => {
    render(<App />);

    expect(screen.getByText('Not signed in.')).toBeDefined();
    expect(screen.getByText('Phase 2 public-first shell with protected action gating.')).toBeDefined();

    await waitFor(() => {
      expect(screen.getByText('Purview Workbench · support: support@example.com')).toBeDefined();
    });
  });

  it('allows anonymous users to browse public pages', async () => {
    render(<App />);

    fireEvent.click(screen.getByRole('button', { name: 'sit-library' }));

    await waitFor(() => {
      expect(screen.getByText('Public SIT templates')).toBeDefined();
      expect(screen.getByText('PAN detector')).toBeDefined();
    });
  });

  it('gates protected test actions behind sign in', async () => {
    render(<App />);

    fireEvent.click(screen.getByRole('button', { name: 'test-console' }));
    fireEvent.click(screen.getByRole('button', { name: 'Run Test-TextExtraction' }));

    expect(screen.getByText('Sign in required for protected action: RUN_TEST_TEXT_EXTRACTION')).toBeDefined();

    fireEvent.click(screen.getByRole('button', { name: 'Continue with sign in' }));

    await waitFor(() => {
      expect(screen.getByText('Signed in as Demo Admin')).toBeDefined();
      expect(screen.getByText('Tenant admin consent is required before running protected tenant operations.')).toBeDefined();
    });
  });
});
