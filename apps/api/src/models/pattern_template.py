from datetime import datetime, timezone
import uuid

from sqlalchemy import DateTime, ForeignKey, Integer, JSON, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from db.base import Base


class PatternTemplate(Base):
    __tablename__ = "pattern_templates"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    schema_name: Mapped[str] = mapped_column(String(64), default="testpattern/v1")
    name: Mapped[str] = mapped_column(String(255))
    slug: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    version: Mapped[str] = mapped_column(String(32), default="1.0.0")
    pattern_type: Mapped[str] = mapped_column(String(64), index=True)
    engine: Mapped[str] = mapped_column(String(64), default="universal", index=True)
    description: Mapped[str] = mapped_column(Text, default="")
    operation: Mapped[str] = mapped_column(Text, default="")
    pattern: Mapped[str | None] = mapped_column(Text, nullable=True)
    confidence: Mapped[str] = mapped_column(String(32), default="medium")
    confidence_justification: Mapped[str] = mapped_column(Text, default="")
    scope: Mapped[str] = mapped_column(String(32), default="wide", index=True)
    risk_rating: Mapped[int | None] = mapped_column(Integer, nullable=True, index=True)
    risk_description: Mapped[str | None] = mapped_column(Text, nullable=True)
    jurisdictions: Mapped[list[str]] = mapped_column(JSON, default=list)
    regulations: Mapped[list[str]] = mapped_column(JSON, default=list)
    data_categories: Mapped[list[str]] = mapped_column(JSON, default=list)
    exports: Mapped[list[str]] = mapped_column(JSON, default=list)
    sensitivity_labels: Mapped[dict] = mapped_column(JSON, default=dict)
    corroborative_evidence: Mapped[dict] = mapped_column(JSON, default=dict)
    purview: Mapped[dict] = mapped_column(JSON, default=dict)
    references: Mapped[list[dict]] = mapped_column(JSON, default=list)
    source: Mapped[str | None] = mapped_column(String(128), nullable=True)
    author: Mapped[str] = mapped_column(String(128), default="")
    license: Mapped[str] = mapped_column(String(64), default="MIT")
    created: Mapped[str | None] = mapped_column(String(32), nullable=True)
    updated: Mapped[str | None] = mapped_column(String(32), nullable=True)
    raw_payload: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )

    regexes = relationship("PatternRegex", back_populates="pattern", cascade="all, delete-orphan")
    keyword_groups = relationship("PatternKeywordGroup", back_populates="pattern", cascade="all, delete-orphan")
    validators = relationship("PatternValidator", back_populates="pattern", cascade="all, delete-orphan")
    filters = relationship("PatternFilter", back_populates="pattern", cascade="all, delete-orphan")
    tiers = relationship("PatternTier", back_populates="pattern", cascade="all, delete-orphan")
    test_cases = relationship("PatternTestCase", back_populates="pattern", cascade="all, delete-orphan")
    false_positives = relationship("PatternFalsePositive", back_populates="pattern", cascade="all, delete-orphan")
    export_formats = relationship("PatternExport", back_populates="pattern", cascade="all, delete-orphan")


