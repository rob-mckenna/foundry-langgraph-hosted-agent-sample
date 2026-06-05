FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1             PYTHONUNBUFFERED=1             PYTHONPATH=/app/src

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8080

CMD ["python", "-m", "uvicorn", "standalone_api.app:app", "--app-dir", "src", "--host", "0.0.0.0", "--port", "8080"]
