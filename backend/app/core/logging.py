"""Centralized logging configuration, applied once at app startup."""

import logging


def configure_logging() -> None:
    """Configure the root logger.

    Called once at import time by `app.main`, before any module-level
    logger (e.g. `logging.getLogger(__name__)`) is used elsewhere in the app.
    """
    logging.basicConfig(level=logging.INFO)
