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

# 1. Copia los archivos pubspec PRIMERO
COPY --from=build /app/pubspec.lock /app/pubspec.yaml ./

# 2. Ejecuta 'dart pub get' OTRA VEZ en la imagen final
# Esto es crucial y es lo que faltaba.
# Usará el .lock para instalar las dependencias exactas.
RUN dart pub get

# 3. Ahora copia la build (el código del servidor)
COPY --from=build /app/build .

# El puerto que tu backend usa
EXPOSE 8086

# El comando para iniciar el servidor de producción
# (Este comando es el que fallaba antes)
CMD ["dart", "run", "bin/server.dart"]