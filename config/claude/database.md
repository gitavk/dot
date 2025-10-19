# Database Guidelines (PostgreSQL)

PostgreSQL-specific best practices and patterns.

## Schema Design

### Naming Conventions
- Use **snake_case** for tables and columns
- Table names should be plural: `users`, `orders`, `order_items`
- Boolean columns: prefix with `is_`, `has_`, `can_`
- Timestamp columns: `created_at`, `updated_at`, `deleted_at`
- Foreign keys: `{table}_id` (e.g., `user_id`, `order_id`)

### Basic Table Structure

```sql
-- Good table design
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    
    CONSTRAINT chk_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$')
);

-- Indexes for frequently queried columns
CREATE INDEX idx_users_email ON users(email) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_username ON users(username) WHERE deleted_at IS NULL;
CREATE INDEX idx_users_created_at ON users(created_at);
CREATE INDEX idx_users_is_active ON users(is_active) WHERE is_active = TRUE;

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $ LANGUAGE plpgsql;

CREATE TRIGGER audit_users
    AFTER INSERT OR UPDATE OR DELETE ON users
    FOR EACH ROW
    EXECUTE FUNCTION audit_trigger_function();
```

## Backup and Recovery

```bash
# Backup entire database
pg_dump -U username -d dbname -F c -f backup.dump

# Backup with compression
pg_dump -U username -d dbname -F c -Z 9 -f backup.dump

# Backup specific tables
pg_dump -U username -d dbname -t users -t orders -F c -f tables_backup.dump

# Backup schema only (no data)
pg_dump -U username -d dbname --schema-only -f schema.sql

# Backup data only (no schema)
pg_dump -U username -d dbname --data-only -f data.sql

# Restore database
pg_restore -U username -d dbname -c backup.dump

# Restore specific table
pg_restore -U username -d dbname -t users backup.dump

# Continuous archiving (WAL archiving)
# In postgresql.conf:
# wal_level = replica
# archive_mode = on
# archive_command = 'cp %p /path/to/archive/%f'
```

## Best Practices

### DO
- Use appropriate data types
- Add NOT NULL constraints where appropriate
- Use FOREIGN KEY constraints for referential integrity
- Add indexes for frequently queried columns
- Use EXPLAIN ANALYZE to understand query performance
- Use transactions for multiple related operations
- Use connection pooling in applications
- Regular VACUUM and ANALYZE for maintenance
- Monitor slow queries and add indexes as needed
- Use prepared statements to prevent SQL injection
- Back up your database regularly
- Test migrations on staging before production
- Use meaningful table and column names
- Document your schema with comments
- Version control your migrations
- Monitor database size and plan for growth

### DON'T
- Use VARCHAR without length or TEXT indiscriminately
- Skip indexes on foreign keys
- Use BETWEEN for timestamp ranges (use >= and <)
- Store large files in database (use object storage)
- Use OFFSET for pagination on large datasets
- Ignore query performance until it's a problem
- Run migrations without testing
- Store passwords in plain text
- Use SELECT * in production code
- Create too many indexes (each slows writes)
- Use database as a message queue
- Store JSON when relational model is appropriate
- Ignore database logs and metrics

## Anti-Patterns to Avoid

