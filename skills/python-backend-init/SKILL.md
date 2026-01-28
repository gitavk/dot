---
name: python-backend-init
description: Creates a production-ready Python backend project structure with modern tooling including UV, FastAPI, Docker, and CI/CD templates.
---
# Python Backend Project Initializer

## Overview
This skill creates a production-ready Python backend project structure with modern tooling:
- UV for dependency management
- FastAPI framework setup
- Docker configuration
- Pre-commit hooks
- Testing infrastructure
- CI/CD templates

## Prerequisites
- Python 3.11+
- UV package manager installed
- Docker (optional, for containerization)

## Project Structure Template
````
project_name/
├── src/
│   └── project_name/
│       ├── __init__.py
│       ├── main.py              # Application entry point
│       ├── config.py            # Configuration management
│       ├── api/                 # API routes
│       │   ├── __init__.py
│       │   └── v1/
│       │       ├── __init__.py
│       │       └── endpoints/
│       ├── core/                # Core business logic
│       │   ├── __init__.py
│       │   └── domain/
│       ├── db/                  # Database layer
│       │   ├── __init__.py
│       │   ├── models.py
│       │   └── repositories.py
│       └── services/            # Business services
│           └── __init__.py
├── tests/
│   ├── __init__.py
│   ├── unit/
│   ├── integration/
│   └── conftest.py
├── pyproject.toml               # Project dependencies
├── uv.lock                      # Lock file
├── Dockerfile
├── compose.yml
├── .env.example
├── .gitignore
├── Makefile                     # Common commands
└── README.md
````

## Step-by-Step Initialization

### Step 1: Create Project Structure
````bash
PROJECT_NAME=$1

# Initialize pyproject.toml with UV
uv init --name $PROJECT_NAME --lib

# Create directory structure
mkdir -p $PROJECT_NAME/{src/$PROJECT_NAME/{api/v1/endpoints,core/domain,db,services},tests/{unit,integration}}

cd $PROJECT_NAME
````

### Step 2: Initialize UV Project
````bash
# Add common dependencies
uv add fastapi uvicorn[standard] pydantic pydantic-settings
uv add sqlalchemy alembic asyncpg
uv add python-jose[cryptography] passlib[bcrypt]
uv add python-multipart aiofiles
uv add httpx

# Add dev dependencies
uv add --dev pytest pytest-asyncio pytest-cov pytest-randomly
uv add --dev ruff
````

### Step 3: Create pyproject.toml Configuration
````toml
[project]
name = "project_name"
version = "0.1.0"
description = "Backend API service"
readme = "README.md"
requires-python = ">=3.11"
dependencies = [ ]

[project.optional-dependencies]
dev = [ ]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.ruff]
line-length = 120
target-version = "py311"
src = ["src"]

[tool.ruff.lint]
extend-select = [
  "Q",      # flake8-quotes
  "I",      # isort
  "C90",    # {name} is too complex
  "RUF100", # Unused noqa (auto-fixable)
  "T20",    # print detected
]

[tool.ruff.lint.per-file-ignores]
"__init__.py" = ["F401"]

[tool.pytest.ini_options]
pythonpath = ["."]
asyncio_mode = "auto"
filterwarnings = "error"
addopts = "--cov=src --cov-report=term-missing"

[tool.coverage.run]
# Threads are used by FastAPI and greenlet by SQLAlchemy
concurrency = ["thread", "greenlet"]
````

### Step 4: Create Main Application File
````python
# src/project_name/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .api.v1 import api_router
from .config import settings

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API router
app.include_router(api_router, prefix=settings.API_V1_STR)


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "project_name.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
    )
````

### Step 5: Create Configuration Management
````python
# src/project_name/config.py
from typing import List
from pydantic_settings import BaseSettings, SettingsConfigDict

class PostgresConf(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=ENV_PATH, env_prefix="POSTGRES_", extra="ignore", env_file_encoding="utf-8"
    )

    USER: str = Field(default="")
    PASSWORD: str = Field(default="")
    DB: str = Field(default="")
    HOST: str = Field(default="")
    PORT: int = Field(default=5432)
    POOL_SIZE: int = Field(default=5)
    MAX_OVERFLOW: int = Field(default=10)

    @property
    def URL(self) -> str:
        return f"postgresql+asyncpg://{self.USER}:{self.PASSWORD}@{self.HOST}:{self.PORT}/{self.DB}"



