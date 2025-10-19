# Testing Guidelines

## General Testing Principles

- **Write tests for new features and bug fixes**
- **Tests should be independent and isolated**
- **Use descriptive test names that explain what is being tested**
- **Follow AAA pattern: Arrange, Act, Assert**
- **Test one thing per test**
- **Keep tests simple and readable**
- **Don't test implementation details, test behavior**
- **Fast tests are better than slow tests**

## Best Practices

### DO
- Write tests before fixing bugs (TDD for bug fixes)
- Test edge cases and boundary conditions
- Use descriptive test names
- Keep tests independent
- Use setup/teardown appropriately
- Mock external dependencies
- Test error conditions
- Aim for high coverage on critical paths
- Keep tests fast
- Test behavior, not implementation

### DON'T
- Test private methods directly
- Write tests that depend on each other
- Use sleep/wait unless necessary
- Test framework code
- Aim for 100% coverage blindly
- Write brittle tests that break with refactoring
- Ignore flaky tests
- Test third-party libraries
- Use production data in tests

## Coverage Guidelines

- **Critical paths**: 100% coverage
- **Business logic**: 80-90% coverage
- **Utilities**: 70-80% coverage
- **UI components**: 60-70% coverage
- **Overall target**: 70-80% coverage

Coverage is a metric, not a goal. Focus on testing important behavior.

## Test Types

### Unit Tests
- Test individual functions/methods in isolation
- Mock external dependencies
- Fast execution (milliseconds)
- Most numerous tests in your suite

### Integration Tests
- Test interactions between components
- May use real dependencies (databases, APIs)
- Slower than unit tests
- Test realistic scenarios

### End-to-End (E2E) Tests
- Test complete user workflows
- Use real systems
- Slowest tests
- Fewest in number
- Most valuable for critical paths

### Test Pyramid
```
        /\
       /E2E\       <- Few, slow, expensive
      /------\
     /  Intg  \    <- Some, moderate speed
    /----------\
   /   Unit     \  <- Many, fast, cheap
  /--------------\
```

## Naming Conventions

### Test File Names
```
Python:    test_user_service.py
Go:        user_service_test.go
Svelte:    UserCard.test.ts
Generic:   *.test.*, *_test.*, test_*.*
```

### Test Function Names

**Pattern**: `test_<what>_<condition>_<expected_result>`

```python
# Good
def test_calculate_discount_with_valid_input_returns_correct_amount()
def test_create_user_with_invalid_email_raises_validation_error()
def test_get_user_when_not_found_returns_none()

# Bad
def test_discount()
def test_user()
def test_1()
```

## Test Structure (AAA Pattern)

```python
def test_create_user_with_valid_data_succeeds():
    # Arrange - Set up test data and dependencies
    user_data = {
        "email": "test@example.com",
        "username": "testuser",
        "password": "SecurePass123"
    }
    repository = MockUserRepository()
    service = UserService(repository)
    
    # Act - Execute the code being tested
    result = service.create_user(user_data)
    
    # Assert - Verify the outcome
    assert result.success is True
    assert result.user.email == "test@example.com"
    assert result.user.username == "testuser"
```

## Python Testing

### Pytest