```sql
-- ❌ Using VARCHAR without length
CREATE TABLE users (
    name VARCHAR  -- BAD
);

-- ✅ Specify length or use TEXT
CREATE TABLE users (
    name VARCHAR(255)  -- or TEXT
);

-- ❌ No indexes on foreign keys
CREATE TABLE orders (
    user_id BIGINT REFERENCES users(id)
    -- Missing index!
);

-- ✅ Always index foreign keys
CREATE TABLE orders (
    user_id BIGINT REFERENCES users(id)
);
CREATE INDEX idx_orders_user_id ON orders(user_id);

-- ❌ Using BETWEEN for timestamp ranges
WHERE created_at BETWEEN '2024-01-01' AND '2024-01-31'
-- Problem: includes '2024-01-31 00:00:00' but not rest of that day

-- ✅ Use >= and < for inclusive/exclusive ranges
WHERE created_at >= '2024-01-01' AND created_at < '2024-02-01'

-- ❌ OFFSET pagination on large datasets (slow)
SELECT * FROM users ORDER BY id LIMIT 10 OFFSET 1000000;

-- ✅ Keyset pagination (cursor-based)
SELECT * FROM users 
WHERE id > 1000000 
ORDER BY id 
LIMIT 10;

-- ❌ Storing comma-separated values
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    roles VARCHAR(255)  -- 'admin,user,editor'
);

-- ✅ Use proper many-to-many relationship
CREATE TABLE user_roles (
    user_id BIGINT REFERENCES users(id),
    role_id INTEGER REFERENCES roles(id),
    PRIMARY KEY (user_id, role_id)
);

-- ❌ Using NULL for different meanings
CREATE TABLE orders (
    status VARCHAR(50)  -- NULL could mean 'pending' or 'unknown'
);

-- ✅ Use explicit values
CREATE TABLE orders (
    status VARCHAR(50) NOT NULL DEFAULT 'pending'
);

-- ❌ Not using transactions for related operations
INSERT INTO orders (...) VALUES (...);
INSERT INTO order_items (...) VALUES (...);
-- What if second insert fails?

-- ✅ Use transactions
BEGIN;
    INSERT INTO orders (...) VALUES (...);
    INSERT INTO order_items (...) VALUES (...);
COMMIT;

-- ❌ Storing computed values that can be calculated
CREATE TABLE orders (
    subtotal DECIMAL(10,2),
    tax DECIMAL(10,2),
    total DECIMAL(10,2)  -- Can be calculated from subtotal + tax
);

-- ✅ Compute on the fly or use generated column
CREATE TABLE orders (
    subtotal DECIMAL(10,2) NOT NULL,
    tax DECIMAL(10,2) NOT NULL,
    total DECIMAL(10,2) GENERATED ALWAYS AS (subtotal + tax) STORED
);
```

## Monitoring Queries

```sql
-- Find slow queries
SELECT
    query,
    calls,
    total_exec_time,
    mean_exec_time,
    max_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;

-- Current activity
SELECT
    pid,
    usename,
    application_name,
    client_addr,
    state,
    query,
    query_start,
    state_change
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY query_start;

-- Kill slow query
SELECT pg_cancel_backend(pid);  -- Graceful
SELECT pg_terminate_backend(pid);  -- Forceful

-- Table sizes
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) AS indexes_size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Index usage statistics
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;

-- Cache hit ratio (should be > 99%)
SELECT
    sum(heap_blks_read) as heap_read,
    sum(heap_blks_hit) as heap_hit,
    sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) AS cache_hit_ratio
FROM pg_statio_user_tables;

-- Database connections
SELECT
    datname,
    count(*) AS connections
FROM pg_stat_activity
GROUP BY datname
ORDER BY connections DESC;
```

## Common Patterns

### Soft Deletes

```sql
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    username VARCHAR(50) NOT NULL,
    deleted_at TIMESTAMPTZ,
    
    CONSTRAINT uq_users_email UNIQUE (email) WHERE deleted_at IS NULL,
    CONSTRAINT uq_users_username UNIQUE (username) WHERE deleted_at IS NULL
);

-- Soft delete
UPDATE users SET deleted_at = NOW() WHERE id = 1;

-- Query active users
SELECT * FROM users WHERE deleted_at IS NULL;

-- Create view for active users
CREATE VIEW active_users AS
SELECT * FROM users WHERE deleted_at IS NULL;
```

### Audit Trail

```sql
CREATE TABLE user_history (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    email VARCHAR(255),
    username VARCHAR(50),
    operation VARCHAR(10) NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    changed_by VARCHAR(50)
);

CREATE OR REPLACE FUNCTION log_user_changes()
RETURNS TRIGGER AS $
BEGIN
    IF TG_OP = 'UPDATE' THEN
        INSERT INTO user_history (user_id, email, username, operation, changed_by)
        VALUES (NEW.id, NEW.email, NEW.username, 'UPDATE', current_user);
    END IF;
    RETURN NEW;
END;
$ LANGUAGE plpgsql;

CREATE TRIGGER user_history_trigger
    AFTER UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION log_user_changes();
```

### Optimistic Locking

```sql
CREATE TABLE products (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    stock INTEGER NOT NULL,
    version INTEGER NOT NULL DEFAULT 0
);

-- Update with version check
UPDATE products
SET 
    stock = stock - 1,
    version = version + 1
WHERE id = 123 
  AND version = 5  -- Current version
RETURNING *;

-- If no rows updated, version conflict occurred
```