class Settings(BaseSettings):
    """Application settings"""
    
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
    )
    
    # Project
    PROJECT_NAME: str = "Backend API"
    VERSION: str = "0.1.0"
    API_V1_STR: str = "/api/v1"
    
    # CORS
    ALLOWED_ORIGINS: List[str] = ["http://localhost:3000"]
    
    DATABASE: PostgresConf = PostgresConf()
    # Security
    SECRET_KEY: str = "your-secret-key-change-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    
    # Redis (optional)
    REDIS_URL: str = "redis://localhost:6379/0"


settings = Settings()
````

### Step 6: Create Docker Configuration
````dockerfile
# Dockerfile
FROM python:3.12-slim as base

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Install UV
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Copy dependency files
COPY pyproject.toml uv.lock ./

# Install dependencies
RUN uv sync --frozen --no-dev

# Copy application code
COPY src/ ./src/

# Expose port
EXPOSE 8000

# Run application
CMD ["uv", "run", "uvicorn", "project_name.main:app", "--host", "0.0.0.0", "--port", "8000"]
````
````yaml
# compose.yml
services:
  api:
    build: .
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgresql+asyncpg://postgres:postgres@db:5432/appdb
      - REDIS_URL=redis://redis:6379/0
    depends_on:
      - db
      - redis
    volumes:
      - ./src:/app/src
    command: uv run uvicorn project_name.main:app --host 0.0.0.0 --port 8000 --reload

  db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=appdb
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
````

### Step 8: Create Makefile
````makefile
# Makefile
.PHONY: help install dev test lint format clean docker-build docker-up docker-down migrate db-upgrade db-downgrade db-revision

# Colors for output
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
WHITE  := $(shell tput -Txterm setaf 7)
RESET  := $(shell tput -Txterm sgr0)

# Help target
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
install: ## Install all dependencies with UV
	uv sync --all-extras

install-prod: ## Install production dependencies only
	uv sync --no-dev

dev: ## Run development server with hot reload
	uv run uvicorn src.project_name.main:app --reload --host 0.0.0.0 --port 8000

dev-debug: ## Run development server with debug logging
	uv run uvicorn src.project_name.main:app --reload --host 0.0.0.0 --port 8000 --log-level debug

## Testing
test: ## Run all tests with coverage
	uv run pytest tests/ -v --cov=src --cov-report=term-missing -p no:cacheprovider

test-unit: ## Run only unit tests
	uv run pytest tests/unit/ -v

test-integration: ## Run only integration tests
	uv run pytest tests/integration/ -v

## Code Quality
lint: ## Run linter ruff
	@echo "${GREEN}Running ruff...${RESET}"
	uv run ruff check --no-cache src/ tests/

lint-fix: ## Run linters with auto-fix
	uv run ruff check --fix --no-cache src/ tests/

format: ## Format code with ruff
	@echo "${GREEN}Running format...${RESET}"
	uv run ruff format --no-cache src/ tests/

format-check: ## Check code formatting without changes
	uv run ruff format --check --no-cache src/ tests/

check: format lint test ## Run format, lint, and tests (pre-commit check)

## Database
db-upgrade: ## Upgrade database to latest migration
	uv run alembic upgrade head

db-downgrade: ## Downgrade database by one revision
	uv run alembic downgrade -1

db-revision: ## Create new migration (use MSG="description")
	@if [ -z "$(MSG)" ]; then \
		echo "${YELLOW}Please provide migration message: make db-revision MSG='your message'${RESET}"; \
		exit 1; \
	fi
	uv run alembic revision --autogenerate -m "$(MSG)"

db-history: ## Show migration history
	uv run alembic history

db-current: ## Show current migration version
	uv run alembic current

db-reset: ## Reset database (downgrade all, upgrade all)
	uv run alembic downgrade base
	uv run alembic upgrade head

## Docker
docker-build: ## Build Docker image
	docker-compose build

docker-up: ## Start all Docker services
	docker-compose up -d

docker-down: ## Stop all Docker services
	docker-compose down

docker-shell: ## Open shell in API container
	docker-compose exec api bash

docker-db-shell: ## Open PostgreSQL shell
	docker-compose exec db psql -U $POSTGRES_USER $POSTGRES_DB

