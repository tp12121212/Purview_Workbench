/** @vitest-environment jsdom */

import { cleanup, fireEvent, render, screen } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { MemoryRouter } from 'react-router-dom';

import { App } from './App';
import { signOutSkeleton } from './auth/msalClient';

function renderAt(route = '/') {
  return render(
    <MemoryRouter initialEntries={[route]}>
      <App />
    </MemoryRouter>
  );
}

describe('Phase A routed UI shell', () => {
  beforeEach(() => {
    localStorage.clear();
    signOutSkeleton();
  });

  afterEach(() => {
    cleanup();
  });

  it('renders public routes anonymously', () => {
    renderAt('/sit-library');
    expect(screen.getByText('Public SIT Library')).toBeDefined();
    expect(screen.getByPlaceholderText('Search SIT templates')).toBeDefined();
  });

  it('gates protected action with auth prompt', () => {
    renderAt('/test-console');
    fireEvent.click(screen.getByRole('button', { name: 'Run Test-DataClassification' }));
    expect(screen.getByText('Sign in required for protected action: RUN_TEST_DATA_CLASSIFICATION')).toBeDefined();
  });

  it('routes to consent flow for authenticated users without consent', () => {
    renderAt('/test-console');
    fireEvent.click(screen.getByRole('button', { name: 'Sign in' }));
    fireEvent.click(screen.getByRole('button', { name: 'Run Test-DataClassification' }));
    expect(screen.getByText('Tenant Connection')).toBeDefined();
    expect(screen.getByText('Consent required')).toBeDefined();
  });

  it('persists theme toggle preference', () => {
    renderAt('/');
    fireEvent.click(screen.getByRole('button', { name: 'Theme: light' }));
    expect(localStorage.getItem('purview-theme')).toBe('dark');
  });

  it('shows sign-in requirement for protected settings route', () => {
    renderAt('/settings');
    expect(screen.getByText(/Settings requires sign in/)).toBeDefined();
  });
});
