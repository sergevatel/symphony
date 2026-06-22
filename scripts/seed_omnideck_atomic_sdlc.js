#!/usr/bin/env node

const endpoint = "https://api.linear.app/graphql";
const apiKey = process.env.LINEAR_API_KEY;

if (!apiKey) {
  console.error("LINEAR_API_KEY is required.");
  process.exit(1);
}

const ids = {
  team: "d6f5e1a8-cde2-4063-bc08-acb70de19261",
  project: "b13e71d7-0e61-41d0-ac24-739a741029d4",
  todo: "44287fa4-4e65-45e4-9de1-4b75014c5791",
  milestones: {
    scope: "567e2d5a-bf7c-40e6-aaa4-4a382fa4521e",
    tables: "25927962-7081-4130-b62b-3f87e203e8af",
    backs: "28c449be-5701-4235-8faa-79f87eca79c9",
    assets: "5336d79a-e4b6-43c9-8f3e-24ed44dd3bb7",
    framework: "b5336b88-792e-44a9-9928-d0fb351eed15",
    aplus: "0336a9c9-df06-4eae-9d29-271dd67ef748",
    rights: "5be20a41-6340-4edf-b54b-695836ec705f",
    qa: "05e59f53-fda8-4347-8ddc-be33b5a116d8",
    rc: "252e009b-8727-4b41-b3c2-7703fbca27bb",
  },
  labels: {
    task: "385a84ed-ffbf-43aa-b14f-fd02b4d09d45",
    ready: "c289a1e7-bb9e-409a-9d32-eb262493e2ca",
    shipBlocker: "b9e1ef35-59eb-45e2-8fa6-c82ae2d380aa",
    planning: "52c06554-2c0e-42e5-8bcc-0c81f9111ba5",
    production: "88f3944f-9bed-4574-ae4b-65221d4dab32",
    integration: "2bb5a926-d5de-479a-a572-f0e896ec3ad8",
    verification: "3dbffcf2-31b7-41df-9c06-30b301b1a38b",
    release: "2b932af3-8215-4cd4-a3f3-cbb25e2bdd61",
    unity: "ac1115fc-542c-4e02-95b4-434a1f4686a6",
    qa: "fb3b78f6-49f3-4f9a-8b83-ab6a3ea54a6f",
    docs: "7d03baf1-f7ff-4ef4-bdaf-c86c3832b807",
    demo: "4527a711-6ca1-43ee-8fe2-70f3142af636",
    rights: "38812ae4-4935-41e9-b7d4-d58434eb8e6d",
    releaseComponent: "68468200-2960-4019-87f2-0b5568bccf85",
    tables: "c6673aee-2a9b-4696-9213-2a396454e6e9",
    backs: "f2f85b86-76a5-47f9-9e61-76900f84c5fb",
    fronts: "b7ee693b-3e48-4048-8bdb-d552760c3d0e",
  },
};

async function gql(query, variables = {}) {
  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: apiKey,
    },
    body: JSON.stringify({ query, variables }),
  });
  const body = await response.json();
  if (body.errors) {
    throw new Error(JSON.stringify(body.errors, null, 2));
  }
  return body.data;
}

function baseDescription(task) {
  return [
    task.goal,
    "",
    "Source of truth: docs/jumbo-card-ui-asset-package-prd.md.",
    "",
    "Acceptance criteria:",
    ...task.acceptance.map((item) => `- ${item}`),
    "",
    "Execution rules:",
    "- Work only in the Symphony issue workspace.",
    "- Keep Unity 2022.3 compatibility and Unity 6 release validation in view.",
    "- Update the persistent `## Codex Workpad` with files changed, commands run, and validation evidence.",
    "- Do not move to Done unless the work is committed to the ticket branch and evidence is present.",
  ].join("\n");
}

function workpad(task) {
  return [
    "## Codex Workpad",
    "",
    `Goal: ${task.goal}`,
    "",
    "Acceptance criteria:",
    ...task.acceptance.map((item) => `- [ ] ${item}`),
    "",
    "Checklist:",
    "- [ ] Inspect current OmniDeck PRD and repo state.",
    "- [ ] Implement or produce the requested artifact.",
    "- [ ] Run focused validation.",
    "- [ ] Commit/push the ticket branch or record the exact blocker.",
    "",
    "Validation evidence:",
    "- Pending.",
    "",
    "Blockers:",
    "- None known at creation.",
    "",
    "Final status:",
    "- Todo.",
  ].join("\n");
}

function mk(id, title, stream, milestone, priority, labels, goal, acceptance) {
  return {
    key: `ODK-SDL-${String(id).padStart(3, "0")}`,
    title: `[ODK-SDL-${String(id).padStart(3, "0")}] ${title}`,
    stream,
    milestone,
    priority,
    labels: [ids.labels.task, ids.labels.ready, ...labels],
    goal,
    acceptance,
  };
}

