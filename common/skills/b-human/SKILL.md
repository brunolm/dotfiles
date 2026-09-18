---
name: b-human
description: Use this skill when the user wants something said in plain, human language instead of technical output. Triggers include "/b-human", "explain that in human", "say that like a human", "what does that mean in plain english", "translate that for me", or any phrasing pairing a message or request with wanting it in everyday words. With no argument it re-explains the most recent message in the conversation in plain language; with an argument it answers that request in plain language.
version: 1.0.0
---

# Answer in Human Language

Two modes, decided by whether anything follows `/b-human`:

- **No argument** — explain the latest message in the conversation in plain human language. That is the most recent substantive message: the assistant's last reply, or, if the assistant hasn't spoken yet, the user's last message. Do not do new work; just make what was already said understandable.
- **With an argument** — the text after the trigger is the real request. Do that task exactly as you normally would, then deliver the answer in plain human language.

## Rules

- Write like you're explaining it out loud to a smart friend who doesn't work on this code. Short sentences. Everyday words.
- Lead with the point — what happened, what it means, or what to do — then add detail only if it changes the reader's understanding.
- Replace jargon with the thing it means. If a term is unavoidable (a real file name, a command the user must type, a product name), keep it and explain it in a few words the first time.
- No code blocks, no diffs, no tables, no file-path-and-line-number references, no commit hashes, unless the user literally has to type or click the thing.
- No lists of every step taken. Explain outcomes and reasons, not the process.
- Don't dumb down the facts. Accuracy first: if something failed, is uncertain, or has a catch, say so in plain words rather than smoothing it over.
- Keep it short — a few sentences for simple things, a short paragraph or two at most. If the topic really needs more, use plain prose with at most a few simple bullets.
- No preamble about the explanation itself ("In simple terms...", "Let me break this down..."). Just say the thing.

## Steps

1. Check for an argument after `/b-human`.
2. No argument: read the latest message, work out what it actually says and what matters about it, and restate it in plain language. Gather nothing new unless the message can't be understood without a quick look (then read only what's needed).
3. With an argument: perform the request normally, using whatever tools it needs. Only the final answer changes — it goes out in plain language.
4. Before sending, reread the draft and cut anything a non-engineer would skim past.

## Examples

`/b-human` right after a reply about a path-limited commit -> "I saved just that one file's change and sent it up to GitHub. The big pile of other pending changes is still sitting there, untouched."

`/b-human why is the build slow` -> investigate as usual -> "Every build re-downloads the dependencies from scratch because nothing is being cached. First fix is turning the cache back on, which should cut it roughly in half."
