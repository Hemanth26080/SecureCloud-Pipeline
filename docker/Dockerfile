# === STAGE 1: Build stage (install deps, then throw away the build tools) ===
FROM python:3.11-slim AS builder

WORKDIR /build

# Install build dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# === STAGE 2: Runtime stage (only what's needed to RUN the app) ===
FROM python:3.11-slim

# Security: run as non-root user (not as admin!)
RUN groupadd --gid 1001 appgroup && \
    useradd --uid 1001 --gid appgroup --create-home appuser

WORKDIR /app

# Copy installed Python packages from builder stage
COPY --from=builder /root/.local /home/appuser/.local

# Copy app code
COPY app/ .

# Own the files as appuser (not root)
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Set PATH so Python finds our packages
ENV PATH=/home/appuser/.local/bin:$PATH
ENV PYTHONUNBUFFERED=1

# Tell Docker which port the app listens on
EXPOSE 5000

# Healthcheck (Docker will ping /health every 30s)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Start the app with gunicorn (production web server, better than python main.py)
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--threads", "4", "main:app"]
