# M.1: Platform Callback Security Implementation

## Overview

This document describes the implementation of signature/timestamp/nonce validation for platform callbacks (Task M.1).

## Security Model

### Threat Model

Platform callbacks are vulnerable to:
1. **Replay Attacks**: Attacker intercepts and replays valid callbacks
2. **Tampering**: Attacker modifies callback data
3. **Spoofing**: Attacker sends fake callbacks pretending to be a platform
4. **Timing Attacks**: Attacker uses old callbacks after they should expire

### Defense Mechanisms

1. **HMAC-SHA256 Signature**: Ensures authenticity and integrity
2. **Timestamp Validation**: Prevents replay of old callbacks
3. **Nonce Tracking**: Prevents replay of recent callbacks
4. **Audit Logging**: Records all validation attempts for security monitoring

## Architecture

### Database Schema

#### `app_publish_callback_nonce`
Tracks used nonces to prevent replay attacks.

```sql
CREATE TABLE app_publish_callback_nonce (
  id UUID PRIMARY KEY,
  nonce TEXT NOT NULL,
  platform_id TEXT NOT NULL,
  callback_timestamp TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  UNIQUE (nonce, platform_id)
);
```

**Indexes:**
- `(nonce, platform_id, expires_at)` for fast lookup
- `(expires_at)` for cleanup of expired nonces

#### `app_publish_platform_secret`
Stores platform-specific HMAC secrets.

```sql
CREATE TABLE app_publish_platform_secret (
  id UUID PRIMARY KEY,
  platform_id TEXT NOT NULL UNIQUE,
  secret_key TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  rotated_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL
);
```

**Key Rotation Support:**
- `is_active` flag allows deactivating old secrets
- `rotated_at` tracks when rotation occurred
- Multiple secrets per platform can coexist during rotation

#### `app_publish_callback_audit`
Security audit log for all callback validation attempts.

```sql
CREATE TABLE app_publish_callback_audit (
  id UUID PRIMARY KEY,
  platform_id TEXT NOT NULL,
  callback_id TEXT,
  validation_status TEXT NOT NULL,
  request_headers JSONB NOT NULL,
  body_hash TEXT,
  error_details TEXT,
  source_ip TEXT,
  created_at TIMESTAMPTZ NOT NULL
);
```

**Validation Statuses:**
- `valid`: Callback passed all checks
- `invalid_signature`: HMAC verification failed
- `invalid_timestamp`: Timestamp out of acceptable window
- `replay_attack`: Nonce already used
- `missing_headers`: Required headers not present
- `secret_not_found`: No active secret for platform

### Validation Flow

```
1. Extract Headers
   ├─ X-Platform-Signature (required)
   ├─ X-Platform-Timestamp (required)
   ├─ X-Platform-Nonce (required)
   └─ X-Callback-Id (optional)

2. Validate Timestamp
   ├─ Parse Unix timestamp
   ├─ Check not too old (default: 5 minutes)
   └─ Check not in future (allow 30s clock skew)

3. Validate Nonce
   ├─ Check format (1-256 chars)
   ├─ Check not used before
   └─ Platform-scoped (same nonce OK for different platforms)

4. Verify Signature
   ├─ Fetch platform secret from database
   ├─ Compute HMAC-SHA256(secret, timestamp + "." + body)
   ├─ Compare with provided signature (constant-time)
   └─ Reject if mismatch

5. Record Nonce
   ├─ Insert into nonce table
   ├─ Set expiry = timestamp + tolerance
   └─ Prevent future replay

6. Audit Result
   ├─ Log validation status
   ├─ Sanitize sensitive headers
   └─ Record body hash for forensics
```

## API Endpoints

### POST `/api/v1/callbacks/publish/:platform_id`

Receives platform callbacks with security validation.

**Path Parameters:**
- `platform_id`: Platform identifier (e.g., `douyin`, `tiktok`)

**Required Headers:**
```
X-Platform-Signature: <hex-encoded-hmac-sha256>
X-Platform-Timestamp: <unix-timestamp-seconds>
X-Platform-Nonce: <unique-nonce>
X-Callback-Id: <optional-callback-id>
```

**Request Body:**
```json
{
  "callback_id": "cb_123",
  "job_id": "550e8400-e29b-41d4-a716-446655440000",
  "draft_id": "550e8400-e29b-41d4-a716-446655440001",
  "event_type": "publish_success",
  "data": {
    "external_video_id": "platform_vid_123",
    "published_url": "https://platform.com/video/123"
  },
  "error": null
}
```

