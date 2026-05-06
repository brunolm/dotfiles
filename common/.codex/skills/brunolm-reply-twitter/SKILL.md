---
name: brunolm-reply-twitter
description: Use this skill when the user asks to find and answer their `!claude` tweets, or says things like "answer my claude tweets", "reply to my !claude posts on twitter/x", "check for unanswered !claude tweets", or any phrasing that pairs Twitter/X with `!claude`. Searches @BrunoLM7's tweets for posts containing the literal trigger `!claude` that have no reply from @BrunoLM7 yet, gathers the full thread context, researches when needed, drafts a reply that matches the parent tweet's tone (<= 280 characters, hard limit), confirms with the user, and posts.
version: 1.0.0
allowed-tools:
  - mcp__patchright__browser_navigate
  - mcp__patchright__browser_snapshot
  - mcp__patchright__browser_click
  - mcp__patchright__browser_type
  - mcp__patchright__browser_evaluate
  - mcp__patchright__browser_press_key
  - mcp__patchright__browser_wait_for
  - WebSearch
  - WebFetch
---

# Reply to !claude tweets

Find tweets from @BrunoLM7 that contain the literal trigger `!claude` and have no reply from @BrunoLM7 yet, then craft and post a reply that matches the parent tweet's tone.

Requires the `patchright` MCP. The user must already be signed in to x.com in the controlled browser session.

## 1. Find candidate tweets

Navigate to the search page:

```
https://x.com/search?q=from%3Abrunolm7%20%22%21claude%22&src=typed_query&f=live
```

The `%22...%22` quoting is required - without it X strips the `!` and matches every tweet that mentions "claude".

Read every `<article>` and keep tweets whose `[data-testid="tweetText"]` contains the literal substring `!claude` (case-sensitive). Build a list of candidate status URLs.

```js
;() =>
  Array.from(document.querySelectorAll('article'))
    .map((a) => ({
      url: a.querySelector('a[href*="/status/"]')?.href,
      text: a.querySelector('[data-testid="tweetText"]')?.innerText,
    }))
    .filter((t) => t.text?.includes('!claude'))
```

## 2. Filter to unanswered tweets

For each candidate, navigate to its page and read every article on the page (scroll once to load replies). The candidate is **unanswered** if no article authored by `@BrunoLM7` appears as a reply below it. If @BrunoLM7 has any reply below the trigger tweet, skip - it is already handled.

Process surviving candidates oldest-first.

## 3. Capture full thread context

For each unanswered candidate, capture:

- The **root** tweet (top of the conversation).
- Every **intermediate** tweet in the chain - other authors and BrunoLM7's prior replies.
- The **trigger** tweet itself. The user often appends a directive (`!claude answer this`, `!claude what do you think`, `!claude explain`). Treat the directive as steering for the reply.
- Whether the root or any intermediate tweet has **media** - the user often triggers on image-based prompts (e.g. "Which one had the best ending?" with an image grid). Note media presence; if the answer hinges on the image content, say so to the user before drafting.

Use `browser_evaluate` to dump:

```js
;() =>
  Array.from(document.querySelectorAll('article')).map((a) => ({
    url: a.querySelector('a[href*="/status/"]')?.href,
    author: a.querySelector('[data-testid="User-Name"]')?.innerText?.split('\n')[0],
    text: a.querySelector('[data-testid="tweetText"]')?.innerText,
    hasMedia: !!a.querySelector('img[alt="Image"], video'),
  }))
```

## 4. Research (only when needed)

Skip research entirely for opinion-only prompts ("which is best?", "what do you think?"). Research when the answer needs verifiable specifics:

- A person's status, role, or recent activity.
- A product/feature/version that may have changed since training.
- A date, price, schedule, release window.
- A claim about a named public event.

Use `WebSearch` first; reach for `WebFetch` only when a specific page is needed for detail. Do not cite sources inside the tweet - characters are precious and the audience is conversational. Keep sources for the chat-side report only.

## 5. Draft the reply

Match the parent tweet's tone:

- **Casual / vent / opinion** -> reply casual, contractions OK, no markdown, no headers.
- **Technical question** -> reply factual, lead with the answer, keep one short caveat if uncertain.
- **Banter / one-liner** -> punchy, one sentence is fine.

Hard rules:

- **280-character limit**, hard. Count the draft (including spaces and any em dashes) before showing the user. If over, trim - do not split into a thread.
- Lead with the substantive answer. No "Great question...", no "I think...".
- Don't quote the parent tweet back at the user - they wrote it.
- No hashtags.
- No greeting and no leading `@` mention - X auto-prepends mentions on replies.
- No prefix tags or markers - write the reply as the user would.

If the trigger directive narrows scope ("answer this", "explain it", "what do you think of X"), follow it. If vague, default to addressing the most recent BrunoLM7 tweet in the chain.

## 6. Safety self-check (no user confirmation)

Do not ask the user to confirm. Post directly after a quick self-check on the draft:

- **Mean-spirited?** Reject if the reply mocks, demeans, insults, or attacks the parent author or anyone named in the thread. Disagreement is fine; ad hominem is not.
- **Excessive profanity / slurs?** Reject if the draft contains extreme slurs, or extreme profanity used as more than mild emphasis. A single mild expletive that fits the parent's tone is OK; sexual profanity, or anything targeting a group is not.
- **Defamatory or unverified personal claims?** Reject if the draft asserts a verifiable claim about a named person that you did not confirm via research in step 4.

If the draft fails any check, rewrite it once and re-check. If it still fails, skip this candidate and report why in the final summary. Do not loop indefinitely - one rewrite attempt, then skip.

## 7. Post the reply

Once the self-check passes:

1. Confirm the page is on the trigger tweet (`https://x.com/BrunoLM7/status/<id>`).
2. Click the inline reply textbox (`[data-testid="tweetTextarea_0"]`).
3. `browser_type` the approved text.
4. Verify it landed and the Reply button is enabled:

   ```js
   ;() => {
     const ta = document.querySelector('[data-testid="tweetTextarea_0"]')
     const btn = document.querySelector('[data-testid="tweetButtonInline"]')
     return { text: ta?.innerText, enabled: !btn?.disabled && btn?.getAttribute('aria-disabled') !== 'true' }
   }
   ```

5. Click `[data-testid="tweetButtonInline"]`.
6. Re-read articles on the page; the new article authored by @BrunoLM7 below the trigger confirms the post. Capture its status URL.

If the harness denies the click, do not retry silently - surface the denial and the drafted text to the user so they can click in their own browser or grant permission. This is the only point where user interaction is expected.

## 8. Loop

After each successful post (or skip), return to the candidate list and continue until all unanswered `!claude` tweets are handled. End with a one-line summary: count posted, count skipped (with reason), and links to the new replies.
