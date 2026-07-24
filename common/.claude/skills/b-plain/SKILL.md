---
name: b-plain
description: Use this skill when the user wants prose written or rewritten in plain English following six plain-writing rules. Triggers include "/b-plain", "write this plainly", "apply the writing rules", "review this prose", "make this doc/PR/message plainer", or any phrasing that pairs prose output (docs, PR text, commit messages, emails, replies) with plain-language quality. Governs prose only — never code or technical terms.
version: 1.0.0
---

# Plain Prose

These rules govern prose: docs, PR text, messages, emails, replies. Never touch code, identifiers, or technical terms; swap in everyday words only where precision survives.

## The rules

1. Never use a metaphor, simile or other figure of speech which you are used to seeing in print.
2. Never use a long word where a short one will do.
3. If it is possible to cut a word out, always cut it out.
4. Never use the passive where you can use the active.
5. Never use a foreign phrase, a scientific word or a jargon word if you can think of an everyday English equivalent.
6. Break any of these rules sooner than say anything outright barbarous.

## How to apply

- **Scope: prose only.** Code blocks, inline code, identifiers, API names, error messages quoted verbatim, and established technical terms (e.g. "idempotent", "mutex") stay untouched. A technical term is only replaced when an everyday word carries the exact same meaning.
- **When writing:** draft the prose, then review it against the six rules before delivering. Fix what fails; deliver the revised version only.
- **When reviewing/rewriting existing text:** go through it rule by rule, propose the plainer version, and note which rule drove each change if the user asks.
- Rule 6 wins conflicts: if applying a rule makes the sentence awkward, unclear, or wrong, leave it.

Review every prose output against these rules before delivering.
