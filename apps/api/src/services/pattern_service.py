import json
from pathlib import Path

from sqlalchemy import Select, func, or_, select
from sqlalchemy.orm import Session

from models.pattern_template import (
    PatternCollection,
    PatternExport,
    PatternFalsePositive,
    PatternFilter,
    PatternKeywordCollection,
    PatternKeywordGroup,
    PatternRegex,
    PatternTemplate,
    PatternTestCase,
    PatternTier,
    PatternValidator,
)


class PatternValidationError(ValueError):
    pass


def _normalize_string_list(value: object) -> list[str]:
    if not isinstance(value, list):
        return []
    normalized = []
    for item in value:
        if not isinstance(item, str):
            continue
        cleaned = item.strip()
        if cleaned:
            normalized.append(cleaned)
    return sorted(set(normalized), key=lambda v: v.lower())


def _normalize_dict(value: object) -> dict:
    return value if isinstance(value, dict) else {}


def _normalize_list_of_dicts(value: object) -> list[dict]:
    if not isinstance(value, list):
        return []
    return [item for item in value if isinstance(item, dict)]


def _safe_int(value: object) -> int | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value
    if isinstance(value, str) and value.strip().isdigit():
        return int(value.strip())
    return None


def load_import_payload(payload: dict | None, file_path: str | None) -> dict:
    if payload is not None:
        return payload
    if not file_path:
        raise PatternValidationError("provide payload or file_path")
    content = Path(file_path).read_text(encoding="utf-8")
    loaded = json.loads(content)
    if not isinstance(loaded, dict):
        raise PatternValidationError("import payload must be a JSON object")
    return loaded


def validate_import_payload(payload: dict) -> list[str]:
    warnings: list[str] = []

    patterns = payload.get("patterns")
    if not isinstance(patterns, list):
        raise PatternValidationError("patterns must be an array")
    collections = payload.get("collections", [])
    if not isinstance(collections, list):
        raise PatternValidationError("collections must be an array")
    keywords = payload.get("keywords", [])
    if not isinstance(keywords, list):
        raise PatternValidationError("keywords must be an array")

    if not patterns:
        warnings.append("patterns array is empty")

    seen_slugs: set[str] = set()
    for idx, item in enumerate(patterns):
        if not isinstance(item, dict):
            raise PatternValidationError(f"patterns[{idx}] must be an object")
        slug = str(item.get("slug", "")).strip()
        name = str(item.get("name", "")).strip()
        pattern_type = str(item.get("type", "")).strip()
        if not slug:
            raise PatternValidationError(f"patterns[{idx}] missing slug")
        if slug in seen_slugs:
            raise PatternValidationError(f"duplicate pattern slug: {slug}")
        seen_slugs.add(slug)
        if not name:
            warnings.append(f"pattern {slug} has empty name")
        if not pattern_type:
            warnings.append(f"pattern {slug} has empty type")

    return warnings


def _extract_regex_rows(item: dict) -> list[PatternRegex]:
    rows: list[PatternRegex] = []

    pattern_text = item.get("pattern")
    if isinstance(pattern_text, str) and pattern_text.strip():
        rows.append(PatternRegex(name="primary", regex_pattern=pattern_text.strip(), metadata_json={"source": "top_level"}))

    purview = _normalize_dict(item.get("purview"))
    for index, regex in enumerate(_normalize_list_of_dicts(purview.get("regexes"))):
        regex_text = regex.get("pattern")
        if not isinstance(regex_text, str) or not regex_text.strip():
            continue
        regex_name = str(regex.get("name") or regex.get("id") or f"regex_{index + 1}")
        rows.append(
            PatternRegex(
                name=regex_name,
                regex_pattern=regex_text.strip(),
                metadata_json={k: v for k, v in regex.items() if k != "pattern"},
            )
        )
    return rows