### UUID Primary Keys

```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id BIGINT NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Or use gen_random_uuid() (PostgreSQL 13+)
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- ...
);
```

### Partitioning

```sql
-- Range partitioning by date
CREATE TABLE orders (
    id BIGSERIAL,
    user_id BIGINT NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
) PARTITION BY RANGE (created_at);

-- Create partitions
CREATE TABLE orders_2024_01 PARTITION OF orders
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

CREATE TABLE orders_2024_02 PARTITION OF orders
    FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');

-- List partitioning
CREATE TABLE users (
    id BIGSERIAL,
    username VARCHAR(50) NOT NULL,
    region VARCHAR(50) NOT NULL
) PARTITION BY LIST (region);

CREATE TABLE users_us PARTITION OF users
    FOR VALUES IN ('US', 'CA');

CREATE TABLE users_eu PARTITION OF users
    FOR VALUES IN ('UK', 'DE', 'FR');

-- Hash partitioning
CREATE TABLE events (
    id BIGSERIAL,
    event_type VARCHAR(50),
    data JSONB
) PARTITION BY HASH (id);

CREATE TABLE events_0 PARTITION OF events
    FOR VALUES WITH (MODULUS 4, REMAINDER 0);

CREATE TABLE events_1 PARTITION OF events
    FOR VALUES WITH (MODULUS 4, REMAINDER 1);
```

---

*Design robust, performant database schemas.*
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Comments for documentation
COMMENT ON TABLE users IS 'System users and authentication';
COMMENT ON COLUMN users.is_verified IS 'Email verification status';
```

### Relationships

```sql
-- One-to-Many: User has many orders
CREATE TABLE orders (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    order_number VARCHAR(50) NOT NULL UNIQUE,
    total_amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    CONSTRAINT fk_order_items_order_id 
        FOREIGN KEY (order_id) 
        REFERENCES orders(id) 
        ON DELETE CASCADE,
    
    CONSTRAINT fk_order_items_product_id 
        FOREIGN KEY (product_id) 
        REFERENCES products(id),
    
    CONSTRAINT chk_quantity_positive CHECK (quantity > 0),
    CONSTRAINT chk_unit_price_positive CHECK (unit_price >= 0)
);

CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);

-- Many-to-Many: Users and Roles
CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE user_roles (
    user_id BIGINT NOT NULL,
    role_id INTEGER NOT NULL,
    granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    granted_by BIGINT,
    
    PRIMARY KEY (user_id, role_id),
    
    CONSTRAINT fk_user_roles_user_id 
        FOREIGN KEY (user_id) 
        REFERENCES users(id) 
        ON DELETE CASCADE,
    
    CONSTRAINT fk_user_roles_role_id 
        FOREIGN KEY (role_id) 
        REFERENCES roles(id) 
        ON DELETE CASCADE,
    
    CONSTRAINT fk_user_roles_granted_by 
        FOREIGN KEY (granted_by) 
        REFERENCES users(id) 
        ON DELETE SET NULL
);

CREATE INDEX idx_user_roles_user_id ON user_roles(user_id);
CREATE INDEX idx_user_roles_role_id ON user_roles(role_id);
```

## Data Types

```sql
-- Choose appropriate types
CREATE TABLE products (
    id BIGSERIAL PRIMARY KEY,
    
    -- Text types
    name VARCHAR(255) NOT NULL,
    description TEXT,
    sku VARCHAR(50) UNIQUE,
    slug VARCHAR(255) UNIQUE,
    
    -- Numeric types
    price DECIMAL(10, 2) NOT NULL,  -- For money (fixed precision)
    stock_quantity INTEGER NOT NULL DEFAULT 0,
    weight_kg NUMERIC(8, 3),  -- For precise decimals
    rating NUMERIC(3, 2) CHECK (rating BETWEEN 0 AND 5),
    
    -- Boolean
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    is_featured BOOLEAN NOT NULL DEFAULT FALSE,
    
    -- Dates and times
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    published_at TIMESTAMPTZ,
    expires_at DATE,
    sale_starts_at TIMESTAMPTZ,
    sale_ends_at TIMESTAMPTZ,
    
    -- JSON (for flexible data)
    metadata JSONB DEFAULT '{}'::JSONB,
    attributes JSONB,
    
    -- Arrays
    tags TEXT[],
    image_urls TEXT[],
    
    -- UUID (for distributed systems)
    external_id UUID DEFAULT gen_random_uuid() UNIQUE,
    
    -- Enum (for fixed values)
    status product_status NOT NULL DEFAULT 'draft',
    
    -- Full-text search
    search_vector TSVECTOR,
    
    CONSTRAINT chk_price_positive CHECK (price >= 0),
    CONSTRAINT chk_stock_non_negative CHECK (stock_quantity >= 0),
    CONSTRAINT chk_sale_dates CHECK (sale_ends_at IS NULL OR sale_starts_at < sale_ends_at)
);

