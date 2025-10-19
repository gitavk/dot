# Claude Project Instructions

This document contains coding standards and best practices for this project. Follow these guidelines when writing or modifying code.

## General Principles

- Write clean, readable, and maintainable code
- Prefer explicit over implicit
- Use meaningful variable and function names
- Keep functions small and focused (single responsibility)
- Write tests for new features and bug fixes
- Document complex logic and non-obvious decisions
- Follow the Boy Scout Rule: leave code better than you found it

## Python

### Style & Standards
- Follow PEP 8 style guide
- Use type hints for function signatures and complex variables
- Maximum line length: 120 characters (ruff formatter default)
- Use `snake_case` for functions and variables, `PascalCase` for classes
- Use docstrings Google for all public functions and classes

### Code Patterns
```python
# Good: Type hints and clear names
def calculate_total_price(items: list[dict], tax_rate: float) -> float:
    """Calculate total price including tax."""
    subtotal = sum(item["price"] * item["quantity"] for item in items)
    return subtotal * (1 + tax_rate)

# Use context managers for resources
with open("file.txt") as f:
    data = f.read()

# Prefer list/dict comprehensions when readable
active_users = [u for u in users if u.is_active]
```

### Project Structure
```
project/
├── src/
│   ├── __init__.py
│   ├── main.py
│   ├── models/
│   ├── services/
│   └── utils/
├── tests/
│   ├── __init__.py
│   ├── test_models.py
│   └── test_services.py
├── pyproject.toml
├── requirements.txt
└── README.md
```

### Dependencies & Tools
- Use `pyproject.toml` for modern Python projects
- Pin dependencies with version ranges: `requests>=2.31.0,<3.0.0`
- Tools: `black` (formatting), `ruff` (linting), `mypy` (type checking), `pytest` (testing)

## Go

### Style & Standards
- Follow official Go style guide and `gofmt` formatting
- Use `camelCase` for private, `PascalCase` for exported identifiers
- Keep packages focused and cohesive
- Error handling: always check errors, don't ignore them
- Use meaningful error messages with context

### Code Patterns
```go
// Good: Clear error handling and naming
func FetchUser(ctx context.Context, id int64) (*User, error) {
    user, err := db.Query(ctx, "SELECT * FROM users WHERE id = $1", id)
    if err != nil {
        return nil, fmt.Errorf("failed to fetch user %d: %w", id, err)
    }
    return user, nil
}

// Use defer for cleanup
func ProcessFile(path string) error {
    f, err := os.Open(path)
    if err != nil {
        return err
    }
    defer f.Close()
    
    // Process file...
    return nil
}

// Use context for cancellation and timeouts
ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
defer cancel()
```

### Project Structure
```
project/
├── cmd/
│   └── app/
│       └── main.go
├── internal/
│   ├── handlers/
│   ├── models/
│   └── services/
├── pkg/
│   └── utils/
├── go.mod
├── go.sum
└── README.md
```

### Best Practices
- Use `internal/` for code that shouldn't be imported by other projects
- Use `pkg/` for reusable libraries
- Keep `main.go` minimal, move logic to packages
- Use interfaces for dependency injection and testing
- Run `go mod tidy` regularly
- Tools: `gofmt`, `golangci-lint`, `go test -race`

## Svelte

### Style & Standards
- Use TypeScript for type safety
- One component per file
- Keep components small and focused
- Use `$:` reactive statements for derived values
- Props should be clearly defined at the top of the script section

### Code Patterns
```svelte
<script lang="ts">
  // Props first
  export let userId: number;
  export let showDetails = false;
  
  // State
  let user: User | null = null;
  let loading = false;
  
  // Reactive declarations
  $: fullName = user ? `${user.firstName} ${user.lastName}` : '';
  
  // Functions
  async function loadUser() {
    loading = true;
    try {
      user = await fetchUser(userId);
    } catch (err) {
      console.error('Failed to load user:', err);
    } finally {
      loading = false;
    }
  }
  
  // Lifecycle
  onMount(() => {
    loadUser();
  });
</script>

<div class="user-card">
  {#if loading}
    <Spinner />
  {:else if user}
    <h2>{fullName}</h2>
  {:else}
    <p>User not found</p>
  {/if}
</div>

<style>
  .user-card {
    padding: 1rem;
    border-radius: 0.5rem;
  }
</style>
```

### Project Structure
```
src/
├── lib/
│   ├── components/
│   ├── stores/
│   ├── utils/
│   └── types/
├── routes/
├── app.html
└── app.css
```

### Best Practices
- Use stores for shared state (`writable`, `derived`, `readable`)
- Keep business logic separate from components
- Use `$:` for reactive updates, not manual DOM manipulation
- Leverage SvelteKit for routing, SSR, and API endpoints
- Use `{#key}` blocks to force component recreation when needed

