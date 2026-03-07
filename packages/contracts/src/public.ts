export type PublicLibraryItem = {
  id: string;
  title: string;
  summary: string;
  category: 'SIT' | 'DLP';
};

export type PublicAppMetadata = {
  productName: string;
  docsUrl: string;
  supportEmail: string;
};

export type PatternSummary = {
  id: string;
  slug: string;
  name: string;
  pattern_type: string;
  confidence: string;
  engine: string;
  scope: string;
  risk_rating: number | null;
  jurisdictions: string[];
  regulations: string[];
  data_categories: string[];
  exports: string[];
};

export type PatternListResponse = {
  total: number;
  items: PatternSummary[];
};

export type PatternEntity = {
  id: string;
  payload: Record<string, unknown>;
};

export type PatternDetail = {
  id: string;
  slug: string;
  name: string;
  version: string;
  schema_name: string;
  pattern_type: string;
  engine: string;
  description: string;
  operation: string;
  pattern: string | null;
  confidence: string;
  confidence_justification: string;
  scope: string;
  risk_rating: number | null;
  risk_description: string | null;
  jurisdictions: string[];
  regulations: string[];
  data_categories: string[];
  exports: string[];
  source: string | null;
  author: string;
  license: string;
  created: string | null;
  updated: string | null;
  references: Array<Record<string, unknown>>;
  corroborative_evidence: Record<string, unknown>;
  purview: Record<string, unknown>;
  sensitivity_labels: Record<string, unknown>;
  regexes: PatternEntity[];
  keyword_groups: PatternEntity[];
  validators: PatternEntity[];
  filters: PatternEntity[];
  pattern_tiers: PatternEntity[];
  test_cases: PatternEntity[];
  false_positives: PatternEntity[];
};

export type PatternQuery = {
  q?: string;
  type?: string;
  jurisdiction?: string;
  regulation?: string;
  category?: string;
  risk_min?: number;
  risk_max?: number;
  engine?: string;
  scope?: string;
  export?: string;
  limit?: number;
  offset?: number;
};
