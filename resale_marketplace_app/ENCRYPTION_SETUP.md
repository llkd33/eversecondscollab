# 🔐 Encryption Configuration Guide

## Overview

This application uses AES-256-GCM encryption to securely store sensitive data like account numbers. The encryption key is now properly managed through environment variables instead of being hardcoded.

## Setup Instructions

### 1. Generate a Secure Encryption Key

Generate a secure random key using OpenSSL:

```bash
openssl rand -base64 32
```

This will output a random 32-character base64-encoded string like:
```
kJ8x3vR9mL2nQ5wT7yH4pA6sD8fG1hK3jM9cV0bN2zX=
```

### 2. Configure Environment Variables

1. Copy the `.env.example` file to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Open `.env` and replace the `ENCRYPTION_KEY` value:
   ```env
   ENCRYPTION_KEY=kJ8x3vR9mL2nQ5wT7yH4pA6sD8fG1hK3jM9cV0bN2zX=
   ```

3. **NEVER commit the `.env` file to git!** (It should already be in `.gitignore`)

### 3. Production Deployment

For production environments:

1. **Do NOT use the same key as development**
2. Generate a new secure key for each environment:
   - Development: `ENCRYPTION_KEY_DEV`
   - Staging: `ENCRYPTION_KEY_STAGING`
   - Production: `ENCRYPTION_KEY_PROD`

3. Store keys securely:
   - AWS: Use AWS Secrets Manager or Parameter Store
   - Google Cloud: Use Secret Manager
   - Azure: Use Key Vault
   - General: Use environment variables in your CI/CD platform

### 4. Key Rotation

To rotate encryption keys:

1. Generate new encryption key
2. Decrypt existing data with old key
3. Re-encrypt with new key
4. Update environment variable
5. Deploy

⚠️ **Warning**: Changing the encryption key will make existing encrypted data unreadable unless you decrypt and re-encrypt it first!

## Security Best Practices

✅ **DO:**
- Use a different key for each environment
- Store keys in secure key management services
- Rotate keys periodically (e.g., every 90 days)
- Use strong random keys (minimum 32 characters)
- Keep backup of keys in secure offline storage

❌ **DON'T:**
- Commit encryption keys to git
- Share keys via email or chat
- Use the same key across environments
- Use weak or predictable keys
- Store keys in application code

## Troubleshooting

### Error: "ENCRYPTION_KEY not found in .env file"

**Solution**: Make sure you have a `.env` file with `ENCRYPTION_KEY` set:
```bash
cp .env.example .env
# Edit .env and add your encryption key
```

### Error: "Default ENCRYPTION_KEY detected"

**Solution**: Generate a new secure key and replace the default value:
```bash
openssl rand -base64 32
# Copy the output to ENCRYPTION_KEY in .env
```

### Error: "ENCRYPTION_KEY is too short"

**Solution**: Your key must be at least 32 characters long. Generate a new one:
```bash
openssl rand -base64 32
```

## Files Modified

- `lib/config/encryption_config.dart` - New encryption configuration
- `lib/services/account_encryption_service.dart` - Updated to use env variables
- `.env.example` - Added encryption key example
- `pubspec.yaml` - Added flutter_dotenv dependency
- `lib/main.dart` - Added .env loading on app start

## Verification

To verify encryption is working correctly:

1. Run the app in debug mode
2. Check the console for encryption configuration logs:
   ```
   🔐 Encryption Configuration:
     - Key configured: true
     - Key length: 44
     - Using secure key: true
   ```

3. The app should NOT show any encryption-related errors

## Migration from Hardcoded Key

If you have existing encrypted data with the old hardcoded key:

1. **Before deploying**: Create a migration script to:
   - Read all encrypted account numbers
   - Decrypt with old key
   - Re-encrypt with new key
   - Update database

2. Or: Keep old key temporarily and implement dual-key support during transition period

3. After migration: Remove old key and use only new environment-based key

## Support

For questions or issues, contact the development team or create an issue in the project repository.