```python
import pytest
from unittest.mock import Mock, patch, MagicMock

# Basic test
def test_add_numbers():
    assert add(2, 3) == 5

# Test with exception
def test_divide_by_zero_raises_error():
    with pytest.raises(ZeroDivisionError):
        divide(10, 0)

# Test with specific error message
def test_invalid_email_raises_validation_error():
    with pytest.raises(ValidationError, match="Invalid email format"):
        validate_email("invalid")

# Parametrized tests
@pytest.mark.parametrize("email,expected", [
    ("valid@example.com", True),
    ("invalid", False),
    ("", False),
    ("test@test", False),
    ("test@test.co", True),
])
def test_email_validation(email, expected):
    assert validate_email(email) == expected

# Fixtures
@pytest.fixture
def sample_user():
    return User(id=1, username="test", email="test@example.com")

@pytest.fixture
def database():
    db = create_test_database()
    yield db
    db.cleanup()

def test_user_creation(database, sample_user):
    database.save(sample_user)
    assert database.get(sample_user.id) == sample_user

# Async tests
@pytest.mark.asyncio
async def test_async_fetch_user():
    user = await fetch_user(1)
    assert user.id == 1

# Mocking
def test_external_api_call():
    with patch('requests.get') as mock_get:
        mock_get.return_value.json.return_value = {'id': 1, 'name': 'Test'}
        result = fetch_user_from_api(1)
        assert result['id'] == 1
        mock_get.assert_called_once_with('/users/1')

# Mock object
def test_service_with_mock_repository():
    mock_repo = Mock()
    mock_repo.get_user.return_value = User(id=1, username="test")
    
    service = UserService(mock_repo)
    user = service.get_user(1)
    
    assert user.username == "test"
    mock_repo.get_user.assert_called_once_with(1)

# Test class organization
class TestUserService:
    def test_create_user_success(self):
        # Test implementation
        pass
    
    def test_create_user_duplicate_email_fails(self):
        # Test implementation
        pass
    
    def test_update_user_not_found_raises_error(self):
        # Test implementation
        pass
```

### Coverage

```bash
# Run with coverage
pytest --cov=src --cov-report=html tests/

# Coverage configuration (.coveragerc)
[run]
source = src
omit = 
    */tests/*
    */migrations/*
    */__init__.py

[report]
exclude_lines =
    pragma: no cover
    def __repr__
    raise AssertionError
    raise NotImplementedError
    if __name__ == .__main__.:
```

## Go Testing

### Standard Testing

```go
import (
    "testing"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/mock"
)

// Basic test
func TestAddNumbers(t *testing.T) {
    result := Add(2, 3)
    if result != 5 {
        t.Errorf("expected 5, got %d", result)
    }
}

// Using testify/assert
func TestCreateUser(t *testing.T) {
    user, err := NewUser("test@example.com", "test")
    assert.NoError(t, err)
    assert.Equal(t, "test@example.com", user.Email)
    assert.Equal(t, "test", user.Username)
}

// Table-driven tests
func TestValidateEmail(t *testing.T) {
    tests := []struct {
        name    string
        email   string
        wantErr bool
    }{
        {"valid email", "test@example.com", false},
        {"missing @", "testexample.com", true},
        {"empty string", "", true},
        {"missing domain", "test@", true},
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := ValidateEmail(tt.email)
            if (err != nil) != tt.wantErr {
                t.Errorf("ValidateEmail() error = %v, wantErr %v", err, tt.wantErr)
            }
        })
    }
}

// Subtests
func TestUserOperations(t *testing.T) {
    t.Run("Create", func(t *testing.T) {
        user, err := NewUser("test@example.com", "test")
        assert.NoError(t, err)
        assert.NotNil(t, user)
    })
    
    t.Run("Update", func(t *testing.T) {
        user := &User{Username: "old"}
        err := user.UpdateEmail("new@example.com")
        assert.NoError(t, err)
        assert.Equal(t, "new@example.com", user.Email)
    })
}

// Benchmarks
func BenchmarkCalculate(b *testing.B) {
    for i := 0; i < b.N; i++ {
        Calculate(100, 200)
    }
}

// Benchmark with setup
func BenchmarkDatabaseQuery(b *testing.B) {
    db := setupTestDB(b)
    defer db.Close()
    
    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        db.Query("SELECT * FROM users WHERE id = ?", i)
    }
}

// Test helpers
func setupTestDB(t testing.TB) *sql.DB {
    db, err := sql.Open("postgres", testConnectionString)
    if err != nil {
        t.Fatalf("failed to connect: %v", err)
    }
    
    t.Cleanup(func() {
        db.Close()
    })
    
    return db
}

// Mock using interface
type MockUserRepository struct {
    mock.Mock
}

func (m *MockUserRepository) Get(ctx context.Context, id int64) (*User, error) {
    args := m.Called(ctx, id)
    if args.Get(0) == nil {
        return nil, args.Error(1)
    }
    return args.Get(0).(*User), args.Error(1)
}

func TestUserService_GetUser(t *testing.T) {
    mockRepo := new(MockUserRepository)
    expectedUser := &User{ID: 1, Username: "test"}
    
    mockRepo.On("Get", mock.Anything, int64(1)).Return(expectedUser, nil)
    
    service := NewUserService(mockRepo)
    user, err := service.GetUser(context.Background(), 1)
    
    assert.NoError(t, err)
    assert.Equal(t, expectedUser, user)
    mockRepo.AssertExpectations(t)
}
```