def _extract_keyword_group_rows(item: dict) -> list[PatternKeywordGroup]:
    rows: list[PatternKeywordGroup] = []

    keywords = _normalize_string_list(item.get("keywords"))
    if keywords:
        rows.append(
            PatternKeywordGroup(
                group_type="top_level",
                name="top_level_keywords",
                words=keywords,
                metadata_json={"source": "top_level"},
            )
        )

    purview = _normalize_dict(item.get("purview"))
    for index, keyword in enumerate(_normalize_list_of_dicts(purview.get("keywords"))):
        group_name = str(keyword.get("name") or keyword.get("id") or keyword.get("group") or f"group_{index + 1}")

        if isinstance(keyword.get("words"), list):
            rows.append(
                PatternKeywordGroup(
                    group_type="words",
                    name=group_name,
                    words=_normalize_string_list(keyword.get("words")),
                    metadata_json={k: v for k, v in keyword.items() if k != "words"},
                )
            )
            continue

        if isinstance(keyword.get("values"), list):
            rows.append(
                PatternKeywordGroup(
                    group_type="values",
                    name=group_name,
                    words=_normalize_string_list(keyword.get("values")),
                    metadata_json={k: v for k, v in keyword.items() if k != "values"},
                )
            )
            continue

        groups = _normalize_list_of_dicts(keyword.get("groups"))
        for group_index, group in enumerate(groups):
            terms = _normalize_string_list(group.get("terms"))
            if not terms:
                continue
            rows.append(
                PatternKeywordGroup(
                    group_type="group_terms",
                    name=f"{group_name}_{group_index + 1}",
                    words=terms,
                    metadata_json={"group": group, "parent": {k: v for k, v in keyword.items() if k != "groups"}},
                )
            )

    return rows


def _extract_validator_rows(item: dict) -> list[PatternValidator]:
    rows: list[PatternValidator] = []

    purview = _normalize_dict(item.get("purview"))
    for validator in _normalize_list_of_dicts(purview.get("validators")):
        rows.append(
            PatternValidator(
                validator_type=str(validator.get("type", "")),
                config_json=validator,
            )
        )

    for regex in _normalize_list_of_dicts(purview.get("regexes")):
        for validator in _normalize_list_of_dicts(regex.get("validators")):
            rows.append(
                PatternValidator(
                    validator_type=str(validator.get("type", "nested_regex_validator")),
                    config_json={"regex_id": regex.get("id") or regex.get("name"), "validator": validator},
                )
            )

    return rows


def _extract_filter_rows(item: dict) -> list[PatternFilter]:
    rows: list[PatternFilter] = []

    purview = _normalize_dict(item.get("purview"))
    for index, flt in enumerate(_normalize_list_of_dicts(purview.get("filters"))):
        if "keywords" in flt:
            keywords = _normalize_string_list(flt.get("keywords"))
        elif "values" in flt:
            keywords = _normalize_string_list(flt.get("values"))
        elif "terms" in flt:
            keywords = _normalize_string_list(flt.get("terms"))
        elif "exclude" in flt and isinstance(flt.get("exclude"), list):
            keywords = _normalize_string_list(flt.get("exclude"))
        else:
            keywords = []

        rows.append(
            PatternFilter(
                filter_type=str(flt.get("type", f"filter_{index + 1}")),
                description=str(flt.get("description", "")),
                keywords=keywords,
                config_json=flt,
            )
        )

    return rows


def _extract_tier_rows(item: dict) -> list[PatternTier]:
    rows: list[PatternTier] = []

    purview = _normalize_dict(item.get("purview"))
    for index, tier in enumerate(_normalize_list_of_dicts(purview.get("pattern_tiers"))):
        rows.append(
            PatternTier(
                tier_name=str(tier.get("tier") or tier.get("id_match") or f"tier_{index + 1}"),
                confidence_level=_safe_int(tier.get("confidence_level") or tier.get("confidence")),
                config_json=tier,
            )
        )

    return rows


def _extract_test_case_rows(item: dict) -> list[PatternTestCase]:
    rows: list[PatternTestCase] = []
    test_cases = _normalize_dict(item.get("test_cases"))

    for case_type in ("should_match", "should_not_match"):
        for test_case in _normalize_list_of_dicts(test_cases.get(case_type)):
            rows.append(
                PatternTestCase(
                    case_type=case_type,
                    value=str(test_case.get("value", "")),
                    description=str(test_case.get("description", "")),
                )
            )

    return rows


