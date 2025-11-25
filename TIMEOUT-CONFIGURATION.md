# Timeout Configuration

## Current Timeout Settings

### App1 (Load Generator) - Client Side

| Setting | Default | Configurable Via | Description |
|---------|---------|------------------|-------------|
| **Connection Timeout** | 5000ms (5s) | `CONNECTION_TIMEOUT_MS` | Time to establish connection to app2 |
| **Read Timeout** | 30000ms (30s) | `READ_TIMEOUT_MS` | Time to wait for response from app2 |

**Configuration:**
```yaml
# In app1-configmap.yaml
CONNECTION_TIMEOUT_MS: "5000"   # 5 seconds
READ_TIMEOUT_MS: "30000"        # 30 seconds
```

### App2 (Echo Server) - Server Side

| Setting | Default | Configurable Via | Description |
|---------|---------|------------------|-------------|
| **Connection Timeout** | 20000ms (20s) | `server.tomcat.connection-timeout` | Time server waits for client connection |
| **Keep-Alive Timeout** | 20000ms (20s) | `server.tomcat.keep-alive-timeout` | Time to keep connection alive |

**Configuration:**
```properties
# In application.properties
server.tomcat.connection-timeout=20000
server.tomcat.keep-alive-timeout=20000
```

### Gateway (BackendConfig)

| Setting | Value | Description |
|---------|-------|-------------|
| **Backend Timeout** | 300s (5 min) | Gateway timeout for backend requests |
| **Health Check Timeout** | 5s | Gateway health check timeout |
| **Connection Draining** | 60s | Time to drain connections during shutdown |

**Configuration:**
```yaml
# In app2-backend-config.yaml
timeoutSec: 300
healthCheck:
  timeoutSec: 5
```

## Timeout Flow

```
app1 (client)
  ├─ Connection Timeout: 5s (establish connection)
  └─ Read Timeout: 30s (wait for response)
      │
      ▼
Gateway
  └─ Backend Timeout: 300s (5 min)
      │
      ▼
app2 (server)
  ├─ Connection Timeout: 20s (accept connection)
  └─ Keep-Alive Timeout: 20s (maintain connection)
```

## Adjusting Timeouts

### Increase App1 Read Timeout

If app2 takes longer to respond, increase read timeout:

```bash
kubectl patch configmap app1-config -n nettest --type merge -p '{"data":{"READ_TIMEOUT_MS":"60000"}}'
kubectl rollout restart deployment/app1 -n nettest
```

### Increase App2 Connection Timeout

If handling many concurrent connections:

```bash
# Update application.properties and rebuild image
# Or set via environment variable in deployment
```

### Adjust Gateway Backend Timeout

```bash
kubectl patch backendconfig app2-backend-config -n nettest --type merge -p '{"spec":{"timeoutSec":600}}'
```

## Common Timeout Scenarios

### Scenario 1: Connection Timeout
**Error:** `java.net.SocketTimeoutException: connect timed out`
**Cause:** Cannot establish connection within 5 seconds
**Fix:** Increase `CONNECTION_TIMEOUT_MS` or check network connectivity

### Scenario 2: Read Timeout
**Error:** `java.net.SocketTimeoutException: Read timed out`
**Cause:** app2 takes longer than 30 seconds to respond
**Fix:** Increase `READ_TIMEOUT_MS` or reduce `RESPONSE_DELAY_MS` in app2

### Scenario 3: Gateway Timeout
**Error:** `504 Gateway Timeout`
**Cause:** Backend takes longer than 300 seconds
**Fix:** Increase `timeoutSec` in BackendConfig or optimize app2 response time

## Recommended Settings

### For High Load Testing
```yaml
# app1-configmap.yaml
CONNECTION_TIMEOUT_MS: "10000"   # 10s
READ_TIMEOUT_MS: "60000"         # 60s
```

### For Low Latency
```yaml
# app1-configmap.yaml
CONNECTION_TIMEOUT_MS: "2000"    # 2s
READ_TIMEOUT_MS: "10000"         # 10s

# app2-configmap.yaml
RESPONSE_DELAY_MS: "100"         # 100ms
```

### For High Latency/Network Issues
```yaml
# app1-configmap.yaml
CONNECTION_TIMEOUT_MS: "30000"   # 30s
READ_TIMEOUT_MS: "120000"        # 120s (2 min)
```

## Monitoring Timeouts

Check logs for timeout errors:
```bash
# App1 timeout errors
kubectl logs -l app=app1 -n nettest | grep -i "timeout\|timed out"

# App2 connection issues
kubectl logs -l app=app2 -n nettest | grep -i "timeout\|connection"
```

## Current Configuration Summary

- **App1 Connection Timeout:** 5 seconds
- **App1 Read Timeout:** 30 seconds
- **App2 Connection Timeout:** 20 seconds
- **App2 Keep-Alive Timeout:** 20 seconds
- **Gateway Backend Timeout:** 300 seconds (5 minutes)
- **Gateway Health Check Timeout:** 5 seconds

