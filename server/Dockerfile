# Stage 1: Build binary AOT mandiri dengan Dart resmi
FROM dart:stable AS build

WORKDIR /app
COPY pubspec.yaml ./
RUN dart pub get

COPY . .
RUN dart pub get --offline
RUN dart compile exe bin/server.dart -o bin/server

# Stage 2: Runtime image super ramping & aman
FROM debian:bookworm-slim

# Pasang CA certificates untuk koneksi HTTPS keluar
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /app/bin/server /app/server
COPY --from=build /app/web /app/web
COPY --from=build /app/web /app/server/web

ENV PORT=8082
EXPOSE 8082

CMD ["/app/server"]
