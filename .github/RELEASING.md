# Release Process

This project uses automated semantic versioning. Releases are created automatically when PRs are merged to `main`.

## Initial Setup

After creating your GitHub repository, run the setup script:

```bash
./scripts/setup-repo.sh
```

This will:
- Create release labels (`release:major`, `release:minor`, `release:patch`, `release:skip`)
- Enable branch protection (blocks direct pushes to `main`)
- Require PR reviews and passing CI before merge
- Enable auto-merge and delete-branch-on-merge

## Branch Protection

Direct pushes to `main` are blocked. All changes must go through pull requests:

```bash
# Create a feature branch
git checkout -b feat/my-feature

# Make changes and commit
git commit -m "feat: add new feature"

# Push and create PR
git push -u origin feat/my-feature
gh pr create --fill
```

## How It Works

### Automatic Releases (Recommended)

When a PR is merged, the version is automatically bumped based on:

1. **PR Labels** (highest priority)
2. **Conventional Commit titles** (fallback)

| Label | PR Title Pattern | Version Bump | Example |
|-------|------------------|--------------|---------|
| `release:major` | `breaking:` or `!:` | `1.0.0` → `2.0.0` | Breaking API changes |
| `release:minor` | `feat:` or `feat(scope):` | `1.0.0` → `1.1.0` | New features |
| `release:patch` | `fix:` or `fix(scope):` | `1.0.0` → `1.0.1` | Bug fixes |
| `release:skip` | `docs:`, `chore:`, `ci:` | No release | Documentation, CI changes |

### PR Title Examples

```
feat: add dark mode support           → Minor release (1.0.0 → 1.1.0)
fix: resolve crash on startup         → Patch release (1.0.0 → 1.0.1)
feat(ui): new settings panel          → Minor release
fix(database): migration error        → Patch release
docs: update README                   → No release
chore: update dependencies            → No release
breaking: remove deprecated API       → Major release (1.0.0 → 2.0.0)
```

### Using Labels

Labels are automatically suggested based on your PR title, but you can override:

1. Open your PR
2. Add one of these labels:
   - `release:major` - Breaking changes
   - `release:minor` - New features
   - `release:patch` - Bug fixes
   - `release:skip` - No release needed

## Manual Releases

### Option 1: Version Bump Workflow

1. Go to **Actions** → **Version Bump**
2. Click **Run workflow**
3. Select bump type (patch/minor/major)
4. Enable "Create release after bump"

### Option 2: Manual Tag

```bash
git tag v1.2.3
git push origin v1.2.3
```

### Option 3: Release Workflow Dispatch

1. Go to **Actions** → **Release (Manual)**
2. Click **Run workflow**
3. Enter version number

## Release Artifacts

Each release includes:

- `MacML-X.Y.Z.dmg` - Disk image for easy installation
- `MacML-X.Y.Z.zip` - ZIP archive
- Auto-generated changelog
- SHA256 checksums

## Code Signing (Optional)

For signed releases without Gatekeeper warnings, add these secrets:

| Secret | Description |
|--------|-------------|
| `MACOS_CERTIFICATE_BASE64` | Base64-encoded .p12 certificate |
| `MACOS_CERTIFICATE_PASSWORD` | Certificate password |
| `MACOS_SIGNING_IDENTITY` | e.g., `Developer ID Application: Name (TEAM_ID)` |
| `KEYCHAIN_PASSWORD` | Temporary keychain password |
| `APPLE_ID` | Apple ID for notarization |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `APPLE_APP_PASSWORD` | App-specific password |

## Workflow Files

| File | Purpose |
|------|---------|
| `auto-release.yml` | Automatic release on PR merge |
| `release.yml` | Manual release via tag or workflow dispatch |
| `version-bump.yml` | Manual version bumping |
| `build.yml` | CI builds and PR artifacts |
| `labeler.yml` | Automatic PR labeling |