def _extract_false_positive_rows(item: dict) -> list[PatternFalsePositive]:
    rows: list[PatternFalsePositive] = []
    for false_positive in _normalize_list_of_dicts(item.get("false_positives")):
        rows.append(
            PatternFalsePositive(
                description=str(false_positive.get("description", "")),
                mitigation=str(false_positive.get("mitigation", "")),
            )
        )
    return rows


def _extract_export_rows(item: dict) -> list[PatternExport]:
    return [PatternExport(export_format=fmt) for fmt in _normalize_string_list(item.get("exports"))]


def import_pattern_payload(db: Session, payload: dict) -> tuple[int, int, int, list[str]]:
    warnings = validate_import_payload(payload)

    imported_patterns = 0
    for item in payload.get("patterns", []):
        slug = str(item.get("slug", "")).strip()
        if not slug:
            continue

        row = db.scalar(select(PatternTemplate).where(PatternTemplate.slug == slug))
        if row is None:
            row = PatternTemplate(slug=slug, name=str(item.get("name", slug)), pattern_type=str(item.get("type", "unknown")))
            db.add(row)

        row.schema_name = str(item.get("schema", "testpattern/v1"))
        row.name = str(item.get("name", slug))
        row.version = str(item.get("version", "1.0.0"))
        row.pattern_type = str(item.get("type", "unknown"))
        row.engine = str(item.get("engine", "universal"))
        row.description = str(item.get("description", ""))
        row.operation = str(item.get("operation", ""))
        row.pattern = str(item.get("pattern")) if isinstance(item.get("pattern"), str) else None
        row.confidence = str(item.get("confidence", "medium"))
        row.confidence_justification = str(item.get("confidence_justification", ""))
        row.scope = str(item.get("scope", "wide"))
        row.risk_rating = _safe_int(item.get("risk_rating"))
        row.risk_description = str(item.get("risk_description")) if isinstance(item.get("risk_description"), str) else None
        row.jurisdictions = _normalize_string_list(item.get("jurisdictions"))
        row.regulations = _normalize_string_list(item.get("regulations"))
        row.data_categories = _normalize_string_list(item.get("data_categories"))
        row.exports = _normalize_string_list(item.get("exports"))
        row.sensitivity_labels = _normalize_dict(item.get("sensitivity_labels"))
        row.corroborative_evidence = _normalize_dict(item.get("corroborative_evidence"))
        row.purview = _normalize_dict(item.get("purview"))
        row.references = _normalize_list_of_dicts(item.get("references"))
        row.source = str(item.get("source")) if isinstance(item.get("source"), str) else None
        row.author = str(item.get("author", ""))
        row.license = str(item.get("license", "MIT"))
        row.created = str(item.get("created")) if isinstance(item.get("created"), str) else None
        row.updated = str(item.get("updated")) if isinstance(item.get("updated"), str) else None
        row.raw_payload = item

        row.regexes.clear()
        row.keyword_groups.clear()
        row.validators.clear()
        row.filters.clear()
        row.tiers.clear()
        row.test_cases.clear()
        row.false_positives.clear()
        row.export_formats.clear()

        row.regexes.extend(_extract_regex_rows(item))
        row.keyword_groups.extend(_extract_keyword_group_rows(item))
        row.validators.extend(_extract_validator_rows(item))
        row.filters.extend(_extract_filter_rows(item))
        row.tiers.extend(_extract_tier_rows(item))
        row.test_cases.extend(_extract_test_case_rows(item))
        row.false_positives.extend(_extract_false_positive_rows(item))
        row.export_formats.extend(_extract_export_rows(item))

        imported_patterns += 1

    imported_collections = 0
    for item in payload.get("collections", []):
        if not isinstance(item, dict):
            continue
        slug = str(item.get("slug", "")).strip()
        if not slug:
            continue

        row = db.scalar(select(PatternCollection).where(PatternCollection.slug == slug))
        if row is None:
            row = PatternCollection(slug=slug, name=str(item.get("name", slug)))
            db.add(row)

        row.schema_name = str(item.get("schema", "testpattern/v1"))
        row.name = str(item.get("name", slug))
        row.description = str(item.get("description", ""))
        row.jurisdictions = _normalize_string_list(item.get("jurisdictions"))
        row.regulations = _normalize_string_list(item.get("regulations"))
        row.pattern_slugs = _normalize_string_list(item.get("patterns"))
        row.author = str(item.get("author", ""))
        row.license = str(item.get("license", "MIT"))
        row.created = str(item.get("created")) if isinstance(item.get("created"), str) else None
        row.updated = str(item.get("updated")) if isinstance(item.get("updated"), str) else None
        row.raw_payload = item

        imported_collections += 1

    imported_keyword_collections = 0
    for item in payload.get("keywords", []):
        if not isinstance(item, dict):
            continue
        slug = str(item.get("slug", "")).strip()
        if not slug:
            continue

        row = db.scalar(select(PatternKeywordCollection).where(PatternKeywordCollection.slug == slug))
        if row is None:
            row = PatternKeywordCollection(slug=slug, name=str(item.get("name", slug)))
            db.add(row)

        row.schema_name = str(item.get("schema", "testpattern/v1"))
        row.name = str(item.get("name", slug))
        row.keyword_type = str(item.get("type", "keyword_list"))
        row.description = str(item.get("description", ""))
        row.jurisdictions = _normalize_string_list(item.get("jurisdictions"))
        row.data_categories = _normalize_string_list(item.get("data_categories"))
        row.keywords = _normalize_string_list(item.get("keywords"))
        row.author = str(item.get("author", ""))
        row.license = str(item.get("license", "MIT"))
        row.created = str(item.get("created")) if isinstance(item.get("created"), str) else None
        row.updated = str(item.get("updated")) if isinstance(item.get("updated"), str) else None
        row.metadata_json = {
            "jurisdictions": row.jurisdictions,
            "data_categories": row.data_categories,
        }
        row.raw_payload = item

        imported_keyword_collections += 1

    db.commit()
    return imported_patterns, imported_collections, imported_keyword_collections, warnings


