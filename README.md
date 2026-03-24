# GoClaw Deploy

Docker Compose configurations for deploying GoClaw — an AI agent gateway platform. Uses pre-built images from GitHub Container Registry (GHCR).

## What is GoClaw?

GoClaw is a Go-based AI agent gateway with a React web dashboard. It supports multiple LLM providers (OpenAI, Anthropic, Gemini, Deepseek, etc.), chat channels (Telegram, Discord, Lark, Zalo), and vector storage.

## Quick Start

### Prerequisites
- Docker & Docker Compose
- At least one LLM provider API key (OpenAI, Anthropic, Gemini, etc.)

### 1. Configure Environment

```bash
cp .env.example .env
```

Edit `.env` and add:
- At least one LLM provider key (e.g., `GOCLAW_ANTHROPIC_API_KEY`)
- Random values for `GOCLAW_GATEWAY_TOKEN` and `GOCLAW_ENCRYPTION_KEY`
- PostgreSQL password: `POSTGRES_PASSWORD`

### 2. Start the Service

**Local Docker (default):**
```bash
docker compose up -d
```

**VPS/Server:**
```bash
docker compose up -d
```

**Dokploy (PaaS platform):**
```bash
docker compose -f docker-compose-dokploy.yml up -d
```

### 3. Access Dashboard

Open http://localhost:3000 in your browser.

## Deployment Variants

| Compose File | Use Case | Network | Image Source |
|---|---|---|---|
| `docker-compose.yml` | Local Docker / VPS | Default bridge | GHCR (`ghcr.io/nextlevelbuilder/goclaw-web`) |
| `docker-compose-dokploy.yml` | Dokploy PaaS | External `dokploy-network` | GHCR (with Dokploy proxy) |

Both variants use:
- **Pre-built images** from GitHub Container Registry (auto-published by upstream CI/CD)
- **PostgreSQL 18** with pgvector extension for vector storage
- **Port 3000** mapped to container port 80

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Container: ghcr.io/nextlevelbuilder/goclaw-web         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  nginx (port 80)                                │   │
│  │  - Reverse proxy for /v1/ (API)                 │   │
│  │  - WebSocket proxy for /ws                      │   │
│  │  - SPA static files (React build)               │   │
│  └─────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────┐   │
│  │  GoClaw backend (internal port 18790)           │   │
│  │  - Go binary with migrations                    │   │
│  │  - Auto-upgrade on startup (managed mode)       │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
           ↓ (port 3000:80 mapped)
┌─────────────────────────────────────────────────────────┐
│  PostgreSQL 18 + pgvector                               │
│  - Vector database for embeddings                       │
│  - User, sessions, config storage                       │
│  - Internal only (not exposed)                          │
└─────────────────────────────────────────────────────────┘
```

## Environment Variables

### LLM Providers (at least one required)
```
GOCLAW_OPENROUTER_API_KEY=
GOCLAW_ANTHROPIC_API_KEY=
GOCLAW_OPENAI_API_KEY=
GOCLAW_GEMINI_API_KEY=
GOCLAW_DEEPSEEK_API_KEY=
GOCLAW_GROQ_API_KEY=
GOCLAW_MISTRAL_API_KEY=
GOCLAW_XAI_API_KEY=
GOCLAW_COHERE_API_KEY=
GOCLAW_PERPLEXITY_API_KEY=
GOCLAW_MINIMAX_API_KEY=
```

### Gateway Security (required)
```
GOCLAW_GATEWAY_TOKEN=             # Random token for external access
GOCLAW_ENCRYPTION_KEY=            # Random encryption key
```

### Channels (optional)
```
GOCLAW_TELEGRAM_TOKEN=
GOCLAW_DISCORD_TOKEN=
GOCLAW_LARK_APP_ID=
GOCLAW_LARK_APP_SECRET=
GOCLAW_ZALO_TOKEN=
```

### Database (managed mode)
```
POSTGRES_USER=goclaw             # Default
POSTGRES_PASSWORD=               # Required, set in .env
POSTGRES_DB=goclaw               # Default
```

### Ports
```
GOCLAW_PORT=3000                 # External port (maps to 80 in container)
```

## Troubleshooting

### Health check failed
```bash
docker compose logs goclaw --tail=50
```
Common causes:
- Database not ready: Check `postgres` health in `docker compose ps`
- Migration failed: Check logs for SQL errors
- Port conflict: `lsof -i :3000` (check if port 3000 is in use)

### Containers won't start
```bash
docker compose down -v
docker compose up -d
```

### Database needs reset
```bash
docker compose down -v  # Remove all volumes
docker compose up -d    # Fresh start
```

### Upgrade to latest version
```bash
./upgrade.sh           # Auto-detect and upgrade to latest
docker compose pull
docker compose up -d
```

### Upgrade to specific version
```bash
./upgrade.sh v2.8.4    # Upgrade to v2.8.4
docker compose pull
docker compose up -d
```

## Image Versions

Images are auto-published by upstream CI/CD:
- **Latest stable**: `ghcr.io/nextlevelbuilder/goclaw-web:latest`
- **Specific version**: `ghcr.io/nextlevelbuilder/goclaw-web:v2.4.7`

Check available versions: https://github.com/nextlevelbuilder/goclaw/pkgs/container/goclaw-web

## Security

- Non-root user (`goclaw`) inside container
- No new privileges, all capabilities dropped except SETUID/SETGID/CHOWN
- `/tmp` mounted noexec for exploit prevention
- Resource limits: 1GB RAM, 2 CPU, 200 PIDs
- Security headers: X-Content-Type-Options, X-Frame-Options, Referrer-Policy
- GZIP compression enabled
- Static asset caching (1 year, immutable)

## Support

For issues with goclaw-core, see https://github.com/nextlevelbuilder/goclaw

For deployment configurations, check this repository's issues.