**Event Types:**
- `publish_success`: Video published successfully
- `publish_failed`: Publishing failed
- `publish_processing`: Platform is processing the video

**Response (200 OK):**
```json
{
  "received": true,
  "callback_id": "cb_123",
  "processed_at": "2024-01-15T10:30:00Z"
}
```

**Error Responses:**
- `400 Bad Request`: Missing headers, invalid timestamp, replay attack
- `401 Unauthorized`: Invalid signature

## Signature Computation

### Server-Side (Verification)

```rust
use hmac::{Hmac, Mac};
use sha2::Sha256;

fn verify_signature(secret: &str, timestamp: &str, body: &[u8], signature_hex: &str) -> bool {
    // Construct payload: timestamp + "." + body
    let mut payload = timestamp.as_bytes().to_vec();
    payload.push(b'.');
    payload.extend_from_slice(body);
    
    // Compute HMAC
    let mut mac = Hmac::<Sha256>::new_from_slice(secret.as_bytes()).unwrap();
    mac.update(&payload);
    let expected = mac.finalize().into_bytes();
    
    // Constant-time comparison
    let provided = hex::decode(signature_hex).unwrap();
    provided == expected.as_slice()
}
```

### Client-Side (Platform Implementation)

```python
import hmac
import hashlib
import time

def compute_signature(secret: str, body: bytes) -> tuple[str, str]:
    timestamp = str(int(time.time()))
    payload = f"{timestamp}.".encode() + body
    signature = hmac.new(
        secret.encode(),
        payload,
        hashlib.sha256
    ).hexdigest()
    return signature, timestamp

# Usage
secret = "platform-secret-key"
body = b'{"callback_id":"cb_123",...}'
signature, timestamp = compute_signature(secret, body)

# Send request with headers:
# X-Platform-Signature: {signature}
# X-Platform-Timestamp: {timestamp}
# X-Platform-Nonce: {unique_nonce}
```

## Configuration

### Environment Variables

```bash
# Callback validation settings (optional, uses defaults if not set)
CALLBACK_TIMESTAMP_TOLERANCE_SECS=300  # 5 minutes
CALLBACK_ENFORCE_NONCE=1               # Enable nonce validation
CALLBACK_ENFORCE_SIGNATURE=1           # Enable signature validation
```

### Default Configuration

```rust
CallbackValidationConfig {
    timestamp_tolerance_secs: 300,  // 5 minutes
    enforce_nonce: true,
    enforce_signature: true,
}
```

## Secret Management

### Initialization

For development/testing, initialize default secrets:

```rust
use toonflow_server::publish::init_default_secrets;

// Initialize random secrets for all platforms
init_default_secrets(&pool).await?;
```

**WARNING**: Default secrets are randomly generated. In production:
1. Generate strong secrets externally
2. Store in secure secret management system (e.g., AWS Secrets Manager, HashiCorp Vault)
3. Inject via environment variables or secure API
4. Never commit secrets to version control

### Secret Rotation

```rust
use toonflow_server::publish::{deactivate_platform_secret, upsert_platform_secret};

// 1. Generate new secret
let new_secret = generate_secure_random_secret();

// 2. Add new secret (activates it)
upsert_platform_secret(&pool, "douyin", &new_secret).await?;

// 3. Notify platform of new secret (out of band)
notify_platform_secret_rotation("douyin", &new_secret).await?;

// 4. Wait for platform to update (grace period)
tokio::time::sleep(Duration::from_secs(3600)).await;

// 5. Deactivate old secret
deactivate_platform_secret(&pool, "douyin").await?;
```

## Maintenance

### Nonce Cleanup

Expired nonces should be cleaned up periodically to prevent table bloat.

**Manual Cleanup:**
```sql
SELECT cleanup_expired_callback_nonces();
```

**Automated Cleanup (Recommended):**

Add to cron or scheduled task:
```rust
use toonflow_server::publish::cleanup_expired_nonces;

// Run every hour
tokio::spawn(async move {
    loop {
        tokio::time::sleep(Duration::from_secs(3600)).await;
        match cleanup_expired_nonces(&pool).await {
            Ok(count) => tracing::info!("Cleaned up {} expired nonces", count),
            Err(e) => tracing::error!("Nonce cleanup failed: {}", e),
        }
    }
});
```

### Monitoring

