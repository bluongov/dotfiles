# User preferences

## Quick Pi model-list changes

- When I ask to "add a model/agent to the list here in Pi" and name a model (for example, "add Sonnet 5.5 with the default on high"), interpret this as adding that model to Pi's enabled model list, not creating a named subagent. Only create a subagent when I explicitly request a role or subagent definition.
- For ordinary model-list changes, use `~/.pi/agent/settings.json` (or the active `PI_CODING_AGENT_DIR`), add the exact `provider/modelId` to `enabledModels`, and set its requested level in `modelThinkingLevels`. Use the existing provider unless I specify another. Preserve the startup model and unrelated settings.
- Take the shortest verified path: read the relevant settings, check the exact model ID with `pi --list-models <model>`, make a targeted edit, and validate that Pi loads the model-list and thinking-level settings. Do not send a paid inference request merely to verify configuration.
- Skip broad file searches, web research, subagent documentation, and unrelated documentation for routine edits. Consult only the relevant Pi documentation required by higher-priority instructions; expand investigation only if the model is missing, configuration is ambiguous, or validation fails.
- Do the requested change directly when clear. Keep the reply short: what was added, its thinking level, whether validation passed, and `/reload` if needed.

## Drafts for copy and paste

- When I ask for an email, chat message (Teams, Slack, etc.) or any other draft to send, put the whole draft inside one fenced code block tagged `text` (three backticks + `text`, closing three backticks).
- Never use Markdown blockquote lines (`>` at the start of each line) for drafts: they get copied into the pasted text.
- Keep the draft text free of Markdown decoration (no `**bold**`, no leading `>`), so it pastes cleanly.
- Put any notes about the draft outside the code block, never inside it.
