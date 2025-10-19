# Go Guidelines

Go-specific coding standards and best practices.

## Style & Standards

- Follow official **Go style guide** and **Effective Go**
- Use `gofmt` for automatic formatting
- Use `camelCase` for private identifiers, `PascalCase` for exported
- Keep packages focused and cohesive
- **Always check errors**, never ignore them
- Use meaningful error messages with context

## Best Practices

- Keep `main.go` minimal, move logic to packages
- Use `internal/` for code that shouldn't be imported
- Accept interfaces, return concrete types
- Handle errors explicitly, don't ignore them
- Use `context.Context` for cancellation and timeouts
- Prefer channels for communication, not shared memory
- Use `defer` for cleanup operations
- Write table-driven tests
- Keep functions short and focused (under 50 lines)
- Use meaningful variable names (avoid single letters except in short loops)
- Run `go fmt` before committing
- Use `golangci-lint` for comprehensive linting
- Don't use `panic` for normal error handling
- Use `sync.WaitGroup` to wait for goroutines
- Close channels from sender, not receiver

## Project Layout

```
project/
├── cmd/
│   ├── api/
│   │   └── main.go
│   └── worker/
│       └── main.go
├── internal/
│   ├── domain/
│   │   ├── user.go
│   │   └── order.go
│   ├── handlers/
│   │   └── user_handler.go
│   ├── services/
│   │   └── user_service.go
│   └── repository/
│       └── user_repository.go
├── pkg/
│   ├── httpclient/
│   │   └── client.go
│   └── validator/
│       └── validator.go
├── migrations/
├── api/
│   └── openapi.yaml
├── scripts/
├── go.mod
├── go.sum
├── Makefile
└── README.md
```

### Directory Purpose
- `cmd/` - Main applications (keep main.go minimal)
- `internal/` - Private code that shouldn't be imported by others
- `pkg/` - Public libraries that can be imported
- `api/` - API definitions (OpenAPI, gRPC proto files)

## Error Handling

```go
// Always check errors
func FetchUser(ctx context.Context, id int64) (*User, error) {
    user, err := db.QueryUser(ctx, id)
    if err != nil {
        // Wrap errors with context
        return nil, fmt.Errorf("failed to fetch user %d: %w", id, err)
    }
    return user, nil
}

// Custom errors
var (
    ErrUserNotFound = errors.New("user not found")
    ErrInvalidEmail = errors.New("invalid email address")
)

// Error wrapping (Go 1.13+)
if err != nil {
    return fmt.Errorf("processing order: %w", err)
}

// Error checking
if errors.Is(err, ErrUserNotFound) {
    // Handle specific error
}

// Custom error types
type ValidationError struct {
    Field   string
    Message string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("%s: %s", e.Field, e.Message)
}

// Type assertion for custom errors
var validErr *ValidationError
if errors.As(err, &validErr) {
    fmt.Printf("Validation failed on field: %s\n", validErr.Field)
}
```

## Context Usage

```go
import "context"

// Always pass context as first parameter
func ProcessRequest(ctx context.Context, req *Request) error {
    // Set timeout
    ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
    defer cancel()
    
    // Pass context to downstream calls
    result, err := fetchData(ctx, req.ID)
    if err != nil {
        return err
    }
    
    // Check for cancellation
    select {
    case <-ctx.Done():
        return ctx.Err()
    default:
        // Continue processing
    }
    
    return nil
}

// Context values (use sparingly)
type contextKey string

const userIDKey contextKey = "userID"

func WithUserID(ctx context.Context, userID int64) context.Context {
    return context.WithValue(ctx, userIDKey, userID)
}

func GetUserID(ctx context.Context) (int64, bool) {
    id, ok := ctx.Value(userIDKey).(int64)
    return id, ok
}
```

## Interfaces

```go
// Small, focused interfaces
type UserRepository interface {
    Get(ctx context.Context, id int64) (*User, error)
    Create(ctx context.Context, user *User) error
    Update(ctx context.Context, user *User) error
    Delete(ctx context.Context, id int64) error
}

// Accept interfaces, return structs
func NewUserService(repo UserRepository) *UserService {
    return &UserService{repo: repo}
}

// Common interfaces
type Closer interface {
    Close() error
}

type Reader interface {
    Read(p []byte) (n int, err error)
}

// Interface composition
type ReadWriteCloser interface {
    Reader
    Writer
    Closer
}
```

## Structs and Methods