def _apply_pattern_filters(
    stmt: Select[tuple[PatternTemplate]],
    *,
    query: str | None,
    pattern_type: str | None,
    jurisdiction: str | None,
    regulation: str | None,
    category: str | None,
    risk_min: int | None,
    risk_max: int | None,
    engine: str | None,
    scope: str | None,
    export_format: str | None,
) -> Select[tuple[PatternTemplate]]:
    if query:
        like = f"%{query.strip()}%"
        stmt = stmt.where(or_(PatternTemplate.name.ilike(like), PatternTemplate.slug.ilike(like), PatternTemplate.description.ilike(like)))
    if pattern_type:
        stmt = stmt.where(PatternTemplate.pattern_type == pattern_type)
    if jurisdiction:
        stmt = stmt.where(PatternTemplate.jurisdictions.contains([jurisdiction]))
    if regulation:
        stmt = stmt.where(PatternTemplate.regulations.contains([regulation]))
    if category:
        stmt = stmt.where(PatternTemplate.data_categories.contains([category]))
    if risk_min is not None:
        stmt = stmt.where(PatternTemplate.risk_rating.is_not(None), PatternTemplate.risk_rating >= risk_min)
    if risk_max is not None:
        stmt = stmt.where(PatternTemplate.risk_rating.is_not(None), PatternTemplate.risk_rating <= risk_max)
    if engine:
        stmt = stmt.where(PatternTemplate.engine == engine)
    if scope:
        stmt = stmt.where(PatternTemplate.scope == scope)
    if export_format:
        stmt = stmt.where(PatternTemplate.exports.contains([export_format]))

    return stmt


