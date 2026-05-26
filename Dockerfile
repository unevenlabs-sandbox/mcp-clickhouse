# Build stage - Use a Python image with uv pre-installed
FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim AS builder

# Install the project into `/app`
WORKDIR /app

# Enable bytecode compilation
ENV UV_COMPILE_BYTECODE=1

# Copy from the cache instead of linking since it's a mounted volume
ENV UV_LINK_MODE=copy

# Install git and build dependencies for ClickHouse client
RUN apt-get update && apt-get install -y --no-install-recommends git build-essential && rm -rf /var/lib/apt/lists/*

# Install the project's dependencies using the lockfile and settings
COPY uv.lock pyproject.toml README.md ./
RUN uv sync --locked --no-install-project --no-dev

# Then, add the rest of the project source code and install it
# Installing separately from its dependencies allows optimal layer caching
COPY . /app
RUN uv sync --locked --no-dev --no-editable

# Production stage - Use minimal Python image
FROM python:3.13-slim-bookworm

LABEL org.opencontainers.image.source="https://github.com/ClickHouse/mcp-clickhouse"
LABEL org.opencontainers.image.description="MCP server for ClickHouse"
LABEL org.opencontainers.image.licenses="Apache-2.0"

# Set the working directory
WORKDIR /app

# Copy the virtual environment from the builder stage
COPY --from=builder /app/.venv /app/.venv

# Place executables in the environment at the front of the path
ENV PATH="/app/.venv/bin:$PATH"

# Run the MCP ClickHouse server by default
CMD ["python", "-m", "mcp_clickhouse.main"]