-- Create enum type
CREATE TYPE product_status AS ENUM ('draft', 'published', 'archived', 'discontinued');

-- Index for JSONB
CREATE INDEX idx_products_metadata ON products USING GIN(metadata);

-- Index for arrays
CREATE INDEX idx_products_tags ON products USING GIN(tags);

-- Full-text search index
CREATE INDEX idx_products_search ON products USING GIN(search_vector);

-- Trigger to update search vector
CREATE OR REPLACE FUNCTION update_product_search_vector()
RETURNS TRIGGER AS $
BEGIN
    NEW.search_vector := 
        setweight(to_tsvector('english', COALESCE(NEW.name, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(NEW.description, '')), 'B') ||
        setweight(to_tsvector('english', COALESCE(array_to_string(NEW.tags, ' '), '')), 'C');
    RETURN NEW;
END;
$ LANGUAGE plpgsql;

CREATE TRIGGER update_products_search_vector
    BEFORE INSERT OR UPDATE ON products
    FOR EACH ROW
    EXECUTE FUNCTION update_product_search_vector();
```

## Constraints

```sql
CREATE TABLE orders (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    total_amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR(50) NOT NULL,
    discount_code VARCHAR(50),
    discount_amount DECIMAL(10, 2) DEFAULT 0,
    
    -- Foreign key with actions
    CONSTRAINT fk_orders_user_id 
        FOREIGN KEY (user_id) 
        REFERENCES users(id) 
        ON DELETE RESTRICT  -- Prevent deletion if orders exist
        ON UPDATE CASCADE,  -- Update order.user_id if users.id changes
    
    -- Check constraints
    CONSTRAINT chk_total_amount_positive 
        CHECK (total_amount >= 0),
    
    CONSTRAINT chk_discount_valid 
        CHECK (discount_amount >= 0 AND discount_amount <= total_amount),
    
    CONSTRAINT chk_status_valid 
        CHECK (status IN ('pending', 'processing', 'completed', 'cancelled')),
    
    -- Unique constraints
    CONSTRAINT uq_order_reference 
        UNIQUE (order_number),
    
    -- Composite unique
    CONSTRAINT uq_user_order_number 
        UNIQUE (user_id, order_number)
);

-- Exclusion constraints (no overlapping date ranges)
CREATE TABLE bookings (
    id BIGSERIAL PRIMARY KEY,
    room_id INTEGER NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    
    CONSTRAINT chk_dates_valid 
        CHECK (start_date < end_date),
    
    EXCLUDE USING GIST (
        room_id WITH =,
        daterange(start_date, end_date) WITH &&
    )
);
```

## Indexes

```sql
-- B-tree index (default, good for equality and range queries)
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_created_at ON users(created_at DESC);

-- Partial index (only index rows that match condition)
CREATE INDEX idx_active_users ON users(email) WHERE is_active = TRUE AND deleted_at IS NULL;
CREATE INDEX idx_pending_orders ON orders(created_at) WHERE status = 'pending';

-- Composite index (for queries filtering multiple columns)
CREATE INDEX idx_orders_user_status ON orders(user_id, status);
CREATE INDEX idx_orders_status_date ON orders(status, created_at DESC);

-- Covering index (includes additional columns to avoid table lookup)
CREATE INDEX idx_orders_user_total 
    ON orders(user_id) 
    INCLUDE (total_amount, created_at);

-- Expression index (index on computed value)
CREATE INDEX idx_users_email_lower ON users(LOWER(email));
CREATE INDEX idx_users_full_name ON users((first_name || ' ' || last_name));

-- GIN index (for JSONB, arrays, full-text search)
CREATE INDEX idx_products_metadata ON products USING GIN(metadata);
CREATE INDEX idx_products_tags ON products USING GIN(tags);
CREATE INDEX idx_products_search ON products USING GIN(to_tsvector('english', name || ' ' || description));

-- GiST index (for geometric and range types)
CREATE INDEX idx_locations_point ON locations USING GIST(coordinates);

-- Hash index (only for equality comparisons, rarely used)
CREATE INDEX idx_sessions_token ON sessions USING HASH(session_token);

-- Unique index
CREATE UNIQUE INDEX idx_users_email_unique ON users(email) WHERE deleted_at IS NULL;

-- Concurrent index creation (doesn't lock table)
CREATE INDEX CONCURRENTLY idx_large_table_column ON large_table(column_name);
```

## Queries

### Basic Queries

```sql
-- Select with filtering
SELECT id, email, username
FROM users
WHERE is_active = TRUE
  AND created_at > NOW() - INTERVAL '30 days'
  AND deleted_at IS NULL
ORDER BY created_at DESC
LIMIT 10;

-- Joins
SELECT 
    u.username,
    o.id AS order_id,
    o.total_amount,
    o.status,
    o.created_at
FROM users u
INNER JOIN orders o ON u.id = o.user_id
WHERE o.status = 'completed'
  AND o.created_at > NOW() - INTERVAL '7 days'
ORDER BY o.created_at DESC;

-- Left join to find users without orders
SELECT 
    u.id,
    u.username,
    COUNT(o.id) AS order_count
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
GROUP BY u.id, u.username
HAVING COUNT(o.id) = 0;

-- Aggregations
SELECT 
    user_id,
    COUNT(*) AS order_count,
    SUM(total_amount) AS total_spent,
    AVG(total_amount) AS avg_order_value,
    MAX(created_at) AS last_order_date,
    MIN(created_at) AS first_order_date
FROM orders
WHERE status = 'completed'
  AND created_at > NOW() - INTERVAL '1 year'
GROUP BY user_id
HAVING COUNT(*) > 5
ORDER BY total_spent DESC;

-- Window functions
SELECT 
    id,
    user_id,
    total_amount,
    created_at,
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at DESC) AS order_rank,
    SUM(total_amount) OVER (PARTITION BY user_id) AS user_total_spent,
    AVG(total_amount) OVER (PARTITION BY user_id) AS user_avg_order,
    LAG(total_amount) OVER (PARTITION BY user_id ORDER BY created_at) AS previous_order_amount
FROM orders
WHERE status = 'completed';

-- Subqueries
SELECT *
FROM users
WHERE id IN (
    SELECT user_id
    FROM orders
    WHERE total_amount > 1000
    GROUP BY user_id
    HAVING COUNT(*) > 3
);

-- EXISTS (often faster than IN)
SELECT *
FROM users u
WHERE EXISTS (
    SELECT 1
    FROM orders o
    WHERE o.user_id = u.id
      AND o.status = 'completed'
);
```

### Advanced Patterns

```sql
-- Common Table Expressions (CTEs)
WITH active_users AS (
    SELECT id, email, username
    FROM users
    WHERE is_active = TRUE
      AND deleted_at IS NULL
),
recent_orders AS (
    SELECT user_id, COUNT(*) AS order_count, SUM(total_amount) AS total_spent
    FROM orders
    WHERE created_at > NOW() - INTERVAL '30 days'
      AND status = 'completed'
    GROUP BY user_id
)
SELECT 
    au.username,
    au.email,
    COALESCE(ro.order_count, 0) AS order_count,
    COALESCE(ro.total_spent, 0) AS total_spent
FROM active_users au
LEFT JOIN recent_orders ro ON au.id = ro.user_id
ORDER BY ro.total_spent DESC NULLS LAST;

-- Recursive CTE (for hierarchical data)
WITH RECURSIVE category_tree AS (
    -- Base case: root categories
    SELECT 
        id, 
        name, 
        parent_id, 
        0 AS level,
        ARRAY[id] AS path
    FROM categories
    WHERE parent_id IS NULL
    
    UNION ALL
    
    -- Recursive case: child categories
    SELECT 
        c.id, 
        c.name, 
        c.parent_id, 
        ct.level + 1,
        ct.path || c.id
    FROM categories c
    INNER JOIN category_tree ct ON c.parent_id = ct.id
    WHERE ct.level < 10  -- Prevent infinite recursion
)
SELECT 
    REPEAT('  ', level) || name AS indented_name,
    level,
    path
FROM category_tree
ORDER BY path;

-- UPSERT (INSERT ... ON CONFLICT)
INSERT INTO user_stats (user_id, login_count, last_login)
VALUES (1, 1, NOW())
ON CONFLICT (user_id)
DO UPDATE SET
    login_count = user_stats.login_count + 1,
    last_login = EXCLUDED.last_login;

-- Bulk upsert
INSERT INTO products (id, name, price, stock)
VALUES 
    (1, 'Product A', 10.00, 100),
    (2, 'Product B', 20.00, 50),
    (3, 'Product C', 30.00, 75)
ON CONFLICT (id)
DO UPDATE SET
    name = EXCLUDED.name,
    price = EXCLUDED.price,
    stock = EXCLUDED.stock,
    updated_at = NOW();

-- JSON operations
SELECT 
    id,
    metadata->>'category' AS category,
    metadata->'attributes'->>'color' AS color,
    (metadata->'price')::numeric AS price
FROM products
WHERE metadata @> '{"featured": true}'
  AND metadata ? 'tags'
  AND metadata->'price' > '99.99';

-- Array operations
SELECT *
FROM products
WHERE 'electronics' = ANY(tags)
  AND array_length(tags, 1) > 2
  AND tags && ARRAY['sale', 'clearance'];  -- Array overlap

-- Full-text search
SELECT 
    id,
    name,
    ts_rank(search_vector, query) AS rank
FROM products, 
     to_tsquery('english', 'laptop & gaming') AS query
WHERE search_vector @@ query
ORDER BY rank DESC;

-- Date/time operations
SELECT 
    DATE_TRUNC('day', created_at) AS day,
    COUNT(*) AS orders_per_day
FROM orders
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY DATE_TRUNC('day', created_at)
ORDER BY day;

-- Generate series for date ranges
SELECT 
    date::DATE AS day,
    COALESCE(COUNT(o.id), 0) AS order_count
FROM generate_series(
    NOW() - INTERVAL '30 days',
    NOW(),
    '1 day'::INTERVAL
) AS date
LEFT JOIN orders o ON DATE_TRUNC('day', o.created_at) = date
GROUP BY day
ORDER BY day;
```

## Transactions

```sql
-- Basic transaction
BEGIN;
    INSERT INTO users (email, username) 
    VALUES ('user@example.com', 'user123');
    
    INSERT INTO user_profiles (user_id, bio) 
    VALUES (lastval(), 'User bio');
COMMIT;

-- Transaction with error handling (in application code)
-- Python example
try:
    cursor.execute("BEGIN")
    cursor.execute("INSERT INTO orders (...) VALUES (...)")
    cursor.execute("UPDATE inventory SET stock = stock - 1 WHERE id = %s", (product_id,))
    cursor.execute("COMMIT")
except Exception as e:
    cursor.execute("ROLLBACK")
    raise

-- Isolation levels
BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    SELECT * FROM accounts WHERE id = 1 FOR UPDATE;
    UPDATE accounts SET balance = balance - 100 WHERE id = 1;
    UPDATE accounts SET balance = balance + 100 WHERE id = 2;
COMMIT;

-- Savepoints
BEGIN;
    INSERT INTO orders (user_id, total_amount) VALUES (1, 100.00);
    SAVEPOINT order_created;
    
    INSERT INTO order_items (order_id, product_id, quantity) 
    VALUES (lastval(), 101, 2);
    
    -- If this fails, we can rollback to savepoint
    SAVEPOINT items_added;
    
    UPDATE inventory SET stock = stock - 2 WHERE product_id = 101;
    
    -- Oops, error occurred
    ROLLBACK TO SAVEPOINT items_added;
    
    -- Continue with transaction
COMMIT;

-- Advisory locks (for application-level locking)
-- Lock for a specific resource
SELECT pg_advisory_lock(12345);
-- Do work
SELECT pg_advisory_unlock(12345);

-- Try lock (non-blocking)
SELECT pg_try_advisory_lock(12345);
```

## Migrations

### Migration File Structure

```
migrations/
├── 001_create_users_table.up.sql
├── 001_create_users_table.down.sql
├── 002_create_orders_table.up.sql
├── 002_create_orders_table.down.sql
├── 003_add_user_email_index.up.sql
├── 003_add_user_email_index.down.sql
├── 004_add_user_status_column.up.sql
└── 004_add_user_status_column.down.sql
```

### Migration Examples

```sql
-- 001_create_users_table.up.sql
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);

