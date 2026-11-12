# ساخت از ریشه‌ی پروژه (تا foods.json اپ هم کپی شود):
#   docker build -f server/Dockerfile -t calorielens-api .
#   docker run --env-file server/.env -p 8000:8000 -v cl-data:/data calorielens-api
FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app

COPY server/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY server/app ./app
# همان پایگاه غذای اپ؛ کالری فقط از این فایل حساب می‌شود.
COPY assets/data/foods.json ./foods.json

ENV FOODS_PATH=/app/foods.json DB_PATH=/data/calorielens.db
RUN mkdir -p /data && useradd --system --uid 10001 app && chown app /data
USER app
VOLUME ["/data"]
EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers"]
