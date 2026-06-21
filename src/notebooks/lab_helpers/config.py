import os
from pathlib import Path
from dotenv import load_dotenv

# Load src/notebooks/.env (sibling of this lab_helpers/ package) so the
# Cognito test-user credentials aren't hardcoded in source. Falls back to
# the previous hardcoded values if no .env is present.
load_dotenv(Path(__file__).resolve().parent.parent / ".env")


# =====================================================
# COGNITO
# =====================================================

COGNITO_USERNAME = os.environ.get("COGNITO_USERNAME", "testuser")
COGNITO_PASSWORD = os.environ.get("COGNITO_PASSWORD", "MyPassword123!")  # pragma: allowlist secret


# =====================================================
# SECRETS MANAGER
# =====================================================

SM_NAME = "customer_support_agent"


# =====================================================
# AGENTCORE MEMORY
# =====================================================

ACTOR_ID = "customer_001"


# =====================================================
# LLM
# =====================================================

# Setup the model_id
MODEL_ID = "global.amazon.nova-2-lite-v1:0"