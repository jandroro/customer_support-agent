FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app
COPY config.yaml .

ENV PYTHONUNBUFFERED=1 \
    CONFIG_FILE=config.yaml

EXPOSE 8000

# Runs as root intentionally: local development relies on mounting the host's
# ~/.aws credentials (see docker-compose.yml), and matching a non-root
# container UID to the host user's UID is unnecessary friction for a dev
# container. Harden this (non-root user, IAM role instead of a profile)
# before using this image outside of local development.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