## JavaScript/TypeScript Testing

### Jest

```typescript
import { describe, it, expect, beforeEach, afterEach, jest } from '@jest/globals';

// Basic test
describe('Calculator', () => {
    it('should add two numbers correctly', () => {
        expect(add(2, 3)).toBe(5);
    });
    
    it('should throw error for division by zero', () => {
        expect(() => divide(10, 0)).toThrow('Division by zero');
    });
});

// Setup and teardown
describe('UserService', () => {
    let service: UserService;
    let mockRepository: jest.Mocked<UserRepository>;
    
    beforeEach(() => {
        mockRepository = {
            findById: jest.fn(),
            save: jest.fn(),
        } as any;
        service = new UserService(mockRepository);
    });
    
    afterEach(() => {
        jest.clearAllMocks();
    });
    
    it('should fetch user by id', async () => {
        const expectedUser = { id: 1, name: 'Test' };
        mockRepository.findById.mockResolvedValue(expectedUser);
        
        const user = await service.getUser(1);
        
        expect(user).toEqual(expectedUser);
        expect(mockRepository.findById).toHaveBeenCalledWith(1);
    });
});

// Async/await
it('should fetch data asynchronously', async () => {
    const data = await fetchData();
    expect(data).toBeDefined();
    expect(data.id).toBeGreaterThan(0);
});

// Promises
it('should resolve promise', () => {
    return fetchData().then(data => {
        expect(data).toBeDefined();
    });
});

// Mocking modules
jest.mock('./api', () => ({
    fetchUser: jest.fn(() => Promise.resolve({ id: 1, name: 'Test' }))
}));

// Spying
const spy = jest.spyOn(console, 'log');
logMessage('test');
expect(spy).toHaveBeenCalledWith('test');
spy.mockRestore();

// Snapshots
it('should match snapshot', () => {
    const component = render(<UserCard user={mockUser} />);
    expect(component).toMatchSnapshot();
});
```

### Svelte Testing Library

```typescript
import { render, screen, fireEvent, waitFor } from '@testing-library/svelte';
import userEvent from '@testing-library/user-event';
import { describe, it, expect, vi } from 'vitest';
import UserCard from './UserCard.svelte';

describe('UserCard', () => {
    it('renders user information', () => {
        const user = { id: 1, name: 'John Doe', email: 'john@example.com' };
        render(UserCard, { props: { user } });
        
        expect(screen.getByText('John Doe')).toBeInTheDocument();
        expect(screen.getByText('john@example.com')).toBeInTheDocument();
    });
    
    it('calls onDelete when delete button is clicked', async () => {
        const onDelete = vi.fn();
        const user = { id: 1, name: 'John' };
        
        render(UserCard, { props: { user, onDelete } });
        
        const deleteButton = screen.getByRole('button', { name: /delete/i });
        await fireEvent.click(deleteButton);
        
        expect(onDelete).toHaveBeenCalledWith(1);
    });
    
    it('shows loading state', async () => {
        render(UserCard, { props: { userId: 1 } });
        
        expect(screen.getByText(/loading/i)).toBeInTheDocument();
        
        await waitFor(() => {
            expect(screen.queryByText(/loading/i)).not.toBeInTheDocument();
        });
    });
    
    it('handles user input', async () => {
        render(UserCard);
        const user = userEvent.setup();
        
        const input = screen.getByRole('textbox');
        await user.type(input, 'test@example.com');
        
        expect(input).toHaveValue('test@example.com');
    });
});
```

## Database Testing

### Test Database Setup

