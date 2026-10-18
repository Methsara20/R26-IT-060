FROM python:3.11-slim-bookworm

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PORT=80

# Install system dependencies required for ML libraries and building
RUN sed -i 's/http:/https:/g' /etc/apt/sources.list.d/debian.sources || true && \
    apt-get update && apt-get install -y \
    build-essential \
    libgomp1 \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements and install
COPY requirements.txt /app/
# Pre-install CPU-only PyTorch (drastically reduces image size and prevents emulator from hanging)
RUN pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY . /app/

# Expose the port
EXPOSE 80

# Start Uvicorn
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "80"]
