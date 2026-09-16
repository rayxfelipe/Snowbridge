FROM python:3.13-slim

ARG SNOWBRIDGE_EXTRAS=""
ARG PIP_INDEX_URL="https://pypi.org/simple"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000

WORKDIR /app

RUN addgroup --system snowbridge \
    && adduser --system --ingroup snowbridge snowbridge

COPY pyproject.toml README.md ./
COPY src ./src

RUN pip install --no-cache-dir ".${SNOWBRIDGE_EXTRAS}"

USER snowbridge
EXPOSE 8000

ENTRYPOINT ["uvicorn", "snowbridge.main:app", "--host", "0.0.0.0", "--port", "8000"]