const tasks = [];
let n = 1;
const add = (title, stream, milestone, priority, labels, goal, acceptance) => {
  tasks.push(mk(n++, title, stream, milestone, priority, labels, goal, acceptance));
};

const standardAcceptance = [
  "Changed files or generated artifacts are listed in the Workpad.",
  "Focused validation command or explicit blocker is recorded.",
  "No rejected assets are promoted into production paths.",
];

[
  "package manifest dependency audit",
  "UPM Samples~ structure audit",
  "Asset Store fallback root audit",
  "asmdef namespace boundary audit",
  "package metadata keyword pass",
  "third-party notices stub pass",
  "changelog/release notes scaffold",
  "package root duplicate-file scan",
  "root folder public naming scan",
  "Casino Royale exclusion scan",
  "Jumbo public-branding migration scan",
  "package export dry-run checklist",
].forEach((name) =>
  add(
    `Package foundation: ${name}`,
    "package",
    ids.milestones.scope,
    2,
    [ids.labels.integration, ids.labels.unity],
    `Close the package-foundation slice for ${name}.`,
    standardAcceptance
  )
);

[
  "cosmetic item base schema",
  "deck theme schema",
  "back skin schema",
  "table skin schema",
  "theme preset schema",
  "rarity and premium tier enums",
  "catalog stable ID validation",
  "localization key validation",
  "source-chain metadata fields",
  "Addressables key metadata fields",
  "unlock metadata fields",
  "catalog sample data fixtures",
].forEach((name) =>
  add(
    `Runtime catalog: ${name}`,
    "runtime",
    ids.milestones.framework,
    2,
    [ids.labels.integration, ids.labels.unity, ids.labels.shipBlocker],
    `Implement or validate the runtime catalog slice for ${name}.`,
    standardAcceptance
  )
);

[
  "catalog browser layout",
  "asset preview panel",
  "category and rarity filters",
  "source-chain warning panel",
  "accessibility warning panel",
  "Addressables warning panel",
  "duplicate ID report",
  "missing localization report",
  "readiness report exporter",
  "Studio Quick Start docs",
  "Studio smoke test",
  "Studio no-cache-artifact gate",
].forEach((name) =>
  add(
    `OmniDeck Studio: ${name}`,
    "studio",
    ids.milestones.aplus,
    2,
    [ids.labels.integration, ids.labels.unity, ids.labels.qa, ids.labels.shipBlocker],
    `Build or verify OmniDeck Studio capability: ${name}.`,
    standardAcceptance
  )
);

[
  "preset creation workflow",
  "front/back/table compatibility checks",
  "UI accent metadata",
  "seasonal/featured flags",
  "preset storefront binding",
  "preset settings binding",
  "preset validation report",
  "preset sample assets",
  "Theme Composer docs",
  "Theme Composer regression test",
].forEach((name) =>
  add(
    `Theme Composer: ${name}`,
    "theme-composer",
    ids.milestones.aplus,
    2,
    [ids.labels.integration, ids.labels.unity],
    `Build or verify Theme Composer capability: ${name}.`,
    standardAcceptance
  )
);

[
  "mobile vertical tab layout",
  "front/back/table segmented controls",
  "locked state card tile",
  "owned state card tile",
  "featured and rarity badges",
  "mock currency labels",
  "purchase attempt UnityEvent",
  "selection changed UnityEvent",
  "preview combination panel",
  "localization-ready strings",
  "storefront prefab docs",
  "storefront smoke test",
].forEach((name) =>
  add(
    `Storefront UI kit: ${name}`,
    "storefront",
    ids.milestones.framework,
    2,
    [ids.labels.integration, ids.labels.unity, ids.labels.demo],
    `Build or verify Storefront UI kit capability: ${name}.`,
    standardAcceptance
  )
);

[
  "contrast evidence calculator",
  "jumbo-index evidence tracker",
  "colorblind-safe metadata checker",
  "unsupported claim scanner",
  "AccessibilityEvidence.md exporter",
  "JSON evidence exporter",
  "CSV evidence exporter",
  "high-contrast deck sample check",
  "accessibility docs claim boundary",
  "WCAG reference appendix",
  "release no-ship check",
  "accessibility regression test",
].forEach((name) =>
  add(
    `Accessibility Lab: ${name}`,
    "accessibility",
    ids.milestones.rights,
    2,
    [ids.labels.verification, ids.labels.qa, ids.labels.rights, ids.labels.shipBlocker],
    `Build or verify Accessibility Lab capability: ${name}.`,
    standardAcceptance
  )
);

