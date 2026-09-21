from snowbridge.ai.client import AiPlanner
from snowbridge.ai.foundry_client import FoundryAiPlanner
from snowbridge.ai.mock_client import MockAiPlanner
from snowbridge.config import Settings


def create_ai_planner(settings: Settings) -> AiPlanner:
    if settings.ai_backend == "foundry":
        return FoundryAiPlanner(settings)
    return MockAiPlanner()