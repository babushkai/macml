# Ralph GitHub App

A GitHub App that responds to PR comments with autonomous agent capabilities, powered by Claude and hosted on Cloudflare Workers.

## Quick Start Example

Here's a complete example of using Ralph to implement a new feature:

### Step 1: Create a Feature Branch with PRD

```bash
git checkout -b ralph/add-dark-mode
mkdir -p scripts/ralph
```

Create `scripts/ralph/prd.json`:

```json
{
  "project": "Dark Mode Feature",
  "branchName": "ralph/add-dark-mode",
  "description": "Add dark mode support to the application",
  "userStories": [
    {
      "id": "DARK-001",
      "title": "Add theme toggle button",
      "description": "Users need a way to switch between light and dark themes",
      "acceptanceCriteria": [
        "Toggle button visible in the header",
        "Clicking toggles between light/dark",
        "Current theme persists in localStorage"
      ],
      "priority": 1,
      "passes": false,
      "notes": ""
    },
    {
      "id": "DARK-002",
      "title": "Implement dark color palette",
      "description": "Define CSS variables for dark mode colors",
      "acceptanceCriteria": [
        "Dark background colors defined",
        "Text colors have good contrast",
        "All components use CSS variables"
      ],
      "priority": 2,
      "passes": false,
      "notes": ""
    }
  ]
}
```

Create `scripts/ralph/progress.txt`:

```
# Ralph Progress Log
Started: 2024-01-15

## Codebase Patterns
- Uses Tailwind CSS for styling
- React components in src/components/
- Theme context in src/contexts/ThemeContext.tsx

---
```

### Step 2: Push and Create PR

```bash
git add scripts/ralph/
git commit -m "feat: Add dark mode PRD for Ralph"
git push -u origin ralph/add-dark-mode
gh pr create --title "feat: Add dark mode support" --body "Using Ralph to implement dark mode"
```

### Step 3: Use Ralph Commands in PR

**Check status:**
```
/ralph status
```

Ralph responds:
```
## Ralph Status

**Project:** Dark Mode Feature
**Branch:** ralph/add-dark-mode
**Progress:** 0/2 stories complete

### Stories
⬜ **DARK-001**: Add theme toggle button
⬜ **DARK-002**: Implement dark color palette
```

**Get implementation guidance:**
```
/ralph run
```

Ralph responds with detailed analysis:
```
## Ralph Analysis for DARK-001

**Story:** Add theme toggle button

### Implementation Plan

1. Create ThemeToggle component
2. Add to Header component
3. Implement localStorage persistence

### Files to Modify

**src/components/ThemeToggle.tsx** (new file)
\`\`\`tsx
export function ThemeToggle() {
  const [isDark, setIsDark] = useState(() =>
    localStorage.getItem('theme') === 'dark'
  );
  // ... implementation details
}
\`\`\`

**src/components/Header.tsx** (modify)
- Import ThemeToggle
- Add to header layout

### Validation
- Run `npm run build` to check for errors
- Test toggle in browser
```

**Target specific story:**
```
/ralph run DARK-002
```

### Step 4: Implement and Iterate

1. Follow Ralph's guidance to implement changes
2. Commit your changes
3. Run `/ralph status` to check progress
4. Update `prd.json` to mark stories as `"passes": true`
5. Repeat until all stories complete

---

## Commands Reference

| Command | Description | Example |
|---------|-------------|---------|
| `/ralph run` | Analyze next pending story (by priority) | `/ralph run` |
| `/ralph run STORY-ID` | Analyze a specific story | `/ralph run DARK-002` |
| `/ralph status` | Show all stories and their status | `/ralph status` |
| `/ralph help` | Show available commands | `/ralph help` |

---

## PRD File Format

The `scripts/ralph/prd.json` file defines your project:

```json
{
  "project": "Project Name",
  "branchName": "ralph/feature-name",
  "description": "Brief description of the feature",
  "userStories": [
    {
      "id": "FEAT-001",
      "title": "Short title",
      "description": "Detailed description of what needs to be done",
      "acceptanceCriteria": [
        "Criterion 1",
        "Criterion 2"
      ],
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `project` | Yes | Project or feature name |
| `branchName` | Yes | Git branch name (must match your PR branch) |
| `description` | No | Overview of the work |
| `userStories` | Yes | Array of stories to implement |
| `userStories[].id` | Yes | Unique identifier (e.g., FEAT-001) |
| `userStories[].title` | Yes | Short descriptive title |
| `userStories[].description` | Yes | Detailed description |
| `userStories[].acceptanceCriteria` | Yes | List of requirements to satisfy |
| `userStories[].priority` | Yes | Number (1 = highest priority) |
| `userStories[].passes` | Yes | `false` = pending, `true` = complete |
| `userStories[].notes` | No | Notes from implementation |

---

## Progress File Format

The `scripts/ralph/progress.txt` helps Ralph understand context:

```
# Ralph Progress Log
Started: 2024-01-15

