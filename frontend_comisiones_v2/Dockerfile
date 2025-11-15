# --- Etapa de "Build" ---
FROM debian:bookworm-slim AS build

# 1. Instalamos dependencias
RUN apt-get update && apt-get install -y \
    git \
    xz-utils \
    curl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# 2. Instalamos Flutter 3.19.5 manualmente
ENV FLUTTER_VERSION=3.19.5
ENV FLUTTER_ROOT="/usr/local/flutter"
RUN git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git ${FLUTTER_ROOT}
ENV PATH="${FLUTTER_ROOT}/bin:${PATH}"

# 3. Preparamos el entorno
RUN flutter doctor -v
RUN git config --global --add safe.directory /usr/local/flutter

# 4. Creamos el usuario
RUN useradd -ms /bin/bash appuser
WORKDIR /app
RUN chown -R appuser:appuser ${FLUTTER_ROOT}
RUN chown -R appuser:appuser /app

# 5. Cambiamos a usuario normal para instalar dependencias
USER appuser
COPY --chown=appuser:appuser pubspec.yaml ./
RUN flutter pub get

# 6. Copiamos el resto del proyecto
COPY --chown=appuser:appuser . .

# --- CORRECCIÓN DE PERMISOS ---
# Volvemos a root temporalmente para asegurar que TODOS los archivos copiados
# sean propiedad de appuser (esto arregla el error de "failed to create directory")
USER root
RUN chown -R appuser:appuser /app
USER appuser
# ------------------------------

# 7. Construimos la web
RUN flutter build web --release

# --- Etapa Final ---
FROM nginx:stable-alpine
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80