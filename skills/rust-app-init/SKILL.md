---
name: rust-app-init
description: Creates a production-ready Rust application project structure with modern tooling including Cargo, Axum, Docker, and CI/CD templates.
---
# Rust Application Project Initializer

## Overview
This skill creates a production-ready Rust application project structure with modern tooling:
- Cargo for dependency management
- Axum web framework setup
- Docker multi-stage build configuration
- SQLx with PostgreSQL (compile-time checked queries)
- Tower middleware stack
- Testing infrastructure
- CI/CD templates

## Prerequisites
- Rust 1.75+ (2024 edition support)
- Cargo installed via rustup
- Docker (optional, for containerization)
- SQLx CLI (optional, for migrations): `cargo install sqlx-cli`

## Project Structure Template
````
project_name/
├── src/
│   ├── main.rs                  # Application entry point
│   ├── lib.rs                   # Library root (re-exports)
│   ├── config.rs                # Configuration management
│   ├── error.rs                 # Error types and handling
│   ├── api/                     # HTTP handlers
│   │   ├── mod.rs
│   │   └── v1/
│   │       ├── mod.rs
│   │       ├── health.rs
│   │       └── routes.rs
│   ├── domain/                  # Core business logic & types
│   │   └── mod.rs
│   ├── db/                      # Database layer
│   │   ├── mod.rs
│   │   └── models.rs
│   └── services/                # Business services
│       └── mod.rs
├── migrations/                  # SQLx migrations
│   └── .keep
├── tests/
│   ├── common/
│   │   └── mod.rs               # Shared test helpers
│   └── api_tests.rs             # Integration tests
├── Cargo.toml                   # Dependencies & metadata
├── Cargo.lock                   # Lock file
├── Dockerfile
├── compose.yml
├── .env.example
├── .gitignore
├── Makefile                     # Common commands
├── rust-toolchain.toml          # Pin Rust version
└── README.md
````

## Step-by-Step Initialization

### Step 1: Create Project Structure
````bash
PROJECT_NAME=$1

# Initialize Cargo project
cargo init --name $PROJECT_NAME $PROJECT_NAME

cd $PROJECT_NAME

# Create directory structure
mkdir -p src/{api/v1,domain,db,services}
mkdir -p tests/common
mkdir -p migrations
touch migrations/.keep
````

### Step 2: Create Cargo.toml
````toml
[package]
name = "project_name"
version = "0.1.0"
edition = "2024"
rust-version = "1.85"

[dependencies]
# Web framework
axum = { version = "0.8", features = ["macros"] }
tower = { version = "0.5", features = ["util", "timeout"] }
tower-http = { version = "0.6", features = ["cors", "trace", "compression-gzip"] }

# Async runtime
tokio = { version = "1", features = ["full"] }

# Serialization
serde = { version = "1", features = ["derive"] }
serde_json = "1"

# Database
sqlx = { version = "0.8", features = ["runtime-tokio-rustls", "postgres", "uuid", "chrono", "migrate"] }

# Configuration
dotenvy = "0.15"

# Logging / Tracing
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter", "json"] }

# Error handling
thiserror = "2"
anyhow = "1"

# Utilities
uuid = { version = "1", features = ["v4", "serde"] }
chrono = { version = "0.4", features = ["serde"] }

[dev-dependencies]
reqwest = { version = "0.12", features = ["json"] }
tokio-test = "0.4"

[profile.release]
lto = true
codegen-units = 1
strip = true
panic = "abort"

[lints.rust]
unsafe_code = "forbid"

[lints.clippy]
enum_glob_use = "deny"
pedantic = { level = "warn", priority = -1 }
module_name_repetitions = "allow"
must_use_candidate = "allow"
missing_errors_doc = "allow"
missing_panics_doc = "allow"
````

### Step 3: Create rust-toolchain.toml
````toml
[toolchain]
channel = "stable"
components = ["rustfmt", "clippy"]
````

### Step 4: Create Main Application File
````rust
// src/main.rs
use project_name::config::Config;
use project_name::api;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    dotenvy::dotenv().ok();

    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info,tower_http=debug".into()),
        )
        .init();

    let config = Config::from_env()?;
    let addr = format!("{}:{}", config.host, config.port);

    let pool = sqlx::postgres::PgPoolOptions::new()
        .max_connections(config.database.pool_size)
        .connect(&config.database.url)
        .await?;

    sqlx::migrate!().run(&pool).await?;

    let app = api::router(pool);

    let listener = tokio::net::TcpListener::bind(&addr).await?;
    tracing::info!("listening on {addr}");
    axum::serve(listener, app).await?;

    Ok(())
}
````