```go
// Struct definition
type User struct {
    ID        int64     `json:"id" db:"id"`
    Email     string    `json:"email" db:"email"`
    Username  string    `json:"username" db:"username"`
    CreatedAt time.Time `json:"created_at" db:"created_at"`
}

// Constructor function
func NewUser(email, username string) (*User, error) {
    if email == "" {
        return nil, ErrInvalidEmail
    }
    
    return &User{
        Email:     email,
        Username:  username,
        CreatedAt: time.Now(),
    }, nil
}

// Methods with pointer receivers (can modify)
func (u *User) UpdateEmail(email string) error {
    if email == "" {
        return ErrInvalidEmail
    }
    u.Email = email
    return nil
}

// Methods with value receivers (read-only)
func (u User) IsValid() bool {
    return u.Email != "" && u.Username != ""
}

// String representation
func (u User) String() string {
    return fmt.Sprintf("User{ID: %d, Username: %s}", u.ID, u.Username)
}
```

## Goroutines and Channels

```go
// Basic goroutine
go func() {
    // Do work
}()

// Wait group for multiple goroutines
var wg sync.WaitGroup

for i := 0; i < 10; i++ {
    wg.Add(1)
    go func(id int) {
        defer wg.Done()
        process(id)
    }(i)
}

wg.Wait()

// Channels
ch := make(chan Result, 10) // Buffered channel

// Send
go func() {
    defer close(ch)
    for i := 0; i < 5; i++ {
        ch <- Result{Value: i}
    }
}()

// Receive
for result := range ch {
    fmt.Println(result.Value)
}

// Select for multiple channels
select {
case msg := <-ch1:
    handle(msg)
case msg := <-ch2:
    handle(msg)
case <-ctx.Done():
    return ctx.Err()
case <-time.After(5 * time.Second):
    return errors.New("timeout")
}

// Fan-out pattern
func fanOut(in <-chan int, n int) []<-chan int {
    outs := make([]<-chan int, n)
    for i := 0; i < n; i++ {
        outs[i] = worker(in)
    }
    return outs
}

func worker(in <-chan int) <-chan int {
    out := make(chan int)
    go func() {
        defer close(out)
        for val := range in {
            out <- process(val)
        }
    }()
    return out
}
```

## Defer, Panic, Recover

```go
// Defer for cleanup
func ProcessFile(path string) error {
    f, err := os.Open(path)
    if err != nil {
        return err
    }
    defer f.Close() // Always called, even on error
    
    // Multiple defers execute in LIFO order
    defer log.Println("Done processing")
    defer metric.RecordDuration(time.Now())
    
    return process(f)
}

// Recover from panic (use sparingly)
func SafeHandler(w http.ResponseWriter, r *http.Request) {
    defer func() {
        if err := recover(); err != nil {
            log.Printf("Panic recovered: %v", err)
            http.Error(w, "Internal Server Error", 500)
        }
    }()
    
    handler(w, r)
}

// Defer with named return values
func ReadFile(path string) (content []byte, err error) {
    f, err := os.Open(path)
    if err != nil {
        return nil, err
    }
    defer func() {
        if cerr := f.Close(); cerr != nil && err == nil {
            err = cerr
        }
    }()
    
    return io.ReadAll(f)
}
```

## Testing

```go
// Basic test
func TestUserCreation(t *testing.T) {
    user, err := NewUser("test@example.com", "testuser")
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
    
    if user.Email != "test@example.com" {
        t.Errorf("expected email %s, got %s", "test@example.com", user.Email)
    }
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
        {"empty", "", true},
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
        if err != nil {
            t.Fatal(err)
        }
        if user.Username != "test" {
            t.Errorf("expected username test, got %s", user.Username)
        }
    })
    
    t.Run("Update", func(t *testing.T) {
        user := &User{Username: "old"}
        err := user.UpdateEmail("new@example.com")
        if err != nil {
            t.Fatal(err)
        }
        if user.Email != "new@example.com" {
            t.Errorf("expected new email, got %s", user.Email)
        }
    })
}

// Benchmarks
func BenchmarkCalculate(b *testing.B) {
    for i := 0; i < b.N; i++ {
        Calculate(100, 200)
    }
}

// Test helpers
func setupTestDB(t *testing.T) *sql.DB {
    db, err := sql.Open("postgres", "test_connection_string")
    if err != nil {
        t.Fatalf("failed to connect to test db: %v", err)
    }
    
    t.Cleanup(func() {
        db.Close()
    })
    
    return db
}

// Mocking with interfaces
type mockUserRepo struct {
    users map[int64]*User
}

func (m *mockUserRepo) Get(ctx context.Context, id int64) (*User, error) {
    user, ok := m.users[id]
    if !ok {
        return nil, ErrUserNotFound
    }
    return user, nil
}

func (m *mockUserRepo) Create(ctx context.Context, user *User) error {
    m.users[user.ID] = user
    return nil
}
```