## PostgreSQL

### Schema Design
- Use meaningful table and column names (snake_case)
- Always define primary keys
- Use appropriate data types (don't use `text` for everything)
- Add NOT NULL constraints where appropriate
- Use FOREIGN KEY constraints for referential integrity
- Add indexes for frequently queried columns

### Best Practices
```sql
-- Good table design
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    username VARCHAR(50) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users(email);

-- Use transactions for multiple operations
BEGIN;
    INSERT INTO users (email, username) VALUES ('user@example.com', 'user123');
    INSERT INTO user_profiles (user_id, bio) VALUES (LASTVAL(), 'Bio text');
COMMIT;

-- Use parameterized queries to prevent SQL injection
-- In application code:
-- cursor.execute("SELECT * FROM users WHERE email = %s", (email,))
```

### Migrations
- Use migration tools (e.g., `goose`, `flyway`, `alembic`)
- Name migrations with timestamp: `20231015_create_users_table.sql`
- Always write both `up` and `down` migrations
- Never modify existing migrations in production
- Test migrations on a copy of production data

### Performance
- Use `EXPLAIN ANALYZE` to understand query performance
- Add indexes for WHERE, JOIN, and ORDER BY columns
- Use appropriate JOIN types (INNER, LEFT, etc.)
- Avoid SELECT *, specify needed columns
- Use connection pooling in applications
- Regular VACUUM and ANALYZE for maintenance

## Kafka

### Topic Design
- Use clear, hierarchical naming: `domain.entity.event` (e.g., `orders.payment.completed`)
- Choose partition count based on throughput needs
- Set appropriate replication factor (at least 2 for prod)
- Define retention policies based on use case
- Use schema registry for message schemas (Avro, Protobuf, JSON Schema)

### Producer Best Practices
```python
# Python example
from kafka import KafkaProducer
import json

producer = KafkaProducer(
    bootstrap_servers=['localhost:9092'],
    value_serializer=lambda v: json.dumps(v).encode('utf-8'),
    acks='all',  # Wait for all replicas
    retries=3,
    max_in_flight_requests_per_connection=1  # Ensure ordering
)

# Include metadata in messages
message = {
    'event_id': str(uuid.uuid4()),
    'timestamp': datetime.utcnow().isoformat(),
    'event_type': 'user.created',
    'data': {
        'user_id': 123,
        'email': 'user@example.com'
    }
}

producer.send('users.events', value=message, key=str(user_id).encode('utf-8'))
producer.flush()  # Ensure delivery
```

### Consumer Best Practices
```python
# Python example
from kafka import KafkaConsumer

consumer = KafkaConsumer(
    'users.events',
    bootstrap_servers=['localhost:9092'],
    group_id='user-processor',
    auto_offset_reset='earliest',
    enable_auto_commit=False,  # Manual commit for control
    value_deserializer=lambda m: json.loads(m.decode('utf-8'))
)

for message in consumer:
    try:
        process_message(message.value)
        consumer.commit()  # Commit after successful processing
    except Exception as e:
        logger.error(f"Failed to process message: {e}")
        # Implement retry logic or send to DLQ
```

### Key Patterns
- **Idempotent consumers**: Handle duplicate messages gracefully
- **At-least-once delivery**: Ensure messages are processed even if duplicated
- **Dead Letter Queue (DLQ)**: Route failed messages for investigation
- **Message ordering**: Use same key for related messages
- **Schema evolution**: Use schema registry for backward/forward compatibility

### Monitoring & Operations
- Monitor consumer lag (messages behind)
- Set up alerts for partition rebalancing
- Monitor disk usage and set retention policies
- Use consumer groups for scalability
- Implement health checks for producers and consumers

## Testing

### Python
```python
import pytest

def test_calculate_total():
    items = [{'price': 10.0, 'quantity': 2}]
    assert calculate_total_price(items, 0.1) == 22.0

@pytest.mark.asyncio
async def test_async_function():
    result = await fetch_data()
    assert result is not None
```

### Go
```go
func TestFetchUser(t *testing.T) {
    user, err := FetchUser(context.Background(), 1)
    if err != nil {
        t.Fatalf("expected no error, got %v", err)
    }
    if user.ID != 1 {
        t.Errorf("expected user ID 1, got %d", user.ID)
    }
}
```

### Svelte
```typescript
import { render, screen } from '@testing-library/svelte';
import UserCard from './UserCard.svelte';

test('renders user name', () => {
  render(UserCard, { props: { userId: 1 } });
  expect(screen.getByText(/John Doe/i)).toBeInTheDocument();
});
```

## Documentation

- Keep README.md up to date with setup instructions
- Document API endpoints (OpenAPI/Swagger for REST)
- Add inline comments for complex logic only
- Use docstrings/JSDoc for public functions
- Document environment variables and configuration
- Include examples in documentation

---
