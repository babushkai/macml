# Ralph GitHub App

A GitHub App that responds to PR comments with autonomous agent capabilities, powered by Claude and hosted on Cloudflare Workers.

## Commands

| Command | Description |
|---------|-------------|
| `/ralph run` | Analyze the next pending story and suggest implementation |
| `/ralph run STORY-ID` | Analyze a specific story |
| `/ralph status` | Show PRD status and story progress |
| `/ralph help` | Show available commands |

## Setup

### 1. Create a GitHub App

1. Go to **Settings > Developer settings > GitHub Apps > New GitHub App**
2. Fill in:
   - **Name**: `Ralph Agent` (or your preferred name)
   - **Homepage URL**: Your Cloudflare Worker URL (after deploy)
   - **Webhook URL**: `https://ralph-github-app.<your-subdomain>.workers.dev`
   - **Webhook secret**: Generate a secure random string
3. **Permissions**:
   - **Repository permissions**:
     - Contents: Read & write
     - Issues: Read & write
     - Pull requests: Read & write
     - Metadata: Read-only
   - **Subscribe to events**:
     - Issue comment
     - Pull request
4. Create the app and note the **App ID**
5. Generate a **Private Key** and download it

### 2. Deploy to Cloudflare Workers

```bash
cd scripts/ralph/github-app

# Install dependencies
npm install

# Set secrets
wrangler secret put GITHUB_APP_ID
wrangler secret put GITHUB_PRIVATE_KEY    # Paste the entire PEM content
wrangler secret put GITHUB_WEBHOOK_SECRET
wrangler secret put ANTHROPIC_API_KEY

# Deploy
npm run deploy
```

### 3. Install the App

1. Go to your GitHub App settings
2. Click **Install App**
3. Select the repositories where you want Ralph

### 4. Use Ralph

1. Create a branch with `scripts/ralph/prd.json`:

```json
{
  "project": "My Feature",
  "branchName": "ralph/my-feature",
  "userStories": [
    {
      "id": "FEAT-001",
      "title": "Add user authentication",
      "description": "Implement login/logout functionality",
      "acceptanceCriteria": [
        "Users can log in with email/password",
        "Session persists across page reloads",
        "Logout clears the session"
      ],
      "priority": 1,
      "passes": false
    }
  ]
}
```

2. Open a PR for the branch
3. Comment `/ralph run` to get implementation guidance

## Development

```bash
# Run locally
npm run dev

# Test with ngrok or similar for webhook delivery
ngrok http 8787
```

## Architecture

```
PR Comment (/ralph run)
        │
        ▼
┌─────────────────────┐
│ Cloudflare Worker   │
│                     │
│ 1. Verify webhook   │
│ 2. Parse command    │
│ 3. Fetch PRD        │
│ 4. Call Claude API  │
│ 5. Post response    │
└─────────────────────┘
        │
        ▼
PR Comment (analysis)
```

## Limitations

- Ralph analyzes and suggests changes but cannot directly commit code
- Works best for planning and guidance, not full automation
- Rate limited by GitHub API and Anthropic API quotas

## Future Improvements

- [ ] Direct code modification via GitHub API
- [ ] Automatic PR creation for fixes
- [ ] Integration with CI/CD checks
- [ ] Support for `/ralph apply` to implement suggestions