```python
# Python with pytest
@pytest.fixture(scope="session")
def test_db():
    """Create test database for the entire test session."""
    engine = create_engine("postgresql://test:test@localhost/test_db")
    Base.metadata.create_all(engine)
    yield engine
    Base.metadata.drop_all(engine)
    engine.dispose()

@pytest.fixture
def db_session(test_db):
    """Create a new session for each test."""
    connection = test_db.connect()
    transaction = connection.begin()
    session = Session(bind=connection)
    
    yield session
    
    session.close()
    transaction.rollback()
    connection.close()

def test_create_user(db_session):
    user = User(email="test@example.com", username="test")
    db_session.add(user)
    db_session.commit()
    
    assert user.id is not None
    retrieved = db_session.query(User).filter_by(id=user.id).first()
    assert retrieved.email == "test@example.com"
```

```go
// Go database testing
func setupTestDB(t *testing.T) *sql.DB {
    db, err := sql.Open("postgres", "postgres://test:test@localhost/test?sslmode=disable")
    if err != nil {
        t.Fatalf("failed to connect to test db: %v", err)
    }
    
    // Run migrations
    if err := runMigrations(db); err != nil {
        t.Fatalf("failed to run migrations: %v", err)
    }
    
    t.Cleanup(func() {
        db.Exec("TRUNCATE TABLE users CASCADE")
        db.Close()
    })
    
    return db
}

func TestCreateUser(t *testing.T) {
    db := setupTestDB(t)
    repo := NewUserRepository(db)
    
    user := &User{Email: "test@example.com", Username: "test"}
    err := repo.Create(context.Background(), user)
    
    assert.NoError(t, err)
    assert.NotZero(t, user.ID)
}
```

## API Testing

### HTTP Testing

```python
# Python with pytest and requests
def test_get_user_endpoint(client):
    response = client.get('/api/users/1')
    
    assert response.status_code == 200
    assert response.json()['id'] == 1
    assert 'email' in response.json()

def test_create_user_endpoint(client):
    user_data = {
        "email": "test@example.com",
        "username": "testuser"
    }
    
    response = client.post('/api/users', json=user_data)
    
    assert response.status_code == 201
    assert response.json()['email'] == user_data['email']

def test_unauthorized_access(client):
    response = client.get('/api/admin/users')
    assert response.status_code == 401
```

```go
// Go HTTP testing
func TestGetUserHandler(t *testing.T) {
    mockRepo := new(MockUserRepository)
    handler := NewUserHandler(mockRepo)
    
    user := &User{ID: 1, Username: "test"}
    mockRepo.On("Get", mock.Anything, int64(1)).Return(user, nil)
    
    req := httptest.NewRequest("GET", "/users/1", nil)
    w := httptest.NewRecorder()
    
    handler.ServeHTTP(w, req)
    
    assert.Equal(t, http.StatusOK, w.Code)
    
    var response User
    json.NewDecoder(w.Body).Decode(&response)
    assert.Equal(t, "test", response.Username)
}
```

## Test Data Management

### Factories

```python
# Python factory pattern
class UserFactory:
    @staticmethod
    def create(
        email: str = "test@example.com",
        username: str = "testuser",
        is_active: bool = True,
        **kwargs
    ) -> User:
        return User(
            email=email,
            username=username,
            is_active=is_active,
            **kwargs
        )

# Usage
def test_active_users():
    active_user = UserFactory.create(is_active=True)
    inactive_user = UserFactory.create(is_active=False)
    
    assert active_user.is_active
    assert not inactive_user.is_active
```

### Fixtures

```python
# Shared test data
@pytest.fixture
def valid_user_data():
    return {
        "email": "test@example.com",
        "username": "testuser",
        "password": "SecurePass123"
    }

@pytest.fixture
def sample_users():
    return [
        User(id=1, username="user1", email="user1@test.com"),
        User(id=2, username="user2", email="user2@test.com"),
        User(id=3, username="user3", email="user3@test.com"),
    ]
```

## Continuous Integration

```yaml
# GitHub Actions example
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      
      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          pip install -r requirements-dev.txt
      
      - name: Run tests
        run: |
          pytest tests/ --cov=src --cov-report=xml
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
```
