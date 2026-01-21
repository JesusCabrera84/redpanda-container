# Redpanda Container Setup

Este proyecto contiene la configuración necesaria para levantar un nodo de Redpanda dentro de un contenedor Docker, optimizado para desarrollo local y despliegue automático.

## Características

- Autenticación SASL/SCRAM habilitada por defecto.
- Creación explícita de tópicos durante el bootstrap (auto-create deshabilitado).
- Configuración de usuarios Admin (`superuser`) y usuarios de aplicación (`producer`/`consumer`).
- ACLs configuradas para restringir el acceso a los tópicos.
- Soporte para VS Code Dev Containers.
- Despliegue automático con GitHub Actions.

## Requisitos Previos

- Docker y Docker Compose instalados.
- Red y volumen externos creados.

## How to run locally

Ensure the network and volume exist:

```bash
docker network create siscom-network
docker volume create redpanda_data
```

Create your `.env` file from the example:

```bash
cp .env.example .env
```

(Optional) Edit `.env` to change default users and passwords.

Build and start:

```bash
docker-compose up -d --build
```

The setup runs automatically! You can monitor progress with:

```bash
docker logs -f redpanda-0
```

### 4. Comandos Útiles (RPK)

**Ver información del cluster:**

```bash
docker exec -it redpanda-0 rpk cluster info \
  -X user=superuser \
  -X pass=secretpassword \
  -X sasl.mechanism=SCRAM-SHA-256
```

**Listar tópicos:**

```bash
docker exec -it redpanda-0 rpk topic list \
  -X user=superuser \
  -X pass=secretpassword \
  -X sasl.mechanism=SCRAM-SHA-256
```