-- 001_create_users_table.down.sql
DROP TABLE IF EXISTS users CASCADE;

-- 002_add_user_status.up.sql
ALTER TABLE users 
ADD COLUMN status VARCHAR(50) NOT NULL DEFAULT 'active';

CREATE INDEX idx_users_status ON users(status);

-- Add constraint
ALTER TABLE users 
ADD CONSTRAINT chk_user_status 
CHECK (status IN ('active', 'inactive', 'banned', 'deleted'));

-- 002_add_user_status.down.sql
DROP INDEX IF EXISTS idx_users_status;
ALTER TABLE users DROP CONSTRAINT IF EXISTS chk_user_status;
ALTER TABLE users DROP COLUMN IF EXISTS status;

-- 003_add_user_metadata.up.sql
ALTER TABLE users ADD COLUMN metadata JSONB DEFAULT '{}'::JSONB;
CREATE INDEX idx_users_metadata ON users USING GIN(metadata);

-- 003_add_user_metadata.down.sql
DROP INDEX IF EXISTS idx_users_metadata;
ALTER TABLE users DROP COLUMN IF EXISTS metadata;

-- 004_data_migration.up.sql
-- Migrate data from old format to new format
UPDATE products
SET metadata = jsonb_build_object(
    'old_category', category,
    'old_subcategory', subcategory
)
WHERE category IS NOT NULL;