def list_patterns(
    db: Session,
    *,
    query: str | None,
    pattern_type: str | None,
    jurisdiction: str | None,
    regulation: str | None,
    category: str | None,
    risk_min: int | None,
    risk_max: int | None,
    engine: str | None,
    scope: str | None,
    export_format: str | None,
    limit: int,
    offset: int,
) -> tuple[int, list[PatternTemplate]]:
    base_stmt = select(PatternTemplate)
    filtered_stmt = _apply_pattern_filters(
        base_stmt,
        query=query,
        pattern_type=pattern_type,
        jurisdiction=jurisdiction,
        regulation=regulation,
        category=category,
        risk_min=risk_min,
        risk_max=risk_max,
        engine=engine,
        scope=scope,
        export_format=export_format,
    )

    count_stmt = select(func.count()).select_from(filtered_stmt.subquery())
    total = db.scalar(count_stmt) or 0

    items = db.scalars(
        filtered_stmt.order_by(PatternTemplate.name.asc(), PatternTemplate.slug.asc()).offset(offset).limit(limit)
    ).all()
    return total, items


def get_pattern_by_slug(db: Session, slug: str) -> PatternTemplate | None:
    return db.scalar(select(PatternTemplate).where(PatternTemplate.slug == slug))


def serialize_pattern_summary(item: PatternTemplate) -> dict:
    return {
        "id": item.id,
        "slug": item.slug,
        "name": item.name,
        "pattern_type": item.pattern_type,
        "confidence": item.confidence,
        "engine": item.engine,
        "scope": item.scope,
        "risk_rating": item.risk_rating,
        "jurisdictions": item.jurisdictions,
        "regulations": item.regulations,
        "data_categories": item.data_categories,
        "exports": item.exports,
    }


def serialize_pattern_detail(item: PatternTemplate) -> dict:
    return {
        "id": item.id,
        "slug": item.slug,
        "name": item.name,
        "version": item.version,
        "schema_name": item.schema_name,
        "pattern_type": item.pattern_type,
        "engine": item.engine,
        "description": item.description,
        "operation": item.operation,
        "pattern": item.pattern,
        "confidence": item.confidence,
        "confidence_justification": item.confidence_justification,
        "scope": item.scope,
        "risk_rating": item.risk_rating,
        "risk_description": item.risk_description,
        "jurisdictions": item.jurisdictions,
        "regulations": item.regulations,
        "data_categories": item.data_categories,
        "exports": item.exports,
        "source": item.source,
        "author": item.author,
        "license": item.license,
        "created": item.created,
        "updated": item.updated,
        "references": item.references,
        "corroborative_evidence": item.corroborative_evidence,
        "purview": item.purview,
        "sensitivity_labels": item.sensitivity_labels,
        "regexes": [
            {
                "id": regex.id,
                "payload": {
                    "name": regex.name,
                    "pattern": regex.regex_pattern,
                    **regex.metadata_json,
                },
            }
            for regex in sorted(item.regexes, key=lambda row: (row.name, row.id))
        ],
        "keyword_groups": [
            {
                "id": group.id,
                "payload": {
                    "name": group.name,
                    "group_type": group.group_type,
                    "words": group.words,
                    **group.metadata_json,
                },
            }
            for group in sorted(item.keyword_groups, key=lambda row: (row.name, row.id))
        ],
        "validators": [
            {"id": validator.id, "payload": {"type": validator.validator_type, **validator.config_json}}
            for validator in sorted(item.validators, key=lambda row: (row.validator_type, row.id))
        ],
        "filters": [
            {
                "id": flt.id,
                "payload": {
                    "type": flt.filter_type,
                    "description": flt.description,
                    "keywords": flt.keywords,
                    **flt.config_json,
                },
            }
            for flt in sorted(item.filters, key=lambda row: (row.filter_type, row.id))
        ],
        "pattern_tiers": [
            {
                "id": tier.id,
                "payload": {
                    "name": tier.tier_name,
                    "confidence_level": tier.confidence_level,
                    **tier.config_json,
                },
            }
            for tier in sorted(item.tiers, key=lambda row: (row.tier_name, row.id))
        ],
        "test_cases": [
            {
                "id": case.id,
                "payload": {
                    "type": case.case_type,
                    "description": case.description,
                    "value": case.value,
                },
            }
            for case in sorted(item.test_cases, key=lambda row: (row.case_type, row.id))
        ],
        "false_positives": [
            {
                "id": fp.id,
                "payload": {
                    "description": fp.description,
                    "mitigation": fp.mitigation,
                },
            }
            for fp in sorted(item.false_positives, key=lambda row: row.id)
        ],
    }
