import type {
  PatternDetail,
  PatternListResponse,
  PatternQuery,
  PublicAppMetadata,
  PublicLibraryItem
} from '@purview/contracts';

const API_BASE = import.meta.env.VITE_API_BASE_URL ?? '';

export async function fetchPublicSitLibrary(): Promise<PublicLibraryItem[]> {
  const response = await fetch(`${API_BASE}/api/v1/public/library/sit`);
  if (!response.ok) {
    throw new Error('Unable to fetch SIT library');
  }

  return (await response.json()) as PublicLibraryItem[];
}

export async function fetchPublicDlpLibrary(): Promise<PublicLibraryItem[]> {
  const response = await fetch(`${API_BASE}/api/v1/public/library/dlp`);
  if (!response.ok) {
    throw new Error('Unable to fetch DLP library');
  }

  return (await response.json()) as PublicLibraryItem[];
}

export async function fetchPublicMetadata(): Promise<PublicAppMetadata> {
  const response = await fetch(`${API_BASE}/api/v1/public/metadata`);
  if (!response.ok) {
    throw new Error('Unable to fetch public metadata');
  }

  return (await response.json()) as PublicAppMetadata;
}

function buildQuery(params: PatternQuery): string {
  const qs = new URLSearchParams();
  Object.entries(params).forEach(([key, value]) => {
    if (value === undefined || value === null || value === '') {
      return;
    }
    qs.set(key, String(value));
  });
  const encoded = qs.toString();
  return encoded ? `?${encoded}` : '';
}

export async function fetchPublicPatterns(params: PatternQuery = {}): Promise<PatternListResponse> {
  const response = await fetch(`${API_BASE}/api/v1/public/patterns${buildQuery(params)}`);
  if (!response.ok) {
    throw new Error('Unable to fetch public patterns');
  }
  return (await response.json()) as PatternListResponse;
}

export async function fetchPublicPatternDetail(slug: string): Promise<PatternDetail> {
  const response = await fetch(`${API_BASE}/api/v1/public/patterns/${encodeURIComponent(slug)}`);
  if (!response.ok) {
    throw new Error('Unable to fetch pattern detail');
  }
  return (await response.json()) as PatternDetail;
}