-- 004_data_migration.down.sql
-- Reverse data migration if possible
UPDATE products
SET 
    category = metadata->>'old_category',
    subcategory = metadata->>'old_subcategory'
WHERE metadata ? 'old_category';
```

### Migration Best Practices

- Always write both UP and DOWN migrations
- Test migrations on a copy of production data
- Never modify existing migrations after deployment
- Use transactions for migrations when possible
- For large tables, consider:
  - Adding columns with no default (then backfill)
  - Creating indexes concurrently
  - Breaking migrations into smaller steps
- Back up before running migrations
- Have a rollback plan

## Performance

### Query Optimization

```sql
-- Use EXPLAIN ANALYZE to understand query performance
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT u.username, COUNT(o.id) AS order_count
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
WHERE u.created_at > '2024-01-01'
GROUP BY u.id, u.username
HAVING COUNT(o.id) > 5;

-- Avoid SELECT *
-- Bad
SELECT * FROM users WHERE id = 1;

-- Good (specify needed columns)
SELECT id, email, username FROM users WHERE id = 1;

-- Use appropriate JOINs
-- INNER JOIN when you need matching rows
-- LEFT JOIN when you want all rows from left table
-- Avoid unnecessary JOINs

-- Use indexes for WHERE, JOIN, ORDER BY columns
CREATE INDEX idx_orders_user_created ON orders(user_id, created_at DESC);