### Step 5: Create Library Root
````rust
// src/lib.rs
pub mod api;
pub mod config;
pub mod db;
pub mod domain;
pub mod error;
pub mod services;
````

### Step 6: Create Configuration Management
````rust
// src/config.rs
use anyhow::{Context, Result};

#[derive(Debug, Clone)]
pub struct Config {
    pub host: String,
    pub port: u16,
    pub database: DatabaseConfig,
    pub cors_origins: Vec<String>,
}

#[derive(Debug, Clone)]
pub struct DatabaseConfig {
    pub url: String,
    pub pool_size: u32,
}

impl Config {
    pub fn from_env() -> Result<Self> {
        Ok(Self {
            host: std::env::var("HOST").unwrap_or_else(|_| "0.0.0.0".into()),
            port: std::env::var("PORT")
                .unwrap_or_else(|_| "8080".into())
                .parse()
                .context("PORT must be a number")?,
            database: DatabaseConfig {
                url: std::env::var("DATABASE_URL")
                    .context("DATABASE_URL must be set")?,
                pool_size: std::env::var("DATABASE_POOL_SIZE")
                    .unwrap_or_else(|_| "5".into())
                    .parse()
                    .context("DATABASE_POOL_SIZE must be a number")?,
            },
            cors_origins: std::env::var("CORS_ORIGINS")
                .unwrap_or_else(|_| "http://localhost:3000".into())
                .split(',')
                .map(|s| s.trim().to_string())
                .collect(),
        })
    }
}
````

### Step 7: Create Error Types
````rust
// src/error.rs
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};

#[derive(Debug, thiserror::Error)]
pub enum AppError {
    #[error("not found: {0}")]
    NotFound(String),

    #[error("bad request: {0}")]
    BadRequest(String),

    #[error("unauthorized")]
    Unauthorized,

    #[error(transparent)]
    Database(#[from] sqlx::Error),

    #[error(transparent)]
    Internal(#[from] anyhow::Error),
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, message) = match &self {
            Self::NotFound(msg) => (StatusCode::NOT_FOUND, msg.clone()),
            Self::BadRequest(msg) => (StatusCode::BAD_REQUEST, msg.clone()),
            Self::Unauthorized => (StatusCode::UNAUTHORIZED, "unauthorized".into()),
            Self::Database(e) => {
                tracing::error!("database error: {e:?}");
                (StatusCode::INTERNAL_SERVER_ERROR, "internal error".into())
            }
            Self::Internal(e) => {
                tracing::error!("internal error: {e:?}");
                (StatusCode::INTERNAL_SERVER_ERROR, "internal error".into())
            }
        };

        let body = serde_json::json!({ "error": message });
        (status, axum::Json(body)).into_response()
    }
}
````

### Step 8: Create API Layer
````rust
// src/api/mod.rs
pub mod v1;

use axum::Router;
use sqlx::PgPool;
use tower_http::cors::{Any, CorsLayer};
use tower_http::trace::TraceLayer;

pub fn router(pool: PgPool) -> Router {
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);

    Router::new()
        .nest("/api/v1", v1::routes::router())
        .layer(TraceLayer::new_for_http())
        .layer(cors)
        .with_state(pool)
}
````

````rust
// src/api/v1/mod.rs
pub mod health;
pub mod routes;
````

````rust
// src/api/v1/routes.rs
use axum::Router;
use sqlx::PgPool;

use super::health;

pub fn router() -> Router<PgPool> {
    Router::new().merge(health::router())
}
````

````rust
// src/api/v1/health.rs
use axum::{extract::State, routing::get, Json, Router};
use sqlx::PgPool;

pub fn router() -> Router<PgPool> {
    Router::new().route("/health", get(health_check))
}

async fn health_check(State(pool): State<PgPool>) -> Json<serde_json::Value> {
    let db_ok = sqlx::query_scalar::<_, i32>("SELECT 1")
        .fetch_one(&pool)
        .await
        .is_ok();

    Json(serde_json::json!({
        "status": if db_ok { "healthy" } else { "degraded" },
        "database": db_ok,
    }))
}
````

