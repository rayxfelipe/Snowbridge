import re

from snowbridge.ai.catalog import validate_plan
from snowbridge.models import AiPlanResponse, OperationName, PlanStatus


class MockAiPlanner:
    def plan(self, request: str) -> AiPlanResponse:
        normalized = request.casefold()
        if any(term in normalized for term in ("ignore instructions", "drop table", "raw sql")):
            return AiPlanResponse(
                status=PlanStatus.REJECTED,
                explanation="The request attempts to bypass the approved operation catalog.",
            )

        if "warehouse" in normalized and any(
            term in normalized for term in ("usage", "credit", "cost", "summary")
        ):
            day_match = re.search(r"\b(\d{1,3})\s+days?\b", normalized)
            if day_match is None:
                return AiPlanResponse(
                    status=PlanStatus.NEEDS_CLARIFICATION,
                    explanation="A time range is required for warehouse usage.",
                    clarification_question=(
                        "How many recent days should the summary include (1-90)?"
                    ),
                )
            days = int(day_match.group(1))
            if not 1 <= days <= 90:
                return AiPlanResponse(
                    status=PlanStatus.NEEDS_CLARIFICATION,
                    explanation="Warehouse usage supports a period from 1 through 90 days.",
                    clarification_question="Choose a number of days from 1 through 90.",
                )
            return validate_plan(
                AiPlanResponse(
                    status=PlanStatus.READY,
                    operation=OperationName.WAREHOUSE_USAGE_SUMMARY,
                    parameters={"days": days},
                    explanation="Summarize recent Snowflake warehouse usage.",
                )
            )

        if "context" in normalized or "current account" in normalized:
            return AiPlanResponse(
                status=PlanStatus.READY,
                operation=OperationName.CURRENT_CONTEXT,
                explanation="Retrieve the active Snowflake connection context.",
            )

        if normalized.startswith(("echo ", "repeat ", "say ")):
            message = request.split(maxsplit=1)[1].strip()
            return validate_plan(
                AiPlanResponse(
                    status=PlanStatus.READY,
                    operation=OperationName.ECHO,
                    parameters={"message": message},
                    explanation="Echo the requested message.",
                )
            )

        return AiPlanResponse(
            status=PlanStatus.REJECTED,
            explanation="No approved Snowbridge operation matches this request.",
        )