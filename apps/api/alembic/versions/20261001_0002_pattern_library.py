"""pattern library domain tables

Revision ID: 20261001_0002
Revises: 20261001_0001
Create Date: 2026-10-01 00:30:00.000000
"""

from collections.abc import Sequence

from alembic import op
import sqlalchemy as sa


revision: str = "20261001_0002"
down_revision: str | None = "20261001_0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "pattern_templates",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("schema_name", sa.String(length=64), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("slug", sa.String(length=255), nullable=False),
        sa.Column("version", sa.String(length=32), nullable=False),
        sa.Column("pattern_type", sa.String(length=64), nullable=False),
        sa.Column("engine", sa.String(length=64), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("operation", sa.Text(), nullable=False),
        sa.Column("pattern", sa.Text(), nullable=True),
        sa.Column("confidence", sa.String(length=32), nullable=False),
        sa.Column("confidence_justification", sa.Text(), nullable=False),
        sa.Column("scope", sa.String(length=32), nullable=False),
        sa.Column("risk_rating", sa.Integer(), nullable=True),
        sa.Column("risk_description", sa.Text(), nullable=True),
        sa.Column("jurisdictions", sa.JSON(), nullable=False),
        sa.Column("regulations", sa.JSON(), nullable=False),
        sa.Column("data_categories", sa.JSON(), nullable=False),
        sa.Column("exports", sa.JSON(), nullable=False),
        sa.Column("sensitivity_labels", sa.JSON(), nullable=False),
        sa.Column("corroborative_evidence", sa.JSON(), nullable=False),
        sa.Column("purview", sa.JSON(), nullable=False),
        sa.Column("references", sa.JSON(), nullable=False),
        sa.Column("source", sa.String(length=128), nullable=True),
        sa.Column("author", sa.String(length=128), nullable=False),
        sa.Column("license", sa.String(length=64), nullable=False),
        sa.Column("created", sa.String(length=32), nullable=True),
        sa.Column("updated", sa.String(length=32), nullable=True),
        sa.Column("raw_payload", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_pattern_templates_slug"), "pattern_templates", ["slug"], unique=True)
    op.create_index(op.f("ix_pattern_templates_pattern_type"), "pattern_templates", ["pattern_type"], unique=False)
    op.create_index(op.f("ix_pattern_templates_engine"), "pattern_templates", ["engine"], unique=False)
    op.create_index(op.f("ix_pattern_templates_scope"), "pattern_templates", ["scope"], unique=False)
    op.create_index(op.f("ix_pattern_templates_risk_rating"), "pattern_templates", ["risk_rating"], unique=False)

    op.create_table(
        "pattern_regexes",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("pattern_id", sa.String(length=36), nullable=False),
        sa.Column("name", sa.String(length=128), nullable=False),
        sa.Column("regex_pattern", sa.Text(), nullable=False),
        sa.Column("metadata_json", sa.JSON(), nullable=False),
        sa.ForeignKeyConstraint(["pattern_id"], ["pattern_templates.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_pattern_regexes_pattern_id"), "pattern_regexes", ["pattern_id"], unique=False)

    op.create_table(
        "pattern_keyword_groups",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("pattern_id", sa.String(length=36), nullable=False),
        sa.Column("group_type", sa.String(length=64), nullable=False),
        sa.Column("name", sa.String(length=128), nullable=False),
        sa.Column("words", sa.JSON(), nullable=False),
        sa.Column("metadata_json", sa.JSON(), nullable=False),
        sa.ForeignKeyConstraint(["pattern_id"], ["pattern_templates.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_pattern_keyword_groups_pattern_id"), "pattern_keyword_groups", ["pattern_id"], unique=False)

    op.create_table(
        "pattern_validators",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("pattern_id", sa.String(length=36), nullable=False),
        sa.Column("validator_type", sa.String(length=64), nullable=False),
        sa.Column("config_json", sa.JSON(), nullable=False),
        sa.ForeignKeyConstraint(["pattern_id"], ["pattern_templates.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_pattern_validators_pattern_id"), "pattern_validators", ["pattern_id"], unique=False)

    op.create_table(
        "pattern_filters",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("pattern_id", sa.String(length=36), nullable=False),
        sa.Column("filter_type", sa.String(length=64), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("keywords", sa.JSON(), nullable=False),
        sa.Column("config_json", sa.JSON(), nullable=False),
        sa.ForeignKeyConstraint(["pattern_id"], ["pattern_templates.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_pattern_filters_pattern_id"), "pattern_filters", ["pattern_id"], unique=False)

    op.create_table(
        "pattern_tiers",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("pattern_id", sa.String(length=36), nullable=False),
        sa.Column("tier_name", sa.String(length=64), nullable=False),
        sa.Column("confidence_level", sa.Integer(), nullable=True),
        sa.Column("config_json", sa.JSON(), nullable=False),
        sa.ForeignKeyConstraint(["pattern_id"], ["pattern_templates.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_pattern_tiers_pattern_id"), "pattern_tiers", ["pattern_id"], unique=False)

    op.create_table(
        "pattern_test_cases",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("pattern_id", sa.String(length=36), nullable=False),
        sa.Column("case_type", sa.String(length=32), nullable=False),
        sa.Column("value", sa.Text(), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.ForeignKeyConstraint(["pattern_id"], ["pattern_templates.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_pattern_test_cases_pattern_id"), "pattern_test_cases", ["pattern_id"], unique=False)
    op.create_index(op.f("ix_pattern_test_cases_case_type"), "pattern_test_cases", ["case_type"], unique=False)

    op.create_table(
        "pattern_false_positives",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("pattern_id", sa.String(length=36), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("mitigation", sa.Text(), nullable=False),
        sa.ForeignKeyConstraint(["pattern_id"], ["pattern_templates.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_pattern_false_positives_pattern_id"), "pattern_false_positives", ["pattern_id"], unique=False)

    op.create_table(
        "pattern_exports",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("pattern_id", sa.String(length=36), nullable=False),
        sa.Column("export_format", sa.String(length=64), nullable=False),
        sa.ForeignKeyConstraint(["pattern_id"], ["pattern_templates.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("pattern_id", "export_format", name="uq_pattern_export_format"),
    )
    op.create_index(op.f("ix_pattern_exports_pattern_id"), "pattern_exports", ["pattern_id"], unique=False)
    op.create_index(op.f("ix_pattern_exports_export_format"), "pattern_exports", ["export_format"], unique=False)

    op.create_table(
        "pattern_collections",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("schema_name", sa.String(length=64), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("slug", sa.String(length=255), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("jurisdictions", sa.JSON(), nullable=False),
        sa.Column("regulations", sa.JSON(), nullable=False),
        sa.Column("pattern_slugs", sa.JSON(), nullable=False),
        sa.Column("author", sa.String(length=128), nullable=False),
        sa.Column("license", sa.String(length=64), nullable=False),
        sa.Column("created", sa.String(length=32), nullable=True),
        sa.Column("updated", sa.String(length=32), nullable=True),
        sa.Column("raw_payload", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_pattern_collections_slug"), "pattern_collections", ["slug"], unique=True)

    op.create_table(
        "pattern_keyword_collections",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("schema_name", sa.String(length=64), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("slug", sa.String(length=255), nullable=False),
        sa.Column("keyword_type", sa.String(length=64), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("jurisdictions", sa.JSON(), nullable=False),
        sa.Column("data_categories", sa.JSON(), nullable=False),
        sa.Column("keywords", sa.JSON(), nullable=False),
        sa.Column("author", sa.String(length=128), nullable=False),
        sa.Column("license", sa.String(length=64), nullable=False),
        sa.Column("created", sa.String(length=32), nullable=True),
        sa.Column("updated", sa.String(length=32), nullable=True),
        sa.Column("metadata_json", sa.JSON(), nullable=False),
        sa.Column("raw_payload", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_pattern_keyword_collections_slug"), "pattern_keyword_collections", ["slug"], unique=True)
    op.create_index(
        op.f("ix_pattern_keyword_collections_keyword_type"),
        "pattern_keyword_collections",
        ["keyword_type"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_pattern_keyword_collections_keyword_type"), table_name="pattern_keyword_collections")
    op.drop_index(op.f("ix_pattern_keyword_collections_slug"), table_name="pattern_keyword_collections")
    op.drop_table("pattern_keyword_collections")

    op.drop_index(op.f("ix_pattern_collections_slug"), table_name="pattern_collections")
    op.drop_table("pattern_collections")

    op.drop_index(op.f("ix_pattern_exports_export_format"), table_name="pattern_exports")
    op.drop_index(op.f("ix_pattern_exports_pattern_id"), table_name="pattern_exports")
    op.drop_table("pattern_exports")

    op.drop_index(op.f("ix_pattern_false_positives_pattern_id"), table_name="pattern_false_positives")
    op.drop_table("pattern_false_positives")

    op.drop_index(op.f("ix_pattern_test_cases_case_type"), table_name="pattern_test_cases")
    op.drop_index(op.f("ix_pattern_test_cases_pattern_id"), table_name="pattern_test_cases")
    op.drop_table("pattern_test_cases")

    op.drop_index(op.f("ix_pattern_tiers_pattern_id"), table_name="pattern_tiers")
    op.drop_table("pattern_tiers")

    op.drop_index(op.f("ix_pattern_filters_pattern_id"), table_name="pattern_filters")
    op.drop_table("pattern_filters")

    op.drop_index(op.f("ix_pattern_validators_pattern_id"), table_name="pattern_validators")
    op.drop_table("pattern_validators")

    op.drop_index(op.f("ix_pattern_keyword_groups_pattern_id"), table_name="pattern_keyword_groups")
    op.drop_table("pattern_keyword_groups")

    op.drop_index(op.f("ix_pattern_regexes_pattern_id"), table_name="pattern_regexes")
    op.drop_table("pattern_regexes")

    op.drop_index(op.f("ix_pattern_templates_risk_rating"), table_name="pattern_templates")
    op.drop_index(op.f("ix_pattern_templates_scope"), table_name="pattern_templates")
    op.drop_index(op.f("ix_pattern_templates_engine"), table_name="pattern_templates")
    op.drop_index(op.f("ix_pattern_templates_pattern_type"), table_name="pattern_templates")
    op.drop_index(op.f("ix_pattern_templates_slug"), table_name="pattern_templates")
    op.drop_table("pattern_templates")
