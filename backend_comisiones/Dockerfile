# --- Etapa de "Build" ---
# Usamos la imagen oficial de Dart para construir el proyecto
FROM dart:stable AS build

# Creamos una carpeta de trabajo
WORKDIR /app

# Copiamos los archivos de dependencias y las instalamos
# Esto se hace primero para aprovechar el caché de Docker
COPY pubspec.yaml pubspec.lock ./
RUN dart pub get

# Copiamos todo el proyecto
COPY . .

# Generamos la build de producción de Dart Frog
RUN dart pub global activate dart_frog_cli
RUN dart_frog build

# --- Etapa Final (Producción) ---
# Usamos la imagen 'stable'
FROM dart:stable 

WORKDIR /app

# --- INICIO DE LA CORRECCIÓN ---
# 1. Copiamos la build de producción (el servidor)
COPY --from=build /app/build .

# 2. Copiamos las dependencias ya resueltas de la etapa 'build'
COPY --from=build /app/.dart_tool .dart_tool

# 3. Copiamos los pubspec para que todo sea consistente
COPY --from=build /app/pubspec.lock /app/pubspec.yaml ./
# --- FIN DE LA CORRECCIÓN ---

# 4. Ya no necesitamos 'dart pub get' porque copiamos .dart_tool

# El puerto que tu backend usa
EXPOSE 8086

# El comando para iniciar el servidor de producción
CMD ["dart", "run", "bin/server.dart"]