## Common Patterns

### Options Pattern
```go
type ServerOptions struct {
    Port    int
    Timeout time.Duration
    Logger  Logger
}

type ServerOption func(*ServerOptions)

func WithPort(port int) ServerOption {
    return func(o *ServerOptions) {
        o.Port = port
    }
}

func WithTimeout(d time.Duration) ServerOption {
    return func(o *ServerOptions) {
        o.Timeout = d
    }
}

func WithLogger(logger Logger) ServerOption {
    return func(o *ServerOptions) {
        o.Logger = logger
    }
}

func NewServer(opts ...ServerOption) *Server {
    options := &ServerOptions{
        Port:    8080,
        Timeout: 30 * time.Second,
        Logger:  defaultLogger,
    }
    
    for _, opt := range opts {
        opt(options)
    }
    
    return &Server{options: options}
}

// Usage
server := NewServer(
    WithPort(9000),
    WithTimeout(60 * time.Second),
)
```

### Builder Pattern
```go
type QueryBuilder struct {
    table   string
    columns []string
    where   []string
    args    []interface{}
}

func (b *QueryBuilder) Select(cols ...string) *QueryBuilder {
    b.columns = cols
    return b
}

func (b *QueryBuilder) From(table string) *QueryBuilder {
    b.table = table
    return b
}

func (b *QueryBuilder) Where(condition string, args ...interface{}) *QueryBuilder {
    b.where = append(b.where, condition)
    b.args = append(b.args, args...)
    return b
}

func (b *QueryBuilder) Build() (string, []interface{}) {
    query := fmt.Sprintf("SELECT %s FROM %s", 
        strings.Join(b.columns, ", "), 
        b.table)
    
    if len(b.where) > 0 {
        query += " WHERE " + strings.Join(b.where, " AND ")
    }
    
    return query, b.args
}

// Usage
query, args := NewQueryBuilder().
    Select("id", "name", "email").
    From("users").
    Where("age > ?", 18).
    Where("active = ?", true).
    Build()
```

### Singleton Pattern
```go
var (
    instance *Database
    once     sync.Once
)

func GetDatabase() *Database {
    once.Do(func() {
        instance = &Database{
            // Initialize
        }
    })
    return instance
}
```

## Tools

```bash
# Format code
go fmt ./...

# Lint
golangci-lint run

# Test
go test ./...
go test -v ./...
go test -race ./...
go test -cover ./...
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out

# Tidy dependencies
go mod tidy

# Vendor dependencies
go mod vendor

# Build
go build -o bin/app cmd/api/main.go

# Build with flags
go build -ldflags="-s -w" -o bin/app cmd/api/main.go

# Run
go run cmd/api/main.go

# Install tools
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
```


## Anti-Patterns to Avoid

```go
// ❌ Ignoring errors
result, _ := doSomething() // BAD

// ✅ Handle errors
result, err := doSomething()
if err != nil {
    return fmt.Errorf("doing something: %w", err)
}

// ❌ Naked returns
func calculate(x int) (result int) {
    result = x * 2
    return // BAD - unclear what's being returned
}

// ✅ Explicit returns
func calculate(x int) int {
    return x * 2 // GOOD
}

// ❌ Goroutine leaks
go func() {
    // No way to stop this goroutine
    for {
        work()
    }
}()

// ✅ Use context for cancellation
go func(ctx context.Context) {
    for {
        select {
        case <-ctx.Done():
            return
        default:
            work()
        }
    }
}(ctx)

// ❌ Not closing resources
file, _ := os.Open("file.txt")
data, _ := io.ReadAll(file) // BAD - file never closed

// ✅ Use defer
file, err := os.Open("file.txt")
if err != nil {
    return err
}
defer file.Close()
data, err := io.ReadAll(file)

// ❌ Pointer to loop variable
for _, user := range users {
    go func() {
        process(user) // BAD - all goroutines use same user
    }()
}

// ✅ Pass variable explicitly
for _, user := range users {
    go func(u User) {
        process(u) // GOOD
    }(user)
}

// ❌ Empty interface abuse
func process(data interface{}) // BAD - loses type safety

// ✅ Use generics or specific types
func process[T any](data T) // GOOD (Go 1.18+)
func process(data *User)     // GOOD (specific type)
```