[
  "texture dimension scanner",
  "compression profile scanner",
  "atlas membership scanner",
  "Addressables label scanner",
  "loaded memory estimator",
  "oversized asset warning",
  "duplicate texture warning",
  "unreferenced asset warning",
  "memory report exporter",
  "profiler docs",
  "profiler regression test",
  "mobile budget threshold config",
].forEach((name) =>
  add(
    `Memory profiler: ${name}`,
    "profiler",
    ids.milestones.aplus,
    2,
    [ids.labels.integration, ids.labels.unity, ids.labels.qa],
    `Build or verify memory/readiness profiler capability: ${name}.`,
    standardAcceptance
  )
);

[
  "table center-noise rubric",
  "table brightness balance",
  "table duplicate detection",
  "table mobile crop proof",
  "table source-chain pass",
  "card-back category diversity",
  "card-back duplicate detection",
  "card-back locked overlay pairing",
  "card-back premium review board",
  "card-back source-chain pass",
  "deck front readability proof",
  "deck face-card identity proof",
  "deck suit/rank consistency",
  "deck source-chain pass",
  "asset promotion report",
  "rejected asset exclusion test",
  "AI artifact review checklist",
  "visual QA docs",
].forEach((name) =>
  add(
    `Visual production gate: ${name}`,
    "visual-gate",
    ids.milestones.assets,
    2,
    [ids.labels.production, ids.labels.qa, ids.labels.tables, ids.labels.backs, ids.labels.fronts, ids.labels.shipBlocker],
    `Build or verify visual promotion gate slice: ${name}.`,
    standardAcceptance
  )
);

[
  "solitaire selector recipe polish",
  "poker/blackjack table recipe polish",
  "deckbuilder inventory recipe polish",
  "casual mobile settings recipe polish",
  "locked/unlocked storefront recipe polish",
  "recipe README consistency",
  "recipe manifest validation",
  "recipe scene validation report",
  "recipe screenshot checklist",
  "recipe import smoke test",
].forEach((name) =>
  add(
    `Integration recipes: ${name}`,
    "recipes",
    ids.milestones.framework,
    3,
    [ids.labels.integration, ids.labels.demo, ids.labels.docs],
    `Build or verify integration recipe slice: ${name}.`,
    standardAcceptance
  )
);

[
  "Quick Start screenshot map",
  "installation guide",
  "catalog integration guide",
  "Addressables guide",
  "unlock provider guide",
  "storefront customization guide",
  "Studio guide",
  "Theme Composer guide",
  "Accessibility Lab guide",
  "memory profiler guide",
  "known limitations",
  "support policy",
  "Asset Store listing technical copy",
  "Asset Store FAQ",
].forEach((name) =>
  add(
    `Documentation: ${name}`,
    "docs",
    ids.milestones.framework,
    3,
    [ids.labels.docs],
    `Create or verify documentation slice: ${name}.`,
    standardAcceptance
  )
);

[
  "Unity 2022 clean import checklist",
  "Unity 2022 compile proof",
  "Unity 2022 demo scene smoke test",
  "Unity 6 clean import checklist",
  "Unity 6 compile proof",
  "Unity 6 demo scene smoke test",
  "Built-in render pipeline pass",
  "URP render pipeline pass",
  "mobile performance budget report",
  "no console errors report",
  "release candidate export",
  "final no-ship gate audit",
].forEach((name) =>
  add(
    `Compatibility and release: ${name}`,
    "release",
    ids.milestones.qa,
    2,
    [ids.labels.verification, ids.labels.qa, ids.labels.release, ids.labels.releaseComponent, ids.labels.shipBlocker],
    `Create or verify compatibility/release slice: ${name}.`,
    standardAcceptance
  )
);

async function main() {
  const existingData = await gql(`
    query Existing($projectId: String!) {
      project(id: $projectId) {
        issues(first: 250) {
          nodes { title }
        }
      }
    }
  `, { projectId: ids.project });
  const existingTitles = new Set(existingData.project.issues.nodes.map((issue) => issue.title));

  const createIssue = `
    mutation CreateIssue($input: IssueCreateInput!) {
      issueCreate(input: $input) {
        success
        issue { id identifier title url }
      }
    }
  `;
  const createComment = `
    mutation CreateComment($input: CommentCreateInput!) {
      commentCreate(input: $input) { success }
    }
  `;

  let created = 0;
  let skipped = 0;
  for (const task of tasks) {
    if (existingTitles.has(task.title)) {
      skipped += 1;
      continue;
    }
    const issueData = await gql(createIssue, {
      input: {
        teamId: ids.team,
        projectId: ids.project,
        stateId: ids.todo,
        projectMilestoneId: task.milestone,
        title: task.title,
        description: baseDescription(task),
        priority: task.priority,
        labelIds: task.labels,
      },
    });
    const issue = issueData.issueCreate.issue;
    await gql(createComment, {
      input: {
        issueId: issue.id,
        body: workpad(task),
      },
    });
    created += 1;
    console.log(`${issue.identifier} | ${issue.title}`);
  }

  console.log(JSON.stringify({ created, skipped, templateCount: tasks.length }));
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
