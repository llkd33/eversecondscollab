# Flutter App Environment Configuration

## Security Notice
⚠️ **NEVER commit Supabase credentials to the repository!**

This app requires Supabase credentials to be provided at build time using `--dart-define` flags.

## Required Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `SUPABASE_URL` | Your Supabase project URL | `https://xxxxx.supabase.co` |
| `SUPABASE_ANON_KEY` | Your Supabase anonymous key | `eyJhbGci...` |

## Development Setup

### 1. Get Your Credentials
1. Go to [Supabase Dashboard](https://app.supabase.com/)
2. Select your project
3. Go to Settings → API
4. Copy the **Project URL** and **anon/public** key

### 2. Running the App

#### Method 1: Command Line (Recommended for CI/CD)
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_anon_key_here
```

#### Method 2: VS Code (launch.json)
Create `.vscode/launch.json`:
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Flutter (Dev)",
      "request": "launch",
      "type": "dart",
      "args": [
        "--dart-define=SUPABASE_URL=${env:SUPABASE_URL}",
        "--dart-define=SUPABASE_ANON_KEY=${env:SUPABASE_ANON_KEY}"
      ]
    }
  ]
}
```

Then set environment variables in your shell:
```bash
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_ANON_KEY="your_anon_key_here"
```

#### Method 3: Android Studio / IntelliJ
1. Run → Edit Configurations
2. Add to "Additional run args":
   ```
   --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your_anon_key_here
   ```

### 3. Building for Production

#### Android
```bash
flutter build apk \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_anon_key_here \
  --release
```

#### iOS
```bash
flutter build ios \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_anon_key_here \
  --release
```

## CI/CD Configuration

### GitHub Actions Example
```yaml
- name: Build Flutter App
  env:
    SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
    SUPABASE_ANON_KEY: ${{ secrets.SUPABASE_ANON_KEY }}
  run: |
    flutter build apk \
      --dart-define=SUPABASE_URL=$SUPABASE_URL \
      --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
      --release
```

Store secrets in: Repository Settings → Secrets and variables → Actions

## Troubleshooting

### Error: "SUPABASE_URL is not configured"
**Cause**: Missing `--dart-define` flags
**Solution**: Add the required flags to your run/build command

### Error: "Bad state: No element" on startup
**Cause**: Invalid or missing Supabase credentials
**Solution**: Verify your credentials are correct and properly formatted

## Security Best Practices

1. ✅ **DO** use `--dart-define` for all sensitive configuration
2. ✅ **DO** store credentials in CI/CD secrets
3. ✅ **DO** rotate keys if accidentally exposed
4. ❌ **DON'T** commit credentials to git
5. ❌ **DON'T** hardcode credentials in source files
6. ❌ **DON'T** share credentials in team chat or email

## Additional Resources

- [Flutter Build Environments](https://docs.flutter.dev/deployment/flavors)
- [Supabase Security Best Practices](https://supabase.com/docs/guides/auth/managing-user-data#security-considerations)
