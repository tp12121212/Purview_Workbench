from fastapi import FastAPI

from routes.health import router as health_router
from routes.jobs import router as jobs_router

app = FastAPI(title="Purview Workbench API", version="0.1.0")

app.include_router(health_router)
app.include_router(jobs_router, prefix="/jobs", tags=["jobs"])