## Codebase Patterns
- Key pattern 1 (e.g., "Uses Redux for state management")
- Key pattern 2 (e.g., "API calls go through src/api/client.ts")
- Key pattern 3 (e.g., "Tests use Jest + React Testing Library")

---

## 2024-01-15 - FEAT-001
- What was implemented
- Files changed
- **Learnings:** Any gotchas or patterns discovered
---
```

**Tips for better results:**
- Add codebase patterns Ralph should know
- Document any gotchas or conventions
- Log what was done in each iteration

---

## Setup Instructions

### 1. Create a GitHub App

1. Go to **GitHub Settings > Developer settings > GitHub Apps > New GitHub App**

2. **Basic info:**
   - **Name**: `Ralph Agent` (or your preferred name)
   - **Homepage URL**: `https://github.com/your-org/your-repo`
   - **Webhook URL**: `https://ralph-github-app.<your-subdomain>.workers.dev`
   - **Webhook secret**: Generate with `openssl rand -hex 32`

3. **Permissions:**
   | Permission | Access |
   |------------|--------|
   | Contents | Read & write |
   | Issues | Read & write |
   | Pull requests | Read & write |
   | Metadata | Read-only |

4. **Subscribe to events:**
   - [x] Issue comment
   - [x] Pull request

5. After creating, note the **App ID** (number at top of settings page)

6. Scroll down and click **Generate a private key** - save the `.pem` file

### 2. Deploy to Cloudflare Workers

```bash
# Navigate to the app directory
cd scripts/ralph/github-app

# Install dependencies
npm install

# Login to Cloudflare (first time only)
npx wrangler login

# Set secrets (you'll be prompted to enter values)
npx wrangler secret put GITHUB_APP_ID
# Enter: your app ID number (e.g., 123456)

npx wrangler secret put GITHUB_PRIVATE_KEY
# Enter: entire contents of the .pem file (including BEGIN/END lines)

npx wrangler secret put GITHUB_WEBHOOK_SECRET
# Enter: the webhook secret you generated

npx wrangler secret put ANTHROPIC_API_KEY
# Enter: your Anthropic API key (sk-ant-...)

# Deploy
npm run deploy
```

After deploy, you'll see your worker URL like:
```
https://ralph-github-app.your-subdomain.workers.dev
```

Update your GitHub App's webhook URL to this address.

### 3. Install the App

1. Go to your GitHub App settings page
2. Click **Install App** in the left sidebar
3. Select your account/organization
4. Choose **Only select repositories** and pick your repos
5. Click **Install**

### 4. Verify It Works

1. Create a test PR in an installed repository
2. Comment `/ralph help`
3. Ralph should respond with the help message

---

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                        GitHub PR                              │
│                                                               │
│  User comments: /ralph run                                    │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼ webhook
┌──────────────────────────────────────────────────────────────┐
│                   Cloudflare Worker                           │
│                                                               │
│  1. Verify webhook signature (GITHUB_WEBHOOK_SECRET)          │
│  2. Authenticate as GitHub App (GITHUB_PRIVATE_KEY)           │
│  3. Parse command from comment                                │
│  4. Fetch prd.json and progress.txt from PR branch            │
│  5. Call Claude API with context (ANTHROPIC_API_KEY)          │
│  6. Post response as PR comment                               │
└──────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────┐
│                        GitHub PR                              │
│                                                               │
│  Ralph responds with implementation guidance                  │
└──────────────────────────────────────────────────────────────┘
```

---

## Troubleshooting

### Ralph doesn't respond

1. Check webhook deliveries in GitHub App settings
2. Check Cloudflare Worker logs: `npm run tail`
3. Verify all secrets are set correctly

### "No PRD found" error

- Ensure `scripts/ralph/prd.json` exists on the PR's branch
- Check the file is valid JSON

### "Invalid signature" error

- Webhook secret in Cloudflare must match GitHub App setting

### Rate limits

- GitHub API: 5000 requests/hour per installation
- Anthropic API: Check your plan limits

---

## Local Development

```bash
# Run locally
npm run dev

# In another terminal, expose to internet
ngrok http 8787

# Update GitHub App webhook URL to ngrok URL
# Test with PR comments
```

---

## Limitations

- **Analysis only**: Ralph suggests changes but doesn't commit code directly
- **Context window**: Very large PRDs may be truncated
- **No file reading**: Ralph sees PRD/progress but not full codebase

---

## Future Roadmap

- [ ] `/ralph apply` - Automatically implement and commit suggestions
- [ ] `/ralph review` - Code review capabilities
- [ ] Multi-file codebase context
- [ ] Integration with CI status checks
- [ ] Slack/Discord notifications
