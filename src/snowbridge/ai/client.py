from typing import Protocol

from snowbridge.models import AiPlanResponse


class AiPlanner(Protocol):
    def plan(self, request: str) -> AiPlanResponse: ...


class AiPlannerError(RuntimeError):
    """Raised when an AI provider cannot produce a safe operation plan."""


class AiPlannerConfigurationError(AiPlannerError):
    """Raised when the configured AI provider is missing required settings."""