export type DashboardData = {
  schemaVersion: string;
  kpis: Array<{ id: string; label: string; value: number }>;
  recentTemplates: Array<{ id: string; type: 'SIT' | 'DLP'; name: string; category: string }>;
};

export type SitLibraryData = {
  schemaVersion: string;
  items: Array<{
    id: string;
    name: string;
    category: string;
    region: string;
    confidence: 'high' | 'medium' | 'low';
    patterns: number;
    keywords: string[];
  }>;
};

export type DlpLibraryData = {
  schemaVersion: string;
  items: Array<{ id: string; name: string; workloads: string[]; severity: string; mode: string; rules: number }>;
};

export type RulePacksData = {
  schemaVersion: string;
  items: Array<{ id: string; name: string; version: string; sitCount: number; dlpCount: number; summary: string }>;
};

export type HelpArticlesData = { schemaVersion: string; articles: Array<{ id: string; title: string; summary: string }> };

export type TestConsoleResults = {
  schemaVersion: string;
  job: { id: string; type: string; state: 'queued' | 'running' | 'completed' | 'failed' };
  inputSummary: { source: string; characters: number; lines: number };
  detections: Array<{ id: string; templateId: string; matchText: string; confidence: number; validator: string }>;
};
