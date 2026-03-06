from fastapi import APIRouter

router = APIRouter(prefix="/public", tags=["public"])


@router.get("/metadata")
def get_public_metadata() -> dict[str, str]:
    return {
        "productName": "Purview Workbench",
        "docsUrl": "/docs",
        "supportEmail": "support@example.com",
    }


@router.get("/library/sit")
def get_public_sit_library() -> list[dict[str, str]]:
    return [
        {
            "id": "sit-1",
            "title": "Payment Card Number detector",
            "summary": "Starter sensitive info type for payment card numbers.",
            "category": "SIT",
        }
    ]


@router.get("/library/dlp")
def get_public_dlp_library() -> list[dict[str, str]]:
    return [
        {
            "id": "dlp-1",
            "title": "PII baseline policy",
            "summary": "Starter DLP policy template for common PII handling.",
            "category": "DLP",
        }
    ]
