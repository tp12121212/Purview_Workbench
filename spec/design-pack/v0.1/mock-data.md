# Mock Data Specification v0.1

## Mock data principles
- Deterministic ordering (stable sort by `id` ascending).
- Explicit schema version in each dataset.
- No timestamps or random IDs.
- Safe, synthetic values only.

## 1) Dashboard mock data

```json
{
  "schemaVersion": "design-pack-v0.1",
  "kpis": [
    { "id": "kpi-01", "label": "Public SIT Templates", "value": 48 },
    { "id": "kpi-02", "label": "Public DLP Templates", "value": 26 },
    { "id": "kpi-03", "label": "Rule Pack Examples", "value": 12 },
    { "id": "kpi-04", "label": "Mock Test Runs", "value": 314 }
  ],
  "recentTemplates": [
    { "id": "sit-us-aba", "type": "SIT", "name": "US ABA Routing Number", "category": "Financial" },
    { "id": "sit-us-passport", "type": "SIT", "name": "US Passport Number", "category": "Identity" },
    { "id": "dlp-pci-mail", "type": "DLP", "name": "PCI in Exchange Mail", "category": "Payments" }
  ]
}
```

## 2) Public SIT templates

```json
{
  "schemaVersion": "design-pack-v0.1",
  "items": [
    {
      "id": "sit-eu-iban",
      "name": "EU IBAN",
      "category": "Financial",
      "region": "EU",
      "confidence": "high",
      "patterns": 3,
      "keywords": ["iban", "bank account", "swift"]
    },
    {
      "id": "sit-us-aba",
      "name": "US ABA Routing Number",
      "category": "Financial",
      "region": "US",
      "confidence": "high",
      "patterns": 2,
      "keywords": ["routing", "aba", "bank"]
    },
    {
      "id": "sit-us-ssn",
      "name": "US Social Security Number",
      "category": "Identity",
      "region": "US",
      "confidence": "high",
      "patterns": 3,
      "keywords": ["ssn", "social security", "taxpayer"]
    }
  ]
}
```

## 3) Public DLP templates

```json
{
  "schemaVersion": "design-pack-v0.1",
  "items": [
    {
      "id": "dlp-hr-pii-sharepoint",
      "name": "HR PII in SharePoint",
      "workloads": ["SharePoint", "OneDrive"],
      "severity": "medium",
      "mode": "audit",
      "rules": 4
    },
    {
      "id": "dlp-pci-mail",
      "name": "PCI in Exchange Mail",
      "workloads": ["Exchange"],
      "severity": "high",
      "mode": "enforce",
      "rules": 5
    },
    {
      "id": "dlp-source-code-teams",
      "name": "Source Code in Teams",
      "workloads": ["Teams"],
      "severity": "medium",
      "mode": "audit",
      "rules": 3
    }
  ]
}
```

## 4) Test Console example result

```json
{
  "schemaVersion": "design-pack-v0.1",
  "job": {
    "id": "job-mock-0001",
    "type": "test-data-classification",
    "state": "completed"
  },
  "inputSummary": {
    "source": "inline-text",
    "characters": 482,
    "lines": 9
  },
  "detections": [
    {
      "id": "det-001",
      "templateId": "sit-us-ssn",
      "matchText": "078-05-1120",
      "confidence": 0.99,
      "validator": "checksum-passed"
    },
    {
      "id": "det-002",
      "templateId": "sit-us-aba",
      "matchText": "021000021",
      "confidence": 0.96,
      "validator": "checksum-passed"
    }
  ]
}
```

## 5) Rule pack examples

```json
{
  "schemaVersion": "design-pack-v0.1",
  "items": [
    {
      "id": "rp-finance-core",
      "name": "Finance Core Pack",
      "version": "1.0.0",
      "sitCount": 6,
      "dlpCount": 4,
      "summary": "Core finance sensitive types and baseline policies."
    },
    {
      "id": "rp-hr-global",
      "name": "HR Global Pack",
      "version": "1.0.0",
      "sitCount": 5,
      "dlpCount": 3,
      "summary": "Employee identity and HR document safeguards."
    }
  ]
}
```

## 6) Help/docs teaser content

```json
{
  "schemaVersion": "design-pack-v0.1",
  "articles": [
    {
      "id": "help-auth-consent",
      "title": "Why sign-in is only required for protected actions",
      "summary": "Browse templates publicly, then sign in only when executing tenant-scoped operations."
    },
    {
      "id": "help-test-console",
      "title": "Using the Test Console",
      "summary": "Prepare input anonymously, then authenticate to run extraction/classification jobs."
    },
    {
      "id": "help-rule-packs",
      "title": "Rule pack import/export basics",
      "summary": "Understand structure, compatibility, and safe rollout patterns."
    }
  ]
}
```

## Fixture organization recommendation
- `apps/web/src/mocks/design-pack-v0.1/` for frontend fixture files.
- File names aligned to route domains:
  - `dashboard.json`
  - `sit-library.json`
  - `dlp-library.json`
  - `test-console-results.json`
  - `rule-packs.json`
  - `help-articles.json`
