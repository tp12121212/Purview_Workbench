import type { PublicAppMetadata, PublicLibraryItem } from '@purview/contracts';

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
