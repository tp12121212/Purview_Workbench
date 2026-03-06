/** @vitest-environment jsdom */

import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { App } from './App';

const mockFetch = vi.fn();

vi.stubGlobal('fetch', mockFetch);

describe('Phase 1 onboarding shell', () => {
  afterEach(() => {
    cleanup();
  });

  beforeEach(() => {
    window.localStorage.clear();
    mockFetch.mockReset();
  });

  it('renders sign in state by default', () => {
    render(<App />);

    expect(screen.getByText('Not signed in.')).toBeDefined();
    expect(screen.queryByText('Tenant onboarding')).toBeNull();
  });

  it('renders onboarding status after sign in', async () => {
    mockFetch.mockResolvedValue({
      ok: true,
      json: async () => ({
        tenant_id: 'tenant-1',
        consent_completed: false,
        consent_completed_at: null
      })
    });

    render(<App />);

    fireEvent.click(screen.getByRole('button', { name: 'Sign in' }));

    await waitFor(() => {
      expect(screen.getByText('Tenant onboarding')).toBeDefined();
      expect(screen.getByText('Admin consent is required before using Purview worker features.')).toBeDefined();
    });
  });
});