### Step 9: Create Module Stubs
````rust
// src/db/mod.rs
pub mod models;
````

````rust
// src/db/models.rs
// Define your SQLx models here
````

````rust
// src/domain/mod.rs
// Define your domain types here
````

````rust
// src/services/mod.rs
// Define your business services here
````

### Step 10: Create Docker Configuration
````dockerfile
# Dockerfile
FROM rust:1.85-slim AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*

# Cache dependency build
COPY Cargo.toml Cargo.lock ./
RUN mkdir src && echo "fn main() {}" > src/main.rs && echo "" > src/lib.rs
RUN cargo build --release && rm -rf src

# Build the actual application
COPY src/ ./src/
COPY migrations/ ./migrations/
RUN touch src/main.rs src/lib.rs && cargo build --release

FROM debian:bookworm-slim AS runtime

RUN apt-get update && apt-get install -y ca-certificates libssl3 && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/project_name /usr/local/bin/app

EXPOSE 8080

CMD ["app"]
````

````yaml
# compose.yml
services:
  api:
    build: .
    ports:
      - "8080:8080"
    environment:
      - DATABASE_URL=postgres://postgres:postgres@db:5432/appdb
      - RUST_LOG=info,tower_http=debug
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16-alpine
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=appdb
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
````

### Step 11: Create .env.example
````
HOST=0.0.0.0
PORT=8080
DATABASE_URL=postgres://postgres:postgres@localhost:5432/appdb
DATABASE_POOL_SIZE=5
CORS_ORIGINS=http://localhost:3000
RUST_LOG=info,tower_http=debug
````

### Step 12: Create Makefile
````makefile
# Makefile
.PHONY: help build run test lint format clean docker-build docker-up docker-down migrate

# Colors for output
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
WHITE  := $(shell tput -Txterm setaf 7)
RESET  := $(shell tput -Txterm sgr0)

