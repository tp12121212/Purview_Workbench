from fastapi import FastAPI

from routes.auth_tenant import router as auth_tenant_router
from routes.health import router as health_router
from routes.jobs import router as jobs_router
from routes.patterns import router as patterns_router
from routes.public import router as public_router

app = FastAPI(title="Purview Workbench API", version="0.1.0")

app.include_router(health_router, prefix="/api/v1")
app.include_router(public_router, prefix="/api/v1")
app.include_router(auth_tenant_router, prefix="/api/v1")
app.include_router(jobs_router, prefix="/api/v1/jobs")
app.include_router(patterns_router, prefix="/api/v1")
