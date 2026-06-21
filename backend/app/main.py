"""FastAPI application factory.

Instantiates the `FastAPI` app, configures logging and CORS, sets the
OpenAPI/Swagger metadata, and wires up the route modules from
`app.api.routes`. Imported by ASGI servers as `app.main:app`
(see ../Dockerfile).
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .api.routes import auth, chat, health
from .core.config import settings
from .core.logging import configure_logging


configure_logging()

app = FastAPI(
    title="Customer Support Agent API",
    description=(
        "Thin API layer between the Next.js frontend and the Bedrock "
        "AgentCore Runtime. Handles Cognito authentication — both the "
        "shared service identity and per-user register/login/refresh "
        "against MCPServerPool — and proxies chat messages to the "
        "deployed AgentCore Runtime.\n\n"
        "Interactive docs: `/docs` (Swagger UI) and `/redoc` (ReDoc)."
    ),
    version="1.0.0",
    openapi_tags=[
        {"name": "Health", "description": "Service liveness checks."},
        {
            "name": "Auth",
            "description": "User registration, login, and token refresh against the MCPServerPool Cognito user pool.",
        },
        {"name": "Chat", "description": "Proxies chat messages to the Bedrock AgentCore Runtime."},
    ],
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors.allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router)
app.include_router(auth.router)
app.include_router(chat.router)
