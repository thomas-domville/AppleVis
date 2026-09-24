# AppleVis Shared Agent Instructions

Claude's AppleVis project memory is the shared source of truth for durable project rules and history:

`C:\Users\thoma\.claude\projects\c--Users-thoma-dev-AppleVis\memory\MEMORY.md`

Before changing this project, read that index and every linked memory relevant to the task. Treat its feedback rules as standing instructions, including when the user does not repeat them in the current conversation.

For every user-facing change:

- Preserve VoiceOver, Braille display, Switch Control, Dynamic Type, contrast, Reduce Motion, and the other established accessibility behavior.
- Check every new or changed user-facing string with `tools/l10n_audit.py` and translate it into all 22 supported non-English languages in the same pass.
- Add an appropriately tagged `ChangeItem` to `AppleVis/Sources/Views/Info/WhatsNewView.swift` when the change is visible or meaningfully changes behavior.
- Check `HelpContent.swift`, `GuidedExperience.swift`, and `TipStore.swift` for related wording or instructions, and update them when the change affects what they describe.
- Follow the established AppleVis house voice and long-form editorial style recorded in memory.

Do not expose credentials or other secrets found in memory or local configuration. When a new durable preference or project rule is established, keep the shared memory current rather than relying only on chat history.