class PatternRegex(Base):
    __tablename__ = "pattern_regexes"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    pattern_id: Mapped[str] = mapped_column(String(36), ForeignKey("pattern_templates.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(128), default="")
    regex_pattern: Mapped[str] = mapped_column(Text)
    metadata_json: Mapped[dict] = mapped_column(JSON, default=dict)

    pattern = relationship("PatternTemplate", back_populates="regexes")


class PatternKeywordGroup(Base):
    __tablename__ = "pattern_keyword_groups"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    pattern_id: Mapped[str] = mapped_column(String(36), ForeignKey("pattern_templates.id", ondelete="CASCADE"), index=True)
    group_type: Mapped[str] = mapped_column(String(64), default="group")
    name: Mapped[str] = mapped_column(String(128), default="")
    words: Mapped[list[str]] = mapped_column(JSON, default=list)
    metadata_json: Mapped[dict] = mapped_column(JSON, default=dict)

    pattern = relationship("PatternTemplate", back_populates="keyword_groups")


class PatternValidator(Base):
    __tablename__ = "pattern_validators"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    pattern_id: Mapped[str] = mapped_column(String(36), ForeignKey("pattern_templates.id", ondelete="CASCADE"), index=True)
    validator_type: Mapped[str] = mapped_column(String(64), default="")
    config_json: Mapped[dict] = mapped_column(JSON, default=dict)

    pattern = relationship("PatternTemplate", back_populates="validators")


class PatternFilter(Base):
    __tablename__ = "pattern_filters"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    pattern_id: Mapped[str] = mapped_column(String(36), ForeignKey("pattern_templates.id", ondelete="CASCADE"), index=True)
    filter_type: Mapped[str] = mapped_column(String(64), default="")
    description: Mapped[str] = mapped_column(Text, default="")
    keywords: Mapped[list[str]] = mapped_column(JSON, default=list)
    config_json: Mapped[dict] = mapped_column(JSON, default=dict)

    pattern = relationship("PatternTemplate", back_populates="filters")


class PatternTier(Base):
    __tablename__ = "pattern_tiers"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    pattern_id: Mapped[str] = mapped_column(String(36), ForeignKey("pattern_templates.id", ondelete="CASCADE"), index=True)
    tier_name: Mapped[str] = mapped_column(String(64), default="")
    confidence_level: Mapped[int | None] = mapped_column(Integer, nullable=True)
    config_json: Mapped[dict] = mapped_column(JSON, default=dict)

    pattern = relationship("PatternTemplate", back_populates="tiers")


class PatternTestCase(Base):
    __tablename__ = "pattern_test_cases"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    pattern_id: Mapped[str] = mapped_column(String(36), ForeignKey("pattern_templates.id", ondelete="CASCADE"), index=True)
    case_type: Mapped[str] = mapped_column(String(32), index=True)
    value: Mapped[str] = mapped_column(Text, default="")
    description: Mapped[str] = mapped_column(Text, default="")

    pattern = relationship("PatternTemplate", back_populates="test_cases")


class PatternFalsePositive(Base):
    __tablename__ = "pattern_false_positives"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    pattern_id: Mapped[str] = mapped_column(String(36), ForeignKey("pattern_templates.id", ondelete="CASCADE"), index=True)
    description: Mapped[str] = mapped_column(Text, default="")
    mitigation: Mapped[str] = mapped_column(Text, default="")

    pattern = relationship("PatternTemplate", back_populates="false_positives")


class PatternExport(Base):
    __tablename__ = "pattern_exports"
    __table_args__ = (UniqueConstraint("pattern_id", "export_format", name="uq_pattern_export_format"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    pattern_id: Mapped[str] = mapped_column(String(36), ForeignKey("pattern_templates.id", ondelete="CASCADE"), index=True)
    export_format: Mapped[str] = mapped_column(String(64), index=True)

    pattern = relationship("PatternTemplate", back_populates="export_formats")


class PatternCollection(Base):
    __tablename__ = "pattern_collections"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    schema_name: Mapped[str] = mapped_column(String(64), default="testpattern/v1")
    name: Mapped[str] = mapped_column(String(255))
    slug: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    description: Mapped[str] = mapped_column(Text, default="")
    jurisdictions: Mapped[list[str]] = mapped_column(JSON, default=list)
    regulations: Mapped[list[str]] = mapped_column(JSON, default=list)
    pattern_slugs: Mapped[list[str]] = mapped_column(JSON, default=list)
    author: Mapped[str] = mapped_column(String(128), default="")
    license: Mapped[str] = mapped_column(String(64), default="MIT")
    created: Mapped[str | None] = mapped_column(String(32), nullable=True)
    updated: Mapped[str | None] = mapped_column(String(32), nullable=True)
    raw_payload: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))


class PatternKeywordCollection(Base):
    __tablename__ = "pattern_keyword_collections"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    schema_name: Mapped[str] = mapped_column(String(64), default="testpattern/v1")
    name: Mapped[str] = mapped_column(String(255))
    slug: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    keyword_type: Mapped[str] = mapped_column(String(64), default="keyword_list", index=True)
    description: Mapped[str] = mapped_column(Text, default="")
    jurisdictions: Mapped[list[str]] = mapped_column(JSON, default=list)
    data_categories: Mapped[list[str]] = mapped_column(JSON, default=list)
    keywords: Mapped[list[str]] = mapped_column(JSON, default=list)
    author: Mapped[str] = mapped_column(String(128), default="")
    license: Mapped[str] = mapped_column(String(64), default="MIT")
    created: Mapped[str | None] = mapped_column(String(32), nullable=True)
    updated: Mapped[str | None] = mapped_column(String(32), nullable=True)
    metadata_json: Mapped[dict] = mapped_column(JSON, default=dict)
    raw_payload: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
