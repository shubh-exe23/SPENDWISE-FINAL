FROM python:3.14-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
RUN useradd --create-home appuser
COPY app.py config.py cron.py reset_store.py gunicorn.conf.py ./
COPY models ./models
COPY routes ./routes
USER appuser
CMD ["gunicorn", "--config", "gunicorn.conf.py", "app:app"]
