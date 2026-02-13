FROM python:latest

WORKDIR /claude-code-proxy

# Copy package specifications
COPY pyproject.toml uv.lock ./

# Install uv and project dependencies
RUN pip install --upgrade uv && uv sync --locked

# Copy project code to current directory
COPY . .

# Start the proxy
EXPOSE 8082
CMD ["uv", "run", "uvicorn", "server:app", "--host", "127.0.0.1", "--port", "8082"]
