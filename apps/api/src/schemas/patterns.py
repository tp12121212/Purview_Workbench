from pydantic import BaseModel, Field


class PatternImportRequest(BaseModel):
    payload: dict | None = None
    file_path: str | None = None


class PatternImportResponse(BaseModel):
    imported_patterns: int
    imported_collections: int
    imported_keyword_collections: int
    warnings: list[str] = Field(default_factory=list)


class PatternSummaryResponse(BaseModel):
    id: str
    slug: str
    name: str
    pattern_type: str
    confidence: str
    engine: str
    scope: str
    risk_rating: int | None
    jurisdictions: list[str]
    regulations: list[str]
    data_categories: list[str]
    exports: list[str]


class PatternListResponse(BaseModel):
    total: int
    items: list[PatternSummaryResponse]


class PatternEntityResponse(BaseModel):
    id: str
    payload: dict


class PatternDetailResponse(BaseModel):
    id: str
    slug: str
    name: str
    version: str
    schema_name: str
    pattern_type: str
    engine: str
    description: str
    operation: str
    pattern: str | None
    confidence: str
    confidence_justification: str
    scope: str
    risk_rating: int | None
    risk_description: str | None
    jurisdictions: list[str]
    regulations: list[str]
    data_categories: list[str]
    exports: list[str]
    source: str | None
    author: str
    license: str
    created: str | None
    updated: str | None
    references: list[dict]
    corroborative_evidence: dict
    purview: dict
    sensitivity_labels: dict
    regexes: list[PatternEntityResponse]
    keyword_groups: list[PatternEntityResponse]
    validators: list[PatternEntityResponse]
    filters: list[PatternEntityResponse]
    pattern_tiers: list[PatternEntityResponse]
    test_cases: list[PatternEntityResponse]
    false_positives: list[PatternEntityResponse]
