# Python Guidelines

Python-specific coding standards and best practices.

## Style & Standards

- Follow **PEP 8** style guide
- Use **type hints** for function signatures and complex variables
- Maximum line length: **120 characters** (ruff formatter default)
- Use `snake_case` for functions and variables, `PascalCase` for classes

## Best Practices

- Use **virtual environments** (venv, conda)
- Pin dependencies with version ranges
- Use `.env` files for configuration (never commit them)
- Use `if __name__ == "__main__":` for script entry points
- Avoid mutable default arguments
- Use `pathlib` instead of `os.path`
- Prefer `f-strings` over `.format()` or `%` formatting
- Use `logging` instead of `print()` for production code
- Keep functions under 50 lines
- Write tests for new features and bug fixes

## Code Patterns

### Context Managers
```python
# Always use context managers for resources
with open("file.txt") as f:
    data = f.read()

# Multiple context managers
with open("input.txt") as infile, open("output.txt", "w") as outfile:
    outfile.write(infile.read())
```

### Comprehensions
```python
# List comprehension (prefer when readable)
active_users = [u for u in users if u.is_active]

# Dict comprehension
user_emails = {u.id: u.email for u in users}

# Generator expression (memory efficient)
total = sum(item.price for item in large_dataset)

# Set comprehension
unique_domains = {email.split('@')[1] for email in emails}
```

### Iterators and Generators
```python
# Generator function
def read_large_file(file_path: str):
    """Read file line by line without loading into memory."""
    with open(file_path) as f:
        for line in f:
            yield line.strip()
```

### Enums
```python
from enum import Enum, auto

class UserRole(Enum):
    ADMIN = "admin"
    APPROVED = auto()
    REJECTED = auto()
```

## Error Handling

```python
# Specific exceptions
try:
    result = risky_operation()
except ValueError as e:
    logger.error(f"Invalid value: {e}")
    raise
except ConnectionError:
    logger.warning("Connection failed, retrying...")
    retry()
else:
    # Runs if no exception
    logger.info("Operation succeeded")
finally:
    # Always runs
    cleanup()

# Custom exceptions
class UserNotFoundError(Exception):
    """Raised when user cannot be found."""
    pass

class ValidationError(Exception):
    """Raised when validation fails."""
    def __init__(self, field: str, message: str):
        self.field = field
        self.message = message
        super().__init__(f"{field}: {message}")
```

## Async/Await

```python
import asyncio
import aiohttp

async def fetch_user(session: aiohttp.ClientSession, user_id: int) -> dict:
    """Fetch user data asynchronously."""
    async with session.get(f"/api/users/{user_id}") as response:
        return await response.json()

async def fetch_all_users(user_ids: list[int]) -> list[dict]:
    """Fetch multiple users concurrently."""
    async with aiohttp.ClientSession() as session:
        tasks = [fetch_user(session, uid) for uid in user_ids]
        return await asyncio.gather(*tasks)
```

## Project Structure

```
project/
├── src/
│   ├── __init__.py
│   ├── main.py
│   ├── config.py
│   ├── models/
│   │   ├── __init__.py
│   │   └── user.py
│   ├── services/
│   │   ├── __init__.py
│   │   └── user_service.py
│   ├── repositories/
│   │   ├── __init__.py
│   │   └── user_repository.py
│   ├── api/
│   │   ├── __init__.py
│   │   ├── routes.py
│   │   └── schemas.py
│   └── utils/
│       ├── __init__.py
│       └── helpers.py
├── tests/
│   ├── __init__.py
│   ├── conftest.py
│   ├── test_models/
│   ├── test_services/
│   └── test_api/
├── pyproject.toml
├── requirements.txt
├── requirements-dev.txt
├── .env.example
├── README.md
└── .gitignore
```

## Dependencies

### pyproject.toml
```toml
[project]
name = "myproject"
version = "0.1.0"
requires-python = ">=3.10"
dependencies = [
    "fastapi>=0.104.0,<1.0.0",
    "sqlalchemy>=2.0.0,<3.0.0",
    "pydantic>=2.0.0,<3.0.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=7.4.0",
    "ruff>=0.1.0",
    "mypy>=1.7.0",
]
```

## Tools

### Ruff (Formatting, Linting)
```bash
ruff check src/ tests/
ruff check --fix src/ tests/
```

### Mypy (Type Checking)
```bash
mypy src/
```

### Pytest (Testing)
```bash
pytest tests/ -v
pytest tests/ --cov=src --cov-report=html
```

## Testing

```python
import pytest
from unittest.mock import Mock, patch

def test_calculate_total():
    items = [{'price': 10.0, 'quantity': 2}]
    assert calculate_total_price(items, 0.1) == 22.0

def test_invalid_tax_rate():
    items = [{'price': 10.0, 'quantity': 1}]
    with pytest.raises(ValueError, match="Tax rate cannot be negative"):
        calculate_total_price(items, -0.1)

@pytest.mark.asyncio
async def test_async_function():
    result = await fetch_data()
    assert result is not None

# Fixtures
@pytest.fixture
def sample_user():
    return User(id=1, username="test", email="test@example.com")

def test_user_validation(sample_user):
    assert sample_user.is_valid()

# Parametrized tests
@pytest.mark.parametrize("email,expected", [
    ("valid@example.com", True),
    ("invalid", False),
    ("", False),
])
def test_email_validation(email, expected):
    assert validate_email(email) == expected

# Mocking
def test_external_api_call():
    with patch('requests.get') as mock_get:
        mock_get.return_value.json.return_value = {'id': 1}
        result = fetch_user_from_api(1)
        assert result['id'] == 1
        mock_get.assert_called_once()
```

## Configuration

```python
# config.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    app_name: str = "MyApp"
    database_url: str
    api_key: str
    debug: bool = False
    
    class Config:
        env_file = ".env"

settings = Settings()
```

## Anti-Patterns to Avoid

```python
# ❌ Mutable default arguments
def add_item(item, items=[]):  # BAD
    items.append(item)
    return items

# ✅ Use None and create new list
def add_item(item, items=None):  # GOOD
    if items is None:
        items = []
    items.append(item)
    return items

# ❌ Bare except
try:
    risky()
except:  # BAD - catches everything including KeyboardInterrupt
    pass

# ✅ Specific exceptions
try:
    risky()
except (ValueError, TypeError) as e:  # GOOD
    handle_error(e)

# ❌ String concatenation in loops
result = ""
for item in items:
    result += str(item)  # BAD - creates new string each time

# ✅ Use join
result = "".join(str(item) for item in items)  # GOOD

# ❌ Using is for value comparison
if name is "John":  # BAD

# ✅ Use == for values
if name == "John":  # GOOD

# ❌ Not closing files
f = open("file.txt")  # BAD
data = f.read()

# ✅ Use context manager
with open("file.txt") as f:  # GOOD
    data = f.read()
```