help:
	@echo ''
	@echo 'Usage:'
	@echo '  ${YELLOW}make${RESET} ${GREEN}<target>${RESET}'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} { \
		if (/^[a-zA-Z_-]+:.*?##.*$$/) {printf "    ${YELLOW}%-20s${GREEN}%s${RESET}\n", $$1, $$2} \
		else if (/^## .*$$/) {printf "  ${WHITE}%s${RESET}\n", substr($$1,4)} \
		}' $(MAKEFILE_LIST)

## Development
build: ## Build in debug mode
	cargo build

build-release: ## Build optimized release binary
	cargo build --release

run: ## Run development server with auto-reload
	cargo watch -x run

run-release: ## Run release binary
	cargo run --release

dev: ## Run with RUST_LOG=debug and auto-reload
	RUST_LOG=debug,tower_http=trace cargo watch -x run

## Testing
test: ## Run all tests
	cargo test -- --nocapture

test-unit: ## Run unit tests only
	cargo test --lib -- --nocapture

test-integration: ## Run integration tests only
	cargo test --test '*' -- --nocapture

test-coverage: ## Run tests with coverage (requires cargo-llvm-cov)
	cargo llvm-cov --html

## Code Quality
lint: ## Run clippy linter
	@echo "${GREEN}Running clippy...${RESET}"
	cargo clippy --all-targets -- -D warnings

format: ## Format code with rustfmt
	@echo "${GREEN}Running rustfmt...${RESET}"
	cargo fmt

format-check: ## Check formatting without changes
	cargo fmt -- --check

check: format-check lint test ## Run format check, lint, and tests

audit: ## Audit dependencies for vulnerabilities (requires cargo-audit)
	cargo audit

## Database
db-create: ## Create database
	sqlx database create

db-drop: ## Drop database
	sqlx database drop -y

db-migrate: ## Run all pending migrations
	sqlx migrate run

db-revert: ## Revert last migration
	sqlx migrate revert

db-reset: db-drop db-create db-migrate ## Reset database (drop, create, migrate)

db-prepare: ## Generate offline SQLx query data
	cargo sqlx prepare

## Docker
docker-build: ## Build Docker image
	docker compose build

docker-up: ## Start all Docker services
	docker compose up -d

docker-down: ## Stop all Docker services
	docker compose down

docker-logs: ## Follow Docker service logs
	docker compose logs -f

docker-shell: ## Open shell in API container
	docker compose exec api sh

docker-db-shell: ## Open PostgreSQL shell
	docker compose exec db psql -U postgres appdb

docker-restart: ## Restart Docker services
	docker compose restart

docker-clean: ## Remove all Docker containers, volumes, and images
	docker compose down -v --rmi all

## Utilities
clean: ## Clean build artifacts
	@echo "${GREEN}Cleaning build artifacts...${RESET}"
	cargo clean
	@echo "${GREEN}Done!${RESET}"

deps-update: ## Update all dependencies
	cargo update

deps-outdated: ## Show outdated dependencies (requires cargo-outdated)
	cargo outdated

deps-tree: ## Show dependency tree
	cargo tree

## CI/CD Simulation
ci: format-check lint test ## Simulate CI pipeline locally

## Recommended tools install
setup-tools: ## Install recommended cargo tools
	cargo install cargo-watch cargo-audit cargo-outdated cargo-llvm-cov sqlx-cli
````

### Step 13: Create .gitignore
````
# Build artifacts
/target
debug/
*.pdb

# Editor
.vscode/
.idea/
*.swp
*.swo
*~

# Environment
.env
.env.local

# OS
.DS_Store
Thumbs.db

# SQLx offline mode
# Uncomment if NOT using offline mode:
# .sqlx/
````

### Step 14: Create README Template
````markdown
# Project Name

Backend API service built with Rust, Axum, and SQLx.

## Features

- Axum web framework with Tower middleware
- SQLx with compile-time checked PostgreSQL queries
- Structured logging with tracing
- Docker multi-stage builds
- Comprehensive error handling
- CI/CD ready

## Quick Start

### Prerequisites

Install Rust via [rustup](https://rustup.rs/):
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

Install recommended tools:
```bash
make setup-tools
```

### Local Development

1. Start PostgreSQL (or use Docker):
```bash
docker compose up db -d
```

2. Copy environment file:
```bash
cp .env.example .env
```

3. Run migrations:
```bash
make db-migrate
```

4. Run development server:
```bash
make dev
```

API will be available at http://localhost:8080

### Docker

```bash
make docker-up
```

## Development

### Run tests
```bash
make test
```

### Format code
```bash
make format
```

### Lint code
```bash
make lint
```

### Full CI check
```bash
make ci
```

## Project Structure

- `src/api/` - HTTP handlers and routing
- `src/domain/` - Core business types
- `src/db/` - Database models and queries
- `src/services/` - Business service layer
- `src/config.rs` - Configuration from environment
- `src/error.rs` - Application error types
- `migrations/` - SQLx database migrations
- `tests/` - Integration tests

## Environment Variables

See `.env.example` for required configuration.
````

## Usage Examples

### Example 1: Initialize New Axum Project
````bash
# In Claude/Cursor:
Prompt: "Use rust-app-init skill to create a new Rust API project called 'inventory-service'"

# Skill will:
1. Create Cargo project and directory structure
2. Generate all source files with Axum + SQLx setup
3. Set up Docker environment with PostgreSQL
4. Create Makefile with common commands
5. Configure clippy lints and release profile
````

## Best Practices

1. **Use clippy pedantic** lints to catch common issues early
2. **Compile-time SQL** with SQLx ensures queries are valid before deploy
3. **Multi-stage Docker builds** keep images small (~20MB)
4. **Tower middleware** for cross-cutting concerns (tracing, CORS, timeouts)
5. **Follow the layered architecture**: API handlers -> Services -> DB layer

## Checklist After Initialization

- [ ] Update project name in Cargo.toml
- [ ] Set DATABASE_URL in .env
- [ ] Configure CORS_ORIGINS for your frontend
- [ ] Create initial migration: `sqlx migrate add initial`
- [ ] Run tests: `make test`
- [ ] Build Docker image: `make docker-build`
- [ ] Verify health endpoint: `curl localhost:8080/api/v1/health`

## Next Steps

After initialization:
1. Define domain types in `src/domain/`
2. Create database models and migrations in `src/db/` and `migrations/`
3. Add API endpoints in `src/api/v1/`
4. Implement business logic in `src/services/`
5. Write integration tests in `tests/`
