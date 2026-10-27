FROM debian:bookworm-slim AS exporter
ARG TARGETARCH
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip python3 git libfontconfig1 libx11-6 libxcursor1 libxinerama1 libgl1 libasound2 libxi6 libxrandr2 libxrender1 libpulse0 libudev1 libvulkan1 libwayland-client0 && rm -rf /var/lib/apt/lists/*
RUN case "$TARGETARCH" in arm64) arch=arm64 ;; amd64) arch=x86_64 ;; *) exit 1 ;; esac; \
    curl -fsSL "https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.${arch}.zip" -o /tmp/godot.zip && \
    unzip /tmp/godot.zip -d /tmp/engine && mv /tmp/engine/Godot* /usr/local/bin/godot && chmod +x /usr/local/bin/godot && rm -rf /tmp/godot.zip /tmp/engine
WORKDIR /src
COPY tools/fetch_web_templates.py /tmp/fetch_web_templates.py
RUN python3 /tmp/fetch_web_templates.py --output /opt/web-templates
COPY . .
RUN mkdir -p build/templates && cp /opt/web-templates/*.zip build/templates/ && git config --global --add safe.directory /src && python3 tools/package_web.py

FROM nginx:1.28-alpine AS web
COPY deploy/web/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=exporter /src/build/web/ /usr/share/nginx/html/
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1

FROM python:3.12-slim-bookworm AS forge
WORKDIR /app
COPY requirements-authoring.txt requirements-web.txt ./
RUN pip install --no-cache-dir -r requirements-authoring.txt -r requirements-web.txt
COPY tools/forge/ tools/forge/
COPY tools/ai_assets.py tools/ai_assets.py
COPY server/ server/
RUN useradd --uid 10001 --create-home forge && mkdir -p /data/forge /backups && chown -R forge:forge /data /backups
USER forge
ENV FORGE_DATA_ROOT=/data/forge PYTHONUNBUFFERED=1
EXPOSE 8000
CMD ["uvicorn", "server.app:app", "--host", "0.0.0.0", "--port", "8000", "--no-access-log"]
