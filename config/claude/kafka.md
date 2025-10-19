# Kafka Guidelines

## Best Practices Summary

### DO
- Version your message schemas
- Use correlation IDs for tracing
- Implement idempotent consumers
- Monitor consumer lag
- Use dead letter queues
- Set appropriate retention policies
- Use compression
- Batch messages for throughput
- Partition strategically
- Test with realistic loads

### DON'T
- Use Kafka as a database
- Create too many partitions (overhead)
- Ignore consumer lag
- Auto-commit without processing
- Send large messages (> 1MB)
- Use null keys when ordering matters
- Forget to handle rebalancing
- Skip monitoring and alerting
- Use synchronous processing for high throughput
- Ignore failed messages

## Topic Design

### Naming Conventions
Use hierarchical, dot-separated naming:
```
<domain>.<entity>.<event-type>

Examples:
- orders.payment.completed
- users.profile.updated
- inventory.stock.depleted
- notifications.email.sent
- analytics.user.clicked
```

### Topic Configuration

```bash
# Create topic with proper configuration
kafka-topics --create \
  --topic orders.payment.completed \
  --bootstrap-server localhost:9092 \
  --partitions 6 \
  --replication-factor 3 \
  --config retention.ms=604800000 \
  --config cleanup.policy=delete \
  --config compression.type=snappy

# List topics
kafka-topics --list --bootstrap-server localhost:9092

# Describe topic
kafka-topics --describe \
  --topic orders.payment.completed \
  --bootstrap-server localhost:9092

# Delete topic
kafka-topics --delete \
  --topic old.topic \
  --bootstrap-server localhost:9092
```

### Partition Strategy

**Number of Partitions**:
- Start with: `max(num_producers, num_consumers)`
- Consider: target throughput / single partition throughput (~10MB/s)
- More partitions = more parallelism but more overhead
- Typical range: 6-12 partitions for moderate load
- Can't easily decrease partitions later (plan ahead)

**Replication Factor**:
- Development: 1
- Production: 3 (minimum 2)
- Critical data: 3+

**Key Selection**:
Choose keys that distribute load evenly:
- User ID, Order ID, Session ID
- Ensures related messages go to same partition (ordering)
- Null key = round-robin distribution

```python
# Good - even distribution
producer.send('orders.created', key=str(order_id), value=order_data)

# Bad - hot partition
producer.send('orders.created', key='all', value=order_data)
```

### Retention Policies

```bash
# Time-based retention (7 days)
--config retention.ms=604800000

# Size-based retention (1GB per partition)
--config retention.bytes=1073741824

# Compact topics (keep latest value per key)
--config cleanup.policy=compact

# Both delete and compact
--config cleanup.policy=compact,delete
```

## Message Design

### Message Structure

```json
{
  "event_id": "550e8400-e29b-41d4-a716-446655440000",
  "event_type": "order.created",
  "event_version": "1.0",
  "timestamp": "2024-10-19T10:30:00Z",
  "source": "order-service",
  "data": {
    "order_id": 12345,
    "user_id": 67890,
    "total_amount": 99.99,
    "currency": "USD",
    "items": [
      {
        "product_id": 111,
        "quantity": 2,
        "price": 49.99
      }
    ]
  },
  "metadata": {
    "correlation_id": "abc-123",
    "causation_id": "def-456",
    "trace_id": "trace-789"
  }
}
```

### Message Best Practices

- **Include metadata**: event_id, timestamp, version, source
- **Use UUIDs** for event IDs
- **Version your events** for schema evolution
- **Include correlation/trace IDs** for debugging
- **Keep messages small** (< 1MB, ideally < 100KB)
- **Use schema registry** (Avro, Protobuf, JSON Schema)
- **Make events immutable** - never modify published events

## Producers

### Python Producer