SELECT * FROM orders 
WHERE user_id = 123 
ORDER BY created_at DESC 
LIMIT 10;

-- Use LIMIT for large result sets
SELECT * FROM large_table 
WHERE condition 
ORDER BY created_at DESC 
LIMIT 100;

-- Avoid functions on indexed columns
-- Bad (can't use index)
WHERE LOWER(email) = 'test@example.com'

-- Good (can use expression index or search in lowercase)
WHERE email = 'test@example.com'

-- Or create expression index
CREATE INDEX idx_users_email_lower ON users(LOWER(email));
```

### N+1 Query Problem

```sql
-- Bad: N+1 queries (one for users, then one per user for orders)
-- SELECT * FROM users;
-- foreach user:
--     SELECT * FROM orders WHERE user_id = ?

-- Good: Single query with JOIN
SELECT 
    u.id,
    u.username,
    json_agg(json_build_object(
        'id', o.id,
        'total', o.total_amount,
        'created_at', o.created_at
    )) AS orders
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
GROUP BY u.id, u.username;
```

### Connection Pooling

```python
# Python with psycopg2
from psycopg2 import pool

connection_pool = pool.SimpleConnectionPool(
    minconn=5,
    maxconn=20,
    host='localhost',
    database='mydb',
    user='user',
    password='password'
)

# Get connection from pool
conn = connection_pool.getconn()
try:
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM users")
    results = cursor.fetchall()
finally:
    # Return connection to pool
    connection_pool.putconn(conn)
```

```go
// Go with pgx
import "github.com/jackc/pgx/v5/pgxpool"

pool, err := pgxpool.New(context.Background(), 
    "postgres://user:pass@localhost:5432/db?pool_max_conns=20")
if err != nil {
    log.Fatal(err)
}
defer pool.Close()

// Use connection from pool
rows, err := pool.Query(context.Background(), "SELECT * FROM users")
```

### Maintenance

```sql
-- VACUUM to reclaim storage and update statistics
VACUUM ANALYZE users;

-- VACUUM FULL (locks table, use carefully)
VACUUM FULL users;

-- Auto-vacuum configuration (postgresql.conf)
-- autovacuum = on
-- autovacuum_analyze_threshold = 50
-- autovacuum_vacuum_threshold = 50
-- autovacuum_vacuum_scale_factor = 0.2

-- Analyze tables for query planner
ANALYZE users;
ANALYZE;  -- Analyze all tables

-- Reindex if needed
REINDEX TABLE users;
REINDEX INDEX idx_users_email;

-- Reindex concurrently (doesn't lock table)
REINDEX INDEX CONCURRENTLY idx_users_email;

-- Check for bloat
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) AS external_size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Find unused indexes
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
  AND indexrelid NOT IN (
      SELECT conindid
      FROM pg_constraint
  )
ORDER BY pg_relation_size(indexrelid) DESC;
```

## Security

```sql
-- Use parameterized queries (prevent SQL injection)
-- Python example
cursor.execute(
    "SELECT * FROM users WHERE email = %s AND status = %s",
    (email, status)
)

-- Never do this:
-- cursor.execute(f"SELECT * FROM users WHERE email = '{email}'")  # VULNERABLE!

-- Create read-only user
CREATE ROLE readonly WITH LOGIN PASSWORD 'secure_password';
GRANT CONNECT ON DATABASE mydb TO readonly;
GRANT USAGE ON SCHEMA public TO readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO readonly;

-- Create application user with limited permissions
CREATE ROLE app_user WITH LOGIN PASSWORD 'secure_password';
GRANT CONNECT ON DATABASE mydb TO app_user;
GRANT USAGE ON SCHEMA public TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_user;

-- Row-level security
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_documents ON documents
    FOR ALL
    TO app_user
    USING (user_id = current_setting('app.current_user_id')::BIGINT);

CREATE POLICY admin_all_documents ON documents
    FOR ALL
    TO admin_user
    USING (true);

-- Set application context
SET app.current_user_id = 123;

-- Revoke permissions
REVOKE ALL ON TABLE sensitive_data FROM app_user;

-- Audit logging
CREATE TABLE audit_log (
    id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    operation VARCHAR(10) NOT NULL,
    user_name VARCHAR(50) NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    old_data JSONB,
    new_data JSONB
);

-- Audit trigger
CREATE OR REPLACE FUNCTION audit_trigger_function()
RETURNS TRIGGER AS $
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log (table_name, operation, user_name, old_data)
        VALUES (TG_TABLE_NAME, TG_OP, current_user, row_to_json(OLD));
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log (table_name, operation, user_name, old_data, new_data)
        VALUES (TG_TABLE_NAME, TG_OP, current_user, row_to_json(OLD), row_to_json(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log (table_name, operation, user_name, new_data)
        VALUES (TG_TABLE_NAME, TG_OP, current_user, row_to_json(NEW));
        RETURN NEW;
    END IF;
END;
$_orders_user_id 
        FOREIGN KEY (user_id) 
        REFERENCES users(id) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE,
    
    CONSTRAINT chk_total_amount_positive 
        CHECK (total_amount >= 0),
    
    CONSTRAINT chk_status_valid 
        CHECK (status IN ('pending', 'processing', 'completed', 'cancelled', 'refunded'))
);

CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created_at ON orders(created_at DESC);

-- One-to-Many: Order has many items
CREATE TABLE order_items (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10, 2) NOT NULL,
    total_price DECIMAL(10, 2) NOT NULL,
    
    CONSTRAINT fk_order_items_order_id 
        FOREIGN KEY (order_id) 
        REFERENCES orders(id) 
        ON DELETE CASCADE,
    
    CONSTRAINT fk