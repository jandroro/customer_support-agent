"""Liveness check endpoint."""

from fastapi import APIRouter

router = APIRouter(tags=["Health"])


@router.get("/api/health", summary="Health check")
def health() -> dict:
    """Report service liveness.

    Returns:
        A `{"status": "ok"}` dict if the process is up and able to handle
        requests. Used by Docker/orchestrator health checks.
    """
    return {"status": "ok"}
