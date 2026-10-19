FROM smartomniretailr26.azurecr.io/backend:latest

WORKDIR /app

# Copy application files
COPY . /app/
RUN mkdir -p /app/generated /app/uploads

# Expose the port
EXPOSE 80

# Start Uvicorn
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "80"]
