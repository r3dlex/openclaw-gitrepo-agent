FROM python:3.11-slim

RUN pip install poetry && poetry config virtualenvs.create false

WORKDIR /app
COPY pyproject.toml poetry.lock* ./
RUN poetry install --no-interaction --no-ansi --no-root

COPY . .
RUN poetry install --no-interaction --no-ansi

CMD ["python", "-m", "pipeline_runner"]