```python
from kafka import KafkaProducer
from kafka.errors import KafkaError
import json
import uuid
from datetime import datetime

class EventProducer:
    def __init__(self, bootstrap_servers=['localhost:9092']):
        self.producer = KafkaProducer(
            bootstrap_servers=bootstrap_servers,
            value_serializer=lambda v: json.dumps(v).encode('utf-8'),
            key_serializer=lambda k: k.encode('utf-8') if k else None,
            # Reliability settings
            acks='all',  # Wait for all replicas
            retries=3,
            max_in_flight_requests_per_connection=1,  # Ensure ordering
            # Performance settings
            compression_type='snappy',
            batch_size=16384,
            linger_ms=10,
        )
    
    def send_event(self, topic, event_type, data, key=None):
        """Send an event with proper structure."""
        message = {
            'event_id': str(uuid.uuid4()),
            'event_type': event_type,
            'event_version': '1.0',
            'timestamp': datetime.utcnow().isoformat() + 'Z',
            'source': 'my-service',
            'data': data
        }
        
        try:
            future = self.producer.send(
                topic,
                value=message,
                key=key
            )
            
            # Block for 'synchronous' send
            record_metadata = future.get(timeout=10)
            
            print(f"Sent to {record_metadata.topic} "
                  f"partition {record_metadata.partition} "
                  f"offset {record_metadata.offset}")
            
            return record_metadata
            
        except KafkaError as e:
            print(f"Failed to send message: {e}")
            raise
    
    def send_async(self, topic, event_type, data, key=None, callback=None):
        """Send event asynchronously with callback."""
        message = self._create_message(event_type, data)
        
        def on_send_success(record_metadata):
            print(f"Message sent to {record_metadata.topic}")
            if callback:
                callback(record_metadata, None)
        
        def on_send_error(exc):
            print(f"Failed to send message: {exc}")
            if callback:
                callback(None, exc)
        
        self.producer.send(
            topic,
            value=message,
            key=key
        ).add_callback(on_send_success).add_errback(on_send_error)
    
    def close(self):
        """Flush and close producer."""
        self.producer.flush()
        self.producer.close()

# Usage
producer = EventProducer()

# Synchronous send
producer.send_event(
    topic='orders.created',
    event_type='order.created',
    data={'order_id': 123, 'amount': 99.99},
    key=str(123)
)

# Async send with callback
producer.send_async(
    topic='orders.created',
    event_type='order.created',
    data={'order_id': 124, 'amount': 149.99},
    key=str(124),
    callback=lambda meta, err: print(f"Done: {meta or err}")
)

producer.close()
```

### Go Producer

```go
package kafka

import (
    "context"
    "encoding/json"
    "fmt"
    "time"
    
    "github.com/google/uuid"
    "github.com/segmentio/kafka-go"
)

type Event struct {
    EventID      string                 `json:"event_id"`
    EventType    string                 `json:"event_type"`
    EventVersion string                 `json:"event_version"`
    Timestamp    string                 `json:"timestamp"`
    Source       string                 `json:"source"`
    Data         map[string]interface{} `json:"data"`
}

type Producer struct {
    writer *kafka.Writer
}

func NewProducer(brokers []string) *Producer {
    return &Producer{
        writer: &kafka.Writer{
            Addr:         kafka.TCP(brokers...),
            Balancer:     &kafka.LeastBytes{},
            Compression:  kafka.Snappy,
            RequiredAcks: kafka.RequireAll,
            MaxAttempts:  3,
            BatchSize:    100,
            BatchTimeout: 10 * time.Millisecond,
        },
    }
}

func (p *Producer) SendEvent(ctx context.Context, topic, eventType string, data map[string]interface{}, key string) error {
    event := Event{
        EventID:      uuid.New().String(),
        EventType:    eventType,
        EventVersion: "1.0",
        Timestamp:    time.Now().UTC().Format(time.RFC3339),
        Source:       "my-service",
        Data:         data,
    }
    
    value, err := json.Marshal(event)
    if err != nil {
        return fmt.Errorf("failed to marshal event: %w", err)
    }
    
    msg := kafka.Message{
        Topic: topic,
        Key:   []byte(key),
        Value: value,
    }
    
    err = p.writer.WriteMessages(ctx, msg)
    if err != nil {
        return fmt.Errorf("failed to write message: %w", err)
    }
    
    return nil
}

func (p *Producer) Close() error {
    return p.writer.Close()
}

// Usage
producer := NewProducer([]string{"localhost:9092"})
defer producer.Close()

err := producer.SendEvent(
    context.Background(),
    "orders.created",
    "order.created",
    map[string]interface{}{
        "order_id": 123,
        "amount":   99.99,
    },
    "123",
)
```

### Producer Best Practices

- **Use `acks=all`** for critical data
- **Enable idempotence** to prevent duplicates
- **Batch messages** for better throughput
- **Use compression** (snappy or lz4)
- **Handle errors properly** - retry or DLQ
- **Set appropriate timeouts**
- **Flush before shutdown**
- **Monitor send metrics**

## Consumers

### Python Consumer