**Key Metrics:**
1. Callback validation success rate
2. Invalid signature rate (potential attack indicator)
3. Replay attack attempts
4. Nonce table size
5. Validation latency

**Audit Queries:**

```sql
-- Recent validation failures
SELECT platform_id, validation_status, COUNT(*) as count
FROM app_publish_callback_audit
WHERE created_at > NOW() - INTERVAL '1 hour'
  AND validation_status != 'valid'
GROUP BY platform_id, validation_status
ORDER BY count DESC;

-- Potential replay attacks
SELECT platform_id, COUNT(*) as replay_attempts
FROM app_publish_callback_audit
WHERE validation_status = 'replay_attack'
  AND created_at > NOW() - INTERVAL '24 hours'
GROUP BY platform_id
ORDER BY replay_attempts DESC;

-- Nonce table size
SELECT COUNT(*) as active_nonces,
       COUNT(*) FILTER (WHERE expires_at <= NOW()) as expired_nonces
FROM app_publish_callback_nonce;
```

## Security Considerations

### Best Practices

1. **Secret Strength**: Use cryptographically secure random secrets (≥32 bytes)
2. **Secret Storage**: Never log or expose secrets in responses
3. **Constant-Time Comparison**: Prevent timing attacks on signature verification
4. **Rate Limiting**: Add rate limits to callback endpoints
5. **IP Allowlisting**: Restrict callbacks to known platform IPs (if available)
6. **TLS Required**: Always use HTTPS for callback endpoints
7. **Audit Retention**: Keep audit logs for security forensics

### Attack Scenarios

#### Replay Attack
**Attack**: Attacker captures valid callback and replays it.
**Defense**: Nonce validation prevents replay within tolerance window.

#### Signature Forgery
**Attack**: Attacker tries to forge valid signature.
**Defense**: HMAC-SHA256 with secret key prevents forgery without key.

#### Timestamp Manipulation
**Attack**: Attacker modifies timestamp to bypass expiry.
**Defense**: Timestamp is included in HMAC payload, modification invalidates signature.

#### Nonce Collision
**Attack**: Attacker tries to guess used nonces.
**Defense**: Nonces should be UUIDs or cryptographically random (≥128 bits).

## Testing

### Unit Tests

Run callback validation tests:
```bash
cd backend
cargo test callback_validation_tests
```

### Integration Tests

Test with real database:
```bash
cargo test --test '*' -- --test-threads=1
```

### Manual Testing

```bash
# 1. Start server
cargo run

# 2. Initialize secrets (development only)
curl -X POST http://localhost:8666/api/v1/admin/init-callback-secrets

# 3. Send test callback
SECRET="your-platform-secret"
TIMESTAMP=$(date +%s)
NONCE=$(uuidgen)
BODY='{"callback_id":"test","event_type":"publish_success","data":{}}'

# Compute signature (requires openssl)
SIGNATURE=$(echo -n "${TIMESTAMP}.${BODY}" | openssl dgst -sha256 -hmac "$SECRET" -hex | cut -d' ' -f2)

curl -X POST http://localhost:8666/api/v1/callbacks/publish/douyin \
  -H "Content-Type: application/json" \
  -H "X-Platform-Signature: $SIGNATURE" \
  -H "X-Platform-Timestamp: $TIMESTAMP" \
  -H "X-Platform-Nonce: $NONCE" \
  -d "$BODY"
```

## Migration Path

### Phase 1: Soft Launch (Current)
- Callback validation implemented
- Audit logging active
- Enforcement configurable (can be disabled)

### Phase 2: Monitoring
- Monitor validation failures
- Identify platform integration issues
- Tune timestamp tolerance if needed

### Phase 3: Enforcement
- Enable enforcement for all platforms
- Reject invalid callbacks
- Alert on suspicious patterns

### Phase 4: Hardening
- Add rate limiting
- Add IP allowlisting
- Implement secret rotation schedule

## Related Tasks

- **M.2**: Idempotency keys for publish operations
- **M.3**: Request-id tracing across publish pipeline
- **M.4**: Sensitive field masking in audit logs
- **M.5**: RBAC for platform credential access
- **M.6**: Rate limiting for publish domain

## References

- [HMAC-SHA256 Specification (RFC 2104)](https://tools.ietf.org/html/rfc2104)
- [Webhook Security Best Practices](https://webhooks.fyi/security/hmac)
- [OWASP API Security Top 10](https://owasp.org/www-project-api-security/)
