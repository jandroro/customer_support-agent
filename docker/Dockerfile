FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim

WORKDIR /app

# Install build tools for compiling dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements.txt
COPY docker/requirements.txt .

# Use uv pip to install dependencies 
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install --system --no-cache -r requirements.txt

RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install --system --no-cache aws-opentelemetry-distro==0.12.2

# Copy app source code and pyproject.toml
COPY src/ ./src/
COPY pyproject.toml .

# All environment variables in one layer
ENV UV_SYSTEM_PYTHON=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_NO_PROGRESS=1 \
    PYTHONUNBUFFERED=1 \
    DOCKER_CONTAINER=1 \
    AWS_REGION=us-east-1 \
    AWS_DEFAULT_REGION=us-east-1

# Signal that this is running in Docker for host binding logic
ENV DOCKER_CONTAINER=1

# OpenTelemetry Configuration for AgentCore observability
# Change this to a unique name for your agent
ENV OTEL_SERVICE_NAME=customer_support_agent
ENV OTEL_TRACES_EXPORTER=otlp
ENV OTEL_METRICS_EXPORTER=otlp

# AWS OpenTelemetry Distribution
ENV OTEL_PYTHON_DISTRO=aws_distro
ENV OTEL_PYTHON_CONFIGURATOR=aws_configurator

# Export Protocol
ENV OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf

# CloudWatch Integration (uncomment and configure as needed)
#ENV OTEL_EXPORTER_OTLP_LOGS_HEADERS = x-aws-log-group=agents/strands-agent-logs,x-aws-log-stream=default,x-aws-metric-namespace=agents

# Enable Agent Observability
ENV AGENT_OBSERVABILITY_ENABLED=true

# Service Identification
ENV OTEL_TRACES_SAMPLER=always_on
ENV OTEL_RESOURCE_ATTRIBUTES=service.namespace=AgentCore,service.version=1.0

# Create non-root user
RUN useradd -m -u 1000 bedrock_agentcore
USER bedrock_agentcore

EXPOSE 9000
EXPOSE 8000
EXPOSE 8080

# Run with OpenTelemetry auto-instrumentation.
# Run as a script (not "python -m") so the script's own directory
# (src/customer_support_agent/) lands on sys.path[0] — main.py's
# "from agent_helpers.* import ..." imports depend on that, since there are
# no __init__.py files making this a proper installable package.
CMD ["opentelemetry-instrument", "python", "src/customer_support_agent/main.py"]
