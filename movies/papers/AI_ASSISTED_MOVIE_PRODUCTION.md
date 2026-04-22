# AI-Assisted Movie Production

![Voyager educational frame](../docs/assets/voyager_status_story.png)

## Abstract

This note describes how to use AI coding agents as practical collaborators in a lightweight cinematic pipeline. The focus is not on model-generated art in isolation, but on using coding agents to direct, script, edit, document, and maintain a deterministic movie workflow that still renders from the actual simulator.

## Core Claim

The strongest use of AI here is not "press one button and get a perfect film." The strongest use is a division of labor:

- the simulator renders the visuals
- the human defines taste and acceptance
- the coding agent handles iteration, structure, and repeatability

## Roles An AI Agent Can Play

### Director

- propose a shot list
- vary camera language
- choose where a one-minute reel should cut

### Editor

- trim master shots into a final social cut
- remove weak shots from the final reel
- build alternate cuts for different audiences

### Research Assistant

- gather factual notes for educational overlays
- convert research into short timed captions
- keep source notes attached to the project

### Pipeline Engineer

- modify manifests and scripts
- add render presets
- package deliverables and documentation

## Tool-Agnostic Compatibility

This workflow fits well with:

- OpenAI Codex
- Claude Code
- Qwen-Coder style agents

The fit is strong because the workflow is mostly text-first and repo-native. No custom integration layer is required. An agent only needs to:

- read and edit files
- run shell commands
- review outputs

## Recommended Production Flow

1. Human defines the purpose.
2. Agent drafts manifests, captions, or render commands.
3. Engine renders real clips.
4. Agent samples frames and proposes edits.
5. Human approves or rejects.
6. Agent rebuilds the reel and updates docs.

This loop is especially useful for:

- outreach explainers
- classroom supplements
- fandom reels
- rapid social-media teasers

## Good Prompts For Educational Use

```text
Create a factual short film using one rendered master clip. Keep each caption under two short lines, align captions with visible visual changes, and preserve a neutral educational tone.
```

## Good Prompts For Fun Use

```text
Use the Trek master clips to build a one-minute reel with bolder pacing, more formation-flight energy, and no educational overlays.
```

## Human Quality Gates

Even when an agent does most of the repo work, a human should still check:

- factual accuracy
- visual readability
- whether ships are actually visible
- whether scale cheat becomes too obvious
- whether the final cut repeats itself

## Practical Lessons From This Repo

- Recutting from good masters is cheaper than rewriting the engine too early.
- Small MP4 outputs make agent-driven review much easier.
- Documentation matters because future batches benefit from the same pipeline.
- Side-project isolation reduces risk to the main app.

## Conclusion

AI coding agents are most valuable here when treated as disciplined collaborators in a real render pipeline. They are strong at iteration, packaging, and structure. They are weaker at final aesthetic judgment. The best results come from combining agent speed with human direction and a simulator that remains the authoritative renderer.
