# =============================================================================
# OpenClaw GitRepo Agent — Multi-Stage Dockerfile
# =============================================================================
# Zero-install: users need only Docker to run the full agent.
# =============================================================================

# --- Stage 1: Elixir Build ---
FROM elixir:1.16-slim AS elixir-build

RUN mix local.hex --force && mix local.rebar --force

WORKDIR /app
COPY mix.exs ./
RUN mix deps.get && mix deps.compile

COPY lib/ lib/
COPY config/ config/
RUN MIX_ENV=prod mix compile

# --- Stage 2: Python Build ---
FROM python:3.11-slim AS python-build

RUN pip install --no-cache-dir poetry && poetry config virtualenvs.create false

WORKDIR /app/tools/pipeline_runner
COPY tools/pipeline_runner/pyproject.toml tools/pipeline_runner/poetry.lock* ./
RUN poetry install --no-interaction --no-ansi --no-root

COPY tools/pipeline_runner/ .
RUN poetry install --no-interaction --no-ansi

# --- Stage 3: Runtime ---
FROM elixir:1.16-slim AS runtime

# Install Python, git, SSH, and common tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv \
    git curl jq openssh-client \
    && rm -rf /var/lib/apt/lists/*

# SSH config: host keys are accepted on first connect, keys mounted at runtime
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh

# Copy Elixir app
WORKDIR /app
COPY --from=elixir-build /app/_build /app/_build
COPY --from=elixir-build /app/deps /app/deps
COPY mix.exs ./
COPY lib/ lib/
COPY config/ config/

# Copy Python pipeline runner
COPY --from=python-build /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/dist-packages/
COPY tools/pipeline_runner/ /app/tools/pipeline_runner/

# Copy agent files
COPY AGENTS.md SOUL.md IDENTITY.md HEARTBEAT.md TOOLS.md USER.md CLAUDE.md ./
COPY spec/ spec/
COPY .archgate/ .archgate/
COPY input/ input/

# Default: run the Elixir agent
CMD ["mix", "run", "--no-halt"]
