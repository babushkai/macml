/**
 * Ralph GitHub App - Cloudflare Worker
 *
 * Responds to PR comments with commands like:
 * - /ralph run - Run Ralph on the current PR branch
 * - /ralph status - Show current PRD status
 * - /ralph help - Show available commands
 */

import { createAppAuth } from "@octokit/auth-app";
import { Octokit } from "@octokit/rest";

interface Env {
  GITHUB_APP_ID: string;
  GITHUB_PRIVATE_KEY: string;
  GITHUB_WEBHOOK_SECRET: string;
  ANTHROPIC_API_KEY: string;
}

interface WebhookPayload {
  action: string;
  comment?: {
    id: number;
    body: string;
    user: { login: string };
  };
  issue?: {
    number: number;
    pull_request?: { url: string };
  };
  pull_request?: {
    number: number;
    head: { ref: string; sha: string };
    base: { ref: string };
  };
  repository: {
    owner: { login: string };
    name: string;
    full_name: string;
  };
  installation?: { id: number };
  sender: { login: string };
}

// Verify GitHub webhook signature
async function verifySignature(
  secret: string,
  signature: string,
  body: string
): Promise<boolean> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, encoder.encode(body));
  const digest = "sha256=" + Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  return signature === digest;
}

// Create authenticated Octokit instance
async function getOctokit(env: Env, installationId: number): Promise<Octokit> {
  const auth = createAppAuth({
    appId: env.GITHUB_APP_ID,
    privateKey: env.GITHUB_PRIVATE_KEY.replace(/\\n/g, "\n"),
    installationId,
  });

  const { token } = await auth({ type: "installation" });
  return new Octokit({ auth: token });
}

// Parse command from comment body
function parseCommand(body: string): { command: string; args: string[] } | null {
  const match = body.match(/^\/ralph\s+(\w+)(?:\s+(.*))?$/m);
  if (!match) return null;
  return {
    command: match[1].toLowerCase(),
    args: match[2]?.split(/\s+/).filter(Boolean) || [],
  };
}

// Get PRD from repository
async function getPRD(
  octokit: Octokit,
  owner: string,
  repo: string,
  ref: string
): Promise<{ content: any; sha: string } | null> {
  try {
    const { data } = await octokit.repos.getContent({
      owner,
      repo,
      path: "scripts/ralph/prd.json",
      ref,
    });

    if ("content" in data) {
      const content = JSON.parse(atob(data.content));
      return { content, sha: data.sha };
    }
  } catch (e) {
    return null;
  }
  return null;
}

// Get progress file from repository
async function getProgress(
  octokit: Octokit,
  owner: string,
  repo: string,
  ref: string
): Promise<{ content: string; sha: string } | null> {
  try {
    const { data } = await octokit.repos.getContent({
      owner,
      repo,
      path: "scripts/ralph/progress.txt",
      ref,
    });

    if ("content" in data) {
      return { content: atob(data.content), sha: data.sha };
    }
  } catch (e) {
    return null;
  }
  return null;
}

// Call Anthropic API
async function callClaude(
  apiKey: string,
  systemPrompt: string,
  userPrompt: string
): Promise<string> {
  const response = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: "claude-sonnet-4-20250514",
      max_tokens: 4096,
      system: systemPrompt,
      messages: [{ role: "user", content: userPrompt }],
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Anthropic API error: ${error}`);
  }

  const data = await response.json() as { content: Array<{ text: string }> };
  return data.content[0].text;
}

// Handle /ralph run command
async function handleRunCommand(
  env: Env,
  octokit: Octokit,
  payload: WebhookPayload,
  args: string[]
): Promise<string> {
  const owner = payload.repository.owner.login;
  const repo = payload.repository.name;

  // Get PR details
  let prNumber: number;
  let branch: string;

  if (payload.pull_request) {
    prNumber = payload.pull_request.number;
    branch = payload.pull_request.head.ref;
  } else if (payload.issue?.pull_request) {
    // Comment on a PR
    const prUrl = payload.issue.pull_request.url;
    const { data: pr } = await octokit.request(`GET ${prUrl}`);
    prNumber = pr.number;
    branch = pr.head.ref;
  } else {
    return "This command can only be used on Pull Requests.";
  }

  // Get PRD
  const prd = await getPRD(octokit, owner, repo, branch);
  if (!prd) {
    return `No PRD found at \`scripts/ralph/prd.json\` on branch \`${branch}\`.\n\nCreate a PRD file to use Ralph.`;
  }

  // Get progress
  const progress = await getProgress(octokit, owner, repo, branch);

  // Find next story
  const stories = prd.content.userStories || [];
  const pendingStories = stories.filter((s: any) => !s.passes);

  if (pendingStories.length === 0) {
    return "All stories are complete! Nothing to do.";
  }

  // Target specific story if provided
  let targetStory = pendingStories[0];
  if (args[0]) {
    const found = pendingStories.find((s: any) => s.id === args[0]);
    if (found) {
      targetStory = found;
    } else {
      return `Story \`${args[0]}\` not found or already complete.`;
    }
  }

  // Build prompt for Claude
  const systemPrompt = `You are Ralph, an autonomous coding agent. You're helping implement user stories for a software project.

Analyze the story and provide:
1. A plan for implementation
2. Key files that need to be modified
3. Specific code changes needed

Be concise and actionable. Format code changes clearly.`;

  const userPrompt = `# Project: ${prd.content.project}
Branch: ${branch}

# Current Story
ID: ${targetStory.id}
Title: ${targetStory.title}
Description: ${targetStory.description}

Acceptance Criteria:
${targetStory.acceptanceCriteria?.map((c: string) => `- ${c}`).join("\n") || "None specified"}

# All Stories Status
${stories.map((s: any) => `- [${s.passes ? "x" : " "}] ${s.id}: ${s.title}`).join("\n")}

# Progress Log
${progress?.content || "No previous progress"}

---

Analyze this story and provide implementation guidance. What files need to change? What's the approach?`;

  const analysis = await callClaude(env.ANTHROPIC_API_KEY, systemPrompt, userPrompt);

  // Post the analysis as a comment
  return `## Ralph Analysis for ${targetStory.id}

**Story:** ${targetStory.title}

${analysis}

---
To apply these changes, a developer should review and implement them.

*Ralph can analyze and suggest changes, but cannot directly modify code in this PR.*`;
}