docker-restart: ## Restart Docker services
	docker-compose restart

docker-clean: ## Remove all Docker containers, volumes, and images
	docker-compose down -v --rmi all

## Utilities
clean: ## Clean cache files and build artifacts
	@echo "${GREEN}Cleaning Python cache files...${RESET}"
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	find . -type f -name "*.pyo" -delete
	find . -type f -name "*.coverage" -delete
	@echo "${GREEN}Cleaning build artifacts...${RESET}"
	rm -rf .pytest_cache .mypy_cache .ruff_cache htmlcov/ dist/ build/ *.egg-info
	@echo "${GREEN}Done!${RESET}"

clean-all: clean ## Clean everything including UV cache
	rm -rf .venv/
	uv cache clean

deps-update: ## Update all dependencies to latest versions
	uv lock --upgrade

deps-outdated: ## Show outdated dependencies
	uv pip list --outdated

deps-tree: ## Show dependency tree
	uv pip tree

## CI/CD Simulation
ci: clean lint test ## Simulate CI pipeline locally

## Production
build-prod: ## Build production Docker image
	docker build -t project_name:latest -f Dockerfile.prod .

run-prod: ## Run production server (use with caution)
	uv run gunicorn src.project_name.main:app \
		--workers 4 \
		--worker-class uvicorn.workers.UvicornWorker \
		--bind 0.0.0.0:8000 \
		--access-logfile - \
		--error-logfile -

## Documentation
docs-serve: ## Serve API documentation locally
	@echo "API docs available at: http://localhost:8000/docs"
	@echo "ReDoc available at: http://localhost:8000/redoc"
	@$(MAKE) dev

````

### Step 9: Create .gitignore
````
# .gitignore
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg

# Virtual environments
venv/
ENV/
env/
.venv

# UV
.uv/
uv.lock

# Testing
.pytest_cache/
.coverage
htmlcov/
*.cover

# IDEs
.vscode/
.idea/
*.swp
*.swo

# Environment
.env
.env.local

# Database
*.db
*.sqlite3

# Logs
*.log
logs/

# OS
.DS_Store
Thumbs.db
````

### Step 10: Create README Template
````markdown
# Project Name

Backend API service built with FastAPI and Python 3.11+

## Features

- ✅ FastAPI with async support
- ✅ SQLAlchemy 2.0 with async PostgreSQL
- ✅ JWT authentication
- ✅ Docker & Docker Compose
- ✅ Pre-commit hooks
- ✅ Comprehensive testing setup
- ✅ CI/CD ready

## Quick Start

### Local Development

1. Install UV:
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

2. Install dependencies:
```bash
make install
```

3. Copy environment file:
```bash
cp .env.example .env
```

4. Run development server:
```bash
make dev
```

API will be available at http://localhost:8000
Docs at http://localhost:8000/docs

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

## Project Structure

- `src/project_name/` - Main application code
  - `api/` - API endpoints
  - `core/` - Business logic
  - `db/` - Database models and repositories
  - `services/` - Service layer
- `tests/` - Test suite
- `scripts/` - Utility scripts

## Environment Variables

See `.env.example` for required configuration.
````

## Usage Examples

### Example 1: Initialize New FastAPI Project
````bash
# In Claude/Cursor:
Prompt: "Use python-backend-init skill to create a new FastAPI project called 'ecommerce-api'"

# Skill will:
1. Create directory structure
2. Initialize UV project
3. Generate all configuration files
4. Set up Docker environment
5. Create Makefile with common commands
````

## Best Practices

1. **Always use UV** for dependency management (faster than pip)
2. **Start with Docker** for consistent development environment
3. **Write tests first** using the provided test structure
4. **Use environment variables** for all configuration
5. **Follow the layered architecture**: API → Services → Repositories

## Checklist After Initialization

- [ ] Update PROJECT_NAME in config.py
- [ ] Change SECRET_KEY in .env
- [ ] Configure ALLOWED_ORIGINS for CORS
- [ ] Set up database connection string
- [ ] Run initial tests: `make test`
- [ ] Build Docker image: `make docker-build`
- [ ] Verify API docs: http://localhost:8000/docs

## Next Steps

After initialization:
1. Define database models in `db/models.py`
2. Create API endpoints in `api/v1/endpoints/`
3. Implement business logic in `services/`
4. Write tests in `tests/`