```python
from kafka import KafkaConsumer, TopicPartition
from kafka.errors import KafkaError
import json
import logging

logger = logging.getLogger(__name__)

class EventConsumer:
    def __init__(
        self,
        topics,
        group_id,
        bootstrap_servers=['localhost:9092']
    ):
        self.consumer = KafkaConsumer(
            *topics,
            bootstrap_servers=bootstrap_servers,
            group_id=group_id,
            # Deserialization
            value_deserializer=lambda m: json.loads(m.decode('utf-8')),
            key_deserializer=lambda k: k.decode('utf-8') if k else None,
            # Consumer settings
            auto_offset_reset='earliest',  # or 'latest'
            enable_auto_commit=False,  # Manual commit for control
            max_poll_records=500,
            max_poll_interval_ms=300000,  # 5 minutes
            session_timeout_ms=10000,
        )
    
    def process_messages(self, handler):
        """Process messages with manual offset commit."""
        try:
            for message in self.consumer:
                try:
                    # Log message metadata
                    logger.info(
                        f"Received message: topic={message.topic}, "
                        f"partition={message.partition}, "
                        f"offset={message.offset}"
                    )
                    
                    # Process message
                    handler(message.value)
                    
                    # Commit offset after successful processing
                    self.consumer.commit()
                    
                except Exception as e:
                    logger.error(f"Error processing message: {e}")
                    # Decide: skip, retry, or send to DLQ
                    self.send_to_dlq(message)
                    self.consumer.commit()
                    
        except KeyboardInterrupt:
            logger.info("Shutting down consumer...")
        finally:
            self.consumer.close()
    
    def send_to_dlq(self, message):
        """Send failed message to dead letter queue."""
        # Implementation to send to DLQ topic
        pass
    
    def seek_to_beginning(self):
        """Reset consumer to beginning of partitions."""
        self.consumer.poll(0)  # Ensure assignment
        self.consumer.seek_to_beginning()
    
    def seek_to_timestamp(self, timestamp_ms):
        """Seek to specific timestamp."""
        partitions = self.consumer.assignment()
        timestamps = {p: timestamp_ms for p in partitions}
        offsets = self.consumer.offsets_for_times(timestamps)
        
        for partition, offset_and_timestamp in offsets.items():
            if offset_and_timestamp:
                self.consumer.seek(partition, offset_and_timestamp.offset)

# Usage
def handle_order_event(event):
    print(f"Processing order: {event['data']['order_id']}")
    # Business logic here

consumer = EventConsumer(
    topics=['orders.created', 'orders.updated'],
    group_id='order-processor'
)

consumer.process_messages(handle_order_event)
```

### Go Consumer

```go
package kafka

import (
    "context"
    "encoding/json"
    "fmt"
    "log"
    "time"
    
    "github.com/segmentio/kafka-go"
)

type Consumer struct {
    reader *kafka.Reader
}

func NewConsumer(brokers []string, groupID string, topics []string) *Consumer {
    return &Consumer{
        reader: kafka.NewReader(kafka.ReaderConfig{
            Brokers:        brokers,
            GroupID:        groupID,
            GroupTopics:    topics,
            MinBytes:       10e3, // 10KB
            MaxBytes:       10e6, // 10MB
            MaxWait:        1 * time.Second,
            CommitInterval: 0, // Manual commit
            StartOffset:    kafka.FirstOffset,
        }),
    }
}

type MessageHandler func(context.Context, Event) error

func (c *Consumer) Consume(ctx context.Context, handler MessageHandler) error {
    for {
        msg, err := c.reader.FetchMessage(ctx)
        if err != nil {
            if err == context.Canceled {
                return nil
            }
            log.Printf("Error fetching message: %v", err)
            continue
        }
        
        log.Printf("Received message: topic=%s partition=%d offset=%d",
            msg.Topic, msg.Partition, msg.Offset)
        
        var event Event
        if err := json.Unmarshal(msg.Value, &event); err != nil {
            log.Printf("Error unmarshaling message: %v", err)
            // Send to DLQ or skip
            c.reader.CommitMessages(ctx, msg)
            continue
        }
        
        if err := handler(ctx, event); err != nil {
            log.Printf("Error processing message: %v", err)
            // Decide: retry, skip, or DLQ
            // For now, commit to avoid blocking
            c.reader.CommitMessages(ctx, msg)
            continue
        }
        
        // Commit after successful processing
        if err := c.reader.CommitMessages(ctx, msg); err != nil {
            log.Printf("Error committing message: %v", err)
        }
    }
}

func (c *Consumer) Close() error {
    return c.reader.Close()
}

// Usage
consumer := NewConsumer(
    []string{"localhost:9092"},
    "order-processor",
    []string{"orders.created", "orders.updated"},
)
defer consumer.Close()

handler := func(ctx context.Context, event Event) error {
    orderID := event.Data["order_id"]
    fmt.Printf("Processing order: %v\n", orderID)
    return nil
}

if err := consumer.Consume(context.Background(), handler); err != nil {
    log.Fatal(err)
}
```

### Consumer Best Practices