// Handle /ralph status command
async function handleStatusCommand(
  octokit: Octokit,
  payload: WebhookPayload
): Promise<string> {
  const owner = payload.repository.owner.login;
  const repo = payload.repository.name;

  // Get branch from PR
  let branch = "main";
  if (payload.pull_request) {
    branch = payload.pull_request.head.ref;
  } else if (payload.issue?.pull_request) {
    const prUrl = payload.issue.pull_request.url;
    const { data: pr } = await octokit.request(`GET ${prUrl}`);
    branch = pr.head.ref;
  }

  const prd = await getPRD(octokit, owner, repo, branch);
  if (!prd) {
    return `No PRD found at \`scripts/ralph/prd.json\` on branch \`${branch}\`.`;
  }

  const stories = prd.content.userStories || [];
  const completed = stories.filter((s: any) => s.passes).length;
  const total = stories.length;

  let status = `## Ralph Status

**Project:** ${prd.content.project}
**Branch:** ${branch}
**Progress:** ${completed}/${total} stories complete

### Stories
`;

  for (const story of stories) {
    const icon = story.passes ? "✅" : "⬜";
    status += `${icon} **${story.id}**: ${story.title}\n`;
    if (story.notes) {
      status += `   > ${story.notes}\n`;
    }
  }

  return status;
}

// Handle /ralph help command
function handleHelpCommand(): string {
  return `## Ralph Commands

| Command | Description |
|---------|-------------|
| \`/ralph run\` | Analyze the next pending story and suggest implementation |
| \`/ralph run STORY-ID\` | Analyze a specific story |
| \`/ralph status\` | Show PRD status and story progress |
| \`/ralph help\` | Show this help message |

### Setup
1. Create \`scripts/ralph/prd.json\` with your user stories
2. Create a PR for your feature branch
3. Use \`/ralph run\` to get implementation guidance

### PRD Format
\`\`\`json
{
  "project": "My Project",
  "branchName": "ralph/my-feature",
  "userStories": [
    {
      "id": "STORY-001",
      "title": "Implement feature X",
      "description": "...",
      "acceptanceCriteria": ["..."],
      "priority": 1,
      "passes": false
    }
  ]
}
\`\`\`
`;
}

// Main webhook handler
async function handleWebhook(
  env: Env,
  payload: WebhookPayload
): Promise<Response> {
  // Only handle issue_comment events with 'created' action
  if (payload.action !== "created" || !payload.comment) {
    return new Response("Ignored", { status: 200 });
  }

  // Parse command
  const parsed = parseCommand(payload.comment.body);
  if (!parsed) {
    return new Response("No command found", { status: 200 });
  }

  // Get authenticated client
  if (!payload.installation?.id) {
    return new Response("No installation ID", { status: 400 });
  }

  const octokit = await getOctokit(env, payload.installation.id);
  const owner = payload.repository.owner.login;
  const repo = payload.repository.name;
  const issueNumber = payload.issue?.number || payload.pull_request?.number;

  if (!issueNumber) {
    return new Response("No issue/PR number", { status: 400 });
  }

  // Add reaction to show we're processing
  await octokit.reactions.createForIssueComment({
    owner,
    repo,
    comment_id: payload.comment.id,
    content: "eyes",
  });

  let responseBody: string;

  try {
    switch (parsed.command) {
      case "run":
        responseBody = await handleRunCommand(env, octokit, payload, parsed.args);
        break;
      case "status":
        responseBody = await handleStatusCommand(octokit, payload);
        break;
      case "help":
        responseBody = handleHelpCommand();
        break;
      default:
        responseBody = `Unknown command: \`${parsed.command}\`. Use \`/ralph help\` for available commands.`;
    }
  } catch (error) {
    console.error("Error handling command:", error);
    responseBody = `Error processing command: ${error instanceof Error ? error.message : "Unknown error"}`;
  }

  // Post response as comment
  await octokit.issues.createComment({
    owner,
    repo,
    issue_number: issueNumber,
    body: responseBody,
  });

  // Add checkmark reaction
  await octokit.reactions.createForIssueComment({
    owner,
    repo,
    comment_id: payload.comment.id,
    content: "rocket",
  });

  return new Response("OK", { status: 200 });
}

// Cloudflare Worker entry point
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // Health check
    if (request.method === "GET") {
      return new Response("Ralph GitHub App is running!", { status: 200 });
    }

    // Only accept POST for webhooks
    if (request.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }

    // Verify webhook signature
    const signature = request.headers.get("x-hub-signature-256") || "";
    const body = await request.text();

    const isValid = await verifySignature(env.GITHUB_WEBHOOK_SECRET, signature, body);
    if (!isValid) {
      return new Response("Invalid signature", { status: 401 });
    }

    // Parse payload
    const payload = JSON.parse(body) as WebhookPayload;

    // Handle webhook
    return handleWebhook(env, payload);
  },
};
