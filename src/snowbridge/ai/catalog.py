from typing import Any

from snowbridge.models import AiPlanResponse, OperationName, PlanStatus

OPERATION_CATALOG: list[dict[str, Any]] = [
    {
        "name": OperationName.ECHO,
        "description": "Return a supplied message to verify connectivity.",
        "parameters": {"message": "Required non-empty string."},
    },
    {
        "name": OperationName.CURRENT_CONTEXT,
        "description": "Return the current Snowflake account, user, role, and warehouse.",
        "parameters": {},
    },
    {
        "name": OperationName.WAREHOUSE_USAGE_SUMMARY,
        "description": "Summarize warehouse credits and execution time over a recent period.",
        "parameters": {"days": "Required integer from 1 through 90."},
    },
]


def validate_plan(plan: AiPlanResponse) -> AiPlanResponse:
    if plan.status is not PlanStatus.READY:
        return plan
    if plan.operation is None:
        raise ValueError("A ready plan must select an operation.")

    parameters = plan.parameters
    if plan.operation is OperationName.ECHO:
        message = parameters.get("message")
        if not isinstance(message, str) or not message.strip():
            raise ValueError("The echo operation requires a non-empty message.")
    elif plan.operation is OperationName.CURRENT_CONTEXT:
        if parameters:
            raise ValueError("The current_context operation does not accept parameters.")
    elif plan.operation is OperationName.WAREHOUSE_USAGE_SUMMARY:
        days = parameters.get("days")
        if isinstance(days, bool) or not isinstance(days, int) or not 1 <= days <= 90:
            raise ValueError("Warehouse usage requires an integer days value from 1 through 90.")

    return plan