- **Use consumer groups** for scalability
- **Disable auto-commit** for control
- **Commit after processing** (at-least-once)
- **Handle duplicates** (idempotent processing)
- **Use appropriate `auto.offset.reset`**
- **Monitor consumer lag**
- **Implement timeout for processing**
- **Use dead letter queues** for failed messages
- **Graceful shutdown** with proper cleanup

## Message Ordering

### Guarantees

- **Within partition**: Strict ordering guaranteed
- **Across partitions**: No ordering guarantee
- **Producer**: Use same key for related messages
- **Consumer**: Single consumer per partition for ordering

```python
# Ensure ordering for user's messages
producer.send(
    'user.events',
    value=event,
    key=str(user_id)  # Same user always goes to same partition
)
```

## Error Handling and Retry

### Retry Pattern

```python
from tenacity import retry, stop_after_attempt, wait_exponential

class ResilientConsumer:
    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=4, max=10)
    )
    def process_message(self, message):
        """Process with automatic retry."""
        # Processing logic
        if should_retry(message):
            raise RetryableError("Temporary failure")
        return process(message)
    
    def handle_message(self, message):
        try:
            self.process_message(message)
            self.consumer.commit()
        except RetryableError:
            # Max retries exceeded, send to DLQ
            self.send_to_dlq(message)
            self.consumer.commit()
```

### Dead Letter Queue (DLQ)

```python
def send_to_dlq(original_message, error):
    """Send failed message to DLQ with error details."""
    dlq_message = {
        'original_topic': original_message.topic,
        'original_partition': original_message.partition,
        'original_offset': original_message.offset,
        'original_key': original_message.key,
        'original_value': original_message.value,
        'error': str(error),
        'error_timestamp': datetime.utcnow().isoformat(),
        'retry_count': original_message.headers.get('retry_count', 0)
    }
    
    dlq_producer.send(
        'dlq.processing.errors',
        value=dlq_message,
        key=original_message.key
    )
```

## Idempotent Processing

```python
class IdempotentProcessor:
    def __init__(self, db):
        self.db = db
        self.processed_events = set()  # Or use database/cache
    
    def process_event(self, event):
        event_id = event['event_id']
        
        # Check if already processed
        if self.db.is_processed(event_id):
            print(f"Event {event_id} already processed, skipping")
            return
        
        # Process event
        try:
            result = self.handle_event(event)
            
            # Mark as processed atomically with business logic
            self.db.mark_processed(event_id, result)
            
        except Exception as e:
            print(f"Failed to process event {event_id}: {e}")
            raise
```

## Monitoring and Metrics

### Key Metrics to Monitor

**Producer Metrics**:
- Message send rate
- Message send errors
- Average batch size
- Compression ratio
- Request latency

**Consumer Metrics**:
- Consumer lag (messages behind)
- Message processing rate
- Processing errors
- Rebalance frequency
- Commit latency

**Cluster Metrics**:
- Under-replicated partitions
- Offline partitions
- Leader election rate
- Disk usage
- Network throughput

### Consumer Lag Monitoring

```bash
# Check consumer lag
kafka-consumer-groups --bootstrap-server localhost:9092 \
  --describe --group order-processor

# Output shows:
# GROUP           TOPIC           PARTITION  CURRENT-OFFSET  LOG-END-OFFSET  LAG
# order-processor orders.created  0          1000           1050            50
```

```python
# Monitor lag programmatically
from kafka import KafkaAdminClient

admin = KafkaAdminClient(bootstrap_servers='localhost:9092')

def get_consumer_lag(group_id):
    """Get consumer lag for all partitions."""
    # Get consumer group offsets
    consumer_offsets = admin.list_consumer_group_offsets(group_id)
    
    # Get topic end offsets
    # Compare and calculate lag
    # Return lag metrics
```

## Schema Management

### Schema Registry (Avro)

```python
from confluent_kafka import avro
from confluent_kafka.avro import AvroProducer

# Define schema
value_schema = avro.loads('''
{
    "type": "record",
    "name": "Order",
    "fields": [
        {"name": "order_id", "type": "int"},
        {"name": "amount", "type": "double"},
        {"name": "currency", "type": "string"}
    ]
}
''')

# Producer with schema
producer = AvroProducer({
    'bootstrap.servers': 'localhost:9092',
    'schema.registry.url': 'http://localhost:8081'
}, default_value_schema=value_schema)

# Send with schema validation
producer.produce(
    topic='orders.created',
    value={'order_id': 123, 'amount': 99.99, 'currency': 'USD'}
)
```
## Common Patterns

### Event Sourcing
Store all changes as events, rebuild state by replaying

### CQRS (Command Query Responsibility Segregation)
Separate read and write models, sync via Kafka

### Change Data Capture (CDC)
Stream database changes to Kafka

### Stream Processing
Transform events in real-time (Kafka Streams, Flink)
