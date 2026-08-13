---
name: b-video-finder
description: Use this skill when the user wants to find videos matching specific content criteria, verified by actually opening each video and inspecting frames. Triggers include "/b-video-finder", "find me N videos that show X", "search <site> for videos containing X", "look for videos with X", or any phrasing pairing video search with must-have visual criteria. Drives a real browser via the patchright MCP, screenshots each candidate at several timestamps, scores every candidate S/A/B/C/D against the criteria, keeps searching until the target count at the minimum rating is met (default 10 at B or better), then writes and opens an HTML report table (platform, thumbnail, title, duration, rating, tags).
version: 1.20.0
allowed-tools:
  - mcp__patchright__browser_navigate
  - mcp__patchright__browser_navigate_back
  - mcp__patchright__browser_snapshot
  - mcp__patchright__browser_take_screenshot
  - mcp__patchright__browser_click
  - mcp__patchright__browser_type
  - mcp__patchright__browser_press_key
  - mcp__patchright__browser_evaluate
  - mcp__patchright__browser_run_code
  - mcp__patchright__browser_wait_for
  - mcp__patchright__browser_tabs
  - mcp__patchright__browser_close
  - PowerShell
---

# Video finder

Find videos that actually contain what the user asked for - not videos whose *title* claims to. Search one or more video platforms with the patchright browser MCP, skip obvious misses from metadata, rank the rest by what their result-page thumbnails show, open those, capture frames, judge those frames against the criteria, and score the match. Keep going until enough videos meet the bar, then deliver an HTML report.

## What the user specifies

Parse these from the text after the skill name (all optional except criteria):

- **Target** - how many videos at what minimum rating, written like `10 B+` (count + rating + `+` meaning "or better"). Default: **10 at B or better**.
- **Platform(s)** - one or more sites to search (e.g. "on youtube", "youtube and vimeo"). Default: **any** - pick the platforms most likely to host the kind of content described.
- **Batch** - how many videos to capture before scoring that set, written like `batch 5`. Default: **5**.
- **Criteria** - the must-have elements a video needs to show. This is required; if the request has no discernible criteria, ask what to look for before opening the browser.

## Setup

Create a per-run temp folder under the workspace `.tmp` (patchright cannot write outside the workspace):

```powershell
$runDir = Join-Path (Join-Path (Get-Location) ".tmp") ("b-video-finder-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $runDir -Force | Out-Null
$runDir
```

Save every screenshot into `$runDir` as JPEG (`type: "jpeg"`) with a name that encodes candidate + timestamp (e.g. `03-yt-abc123-t120.jpg`). JPEG is smaller and faster to round-trip than PNG.

Platform notes live outside this skill so they can name hosts without bloating SKILL.md:

```powershell
$notes = Join-Path $env:USERPROFILE ".local\share\b-video-finder\platforms.md"
```

If that file exists, read it before searching and apply any section whose host you are about to open.

At the end of the run, upsert **one short section per host** you actually used. Replace that host's previous section; do not append a diary. Create the parent folder if needed. Store mechanical facts only: search URL shape, how to read a result card, how to start the player, how to seek, which overlay dismisses, what failed and what worked instead. Do not store queries, titles, video URLs, criteria, or anything about the content. Do not copy these notes into SKILL.md.

```markdown
# youtube.com
- search: /results?search_query=
- cards: title from the video-title link, not the thumbnail
- player: click once, wait until video.duration is finite, then currentTime seek
- overlays: consent button on the banner
```

## Hard limits

- **Single tab.** Do all navigation in one tab. If a click spawns a new tab, close it and `browser_navigate` to the URL directly instead.
- **At most 30 seconds per video**, total wall-clock from navigating to it until the probe returns. The budget wins over extra frames. If a video won't load, won't seek, or hits DRM/region walls inside the budget, score whatever files exist (or `C` if none) and move on - never burn the budget retrying.
- **One probe script per video.** After navigate, one `browser_run_code` captures every frame and returns. Do not split the probe into per-timestamp `evaluate` / `take_screenshot` calls, and do not build a helper library around it.
- **Do not wait for page idle.** Do not wait for `networkidle`, a quiet network, ads, or related rails. Poll the `<video>` immediately and start capturing as soon as `readyState >= 2` and `duration` is finite. If you `page.goto` inside the probe, use `waitUntil: 'domcontentloaded'` - not `'load'` or `'networkidle'`.
- **Cap every wait inside the probe.** Playwright's default timeout is 30s per action - one uncapped `locator.screenshot()` exceeds the video budget. Pass an explicit timeout of a few seconds on `goto`, click, and screenshot. Screenshot with `animations: 'disabled'` (player chrome never goes stable). Await `video.play()` with a 2s timeout only when media is already attached. If a platform needs the `seeked` event, race it against a few hundred milliseconds, then capture. Return whatever you have.
- **Dismiss cookies, banners, and other overlays** that block the player or search results before interacting or screenshotting. Match the overlay's own controls (role, visible label on the banner). Do not click a result title or other page text just because it contains "accept" / "ok".
- **Abandon stuck scripts.** If that probe hangs or errors, don't retry it - switch method: seek by clicking positions on the player's seek bar, or use keyboard shortcuts (arrow keys, digit keys jump to 10%/20%/... on many players), and screenshot whatever frame that lands on. Keep those files in the current batch and score them with the rest (section 4).

## 1. Search

For each platform:

1. Navigate to the platform's search results for a query derived from the criteria. The first phrasing is a guess - the same words often name a different arrangement on that platform. Keep 2-3 phrasings ready (the specific arrangement, plus a broader query that still has the same people or setting). If the first page is mostly a different reading of the words, reword immediately; do not drain a bad list.
2. Extract candidates from the results (one short evaluate can return URL, title, duration, thumbnail, and tags as JSON). Read the title from the card's title/name text, not from thumbnail markup. Drop non-result links (watch-later, channel rails, ads).
3. **Skip from metadata before opening.** If title, duration, or tags already fail a hard criterion (too short, wrong genre, compilation when a single scene is required, sequential wording like "then" when the criterion is a simultaneous arrangement, etc.), do not open that video. Skipped-from-metadata videos are not verified and do not go in the report.
4. **Rank from the results screenshot.** After the metadata skip, screenshot the visible results grid as JPEG into `$runDir` (e.g. `search-yt-1.jpg`) and read that file. Do not wait for thumbs to finish loading. Order the remaining candidates by how clearly the on-page thumbnail shows the criteria - likely hits first. Skip a card only when its thumbnail clearly contradicts a hard visual criterion (wrong body, wrong setting, the opposite arrangement). An ambiguous, cropped, or logo/poster thumb is not a skip: keep it, just don't lead with it. A thumbnail is ranking evidence, not a score - do not put thumb-only videos in the report. If the thumbs are still placeholders, keep metadata order.
5. Related / recommended / up-next cards come back on the probe result, plus one JPEG of that rail when the probe captured it. When a score meets the bar, prefer those URLs next. Rank them from the related-rail shot the same way as a results grid (step 4) before prepending.

Then probe the ranked list in batches (section 3).

Go back for more (next result page, reworded query, next platform) when the current result list is exhausted or is clearly the wrong reading of the query. Rank each new results page the same way before probing it.

## 2. Handle login walls

Some sites gate playback or search behind login. When that happens:

- Click the **Sign in with Google** option and choose my account.
- If Google asks for a password, 2FA, or any challenge the browser session can't answer, pause and tell the user to complete the login in the browser window, then continue.
- Don't create accounts, and don't dismiss-and-retry around a hard login wall - log in or skip the platform.

## 3. Verify candidates

Judge with player frames, not titles or thumbnails - but only after a video survived the metadata skip and any clear thumb contradiction.

Probe first, score later, **batch** videos at a time (default 5).

**Probe.** For each candidate in the batch, within the 30-second budget:

1. Navigate to the video (or `page.goto` with `waitUntil: 'domcontentloaded'` inside the probe). Do not wait for the page to go idle after that.
2. Run **one** `browser_run_code` that does the whole capture and returns:
   - Start the player, then leave as soon as it can seek:
     1. Click the **player surface** (the player container or its visible play overlay), not the `<video>` node. A `<video>` with no `src` often has no box or is a noscript fallback - that click will not start HLS. Prefer the container's center (`boundingBox()` + `mouse.click(cx, cy)`), or `locator(container).click({ timeout: 2000 })`.
     2. Poll until `readyState >= 2` **and** `duration` is a finite number, or 2s elapses. A `<video>` node existing is not ready. Empty `currentSrc` / `readyState === 0` means media was never attached.
     3. If media is still not attached, press Space (or click the visible play control) and poll again for 2s. Do not reload yet.
     4. If media is attached (`currentSrc` set, `readyState >= 2`) but the video is paused, `await video.play()` with a 2s timeout. Do not call `play()` on an empty `<video>`.
     5. Reload the page once (`waitUntil: 'domcontentloaded'`) only if the player container is missing from the DOM. Do not reload to retry the same click.
     6. Continue. Do not wait for the rest of the page.
   - Read duration from `document.querySelector('video').duration` - not from a duration badge elsewhere on the page (those are often a related video or an ad).
   - If `duration` is not finite, do **not** capture a single `t=0` poster and return. Inside this same probe, take five fallback frames: digit keys `1` / `3` / `5` / `7` / `9`, or clicks at ~10% / 30% / 50% / 70% / 90% on the seek bar. Then return whatever you have.
   - Pick probe timestamps: **5 by default**, at ~10% / 30% / 50% / 70% / 90% of the duration. If the criterion is a specific arrangement that is usually a later beat, not the opening, bias the back half and always keep one late probe (~90%). Longer videos get more - one extra frame per 10 minutes after the first 10 minutes - as many as the 30-second budget allows. A compilation or long video cannot be confirmed from a handful of cuts: rate only the frames you captured.
   - For each timestamp: set `video.currentTime`, then screenshot the player (the `<video>` node or its player container), not the full page, as JPEG into `$runDir` (name encodes candidate + timestamp). Use `animations: 'disabled'` and a short timeout. Fall back to a viewport shot only if the player shot fails or is empty. No wait between seeks (if you race `seeked`, cap it at a few hundred milliseconds). If a write is empty or tiny, one immediate retry of that timestamp.
   - Take **one** JPEG of the related / up-next section if that container is already in the DOM (e.g. `03-yt-abc123-related.jpg`). Screenshot the rail node, not the player. Do not wait for it to load, do not scroll the page to find it, and do not retry if it is missing or empty. Do not add this file to `paths` - it is ranking input, not a scored frame.
   - Also collect `meta[property="og:image"]` and the related / up-next cards (url, title, duration, thumb) if they are already in the DOM. Do not wait for that rail to finish loading.
   - Return `{ duration, paths, thumb, related, relatedShot }`.
3. Hold the result. Do not score yet. Go to the next candidate in the batch.

If the player blocks seeking, keep whatever frames you got (poster frame, early playback). Stop the probe pass when the batch is full or the plausible list is empty.

**Score.** After the probe pass, score every held result (section 4). If the target is not met, start another probe batch (prefer related URLs from hits). Do not start another batch once scores already meet the target. Score any videos already captured in the current batch even if a later one in that batch would have been enough.

## 4. Score

Read the JPEG paths yourself and score them against the table below. Do not treat a bumper / slate / trailer card as evidence. After each score, append one line to `$runDir/log.txt` (url, title, duration, rating) and, if the score meets the bar, prepend that video's `related` list to the candidate queue (ranked from that video's related-rail shot per section 1).

| Rating | Meaning |
|--------|---------|
| **S** | Perfect match - all criteria clearly visible, high certainty |
| **A** | Match with high certainty - criteria present, minor ambiguity |
| **B** | Confident match - criteria appear present but evidence is partial |
| **C** | Probably not a match - weak or contradicting evidence |
| **D** | Not a match |

The same people or setting without the asked-for arrangement is not a match. One ambiguous still of a similar-looking setup is at most **B**. The title naming the criterion is not evidence.

Stop starting new probe batches when scores meet the target (e.g. 10 videos rated B or better). If candidates and reasonable query variations are exhausted, report the shortfall honestly rather than inflating ratings.

## 5. Report

Write a self-contained dark-theme HTML file to `$runDir` and open it in the default browser. One table, rows sorted best rating first (S -> D), columns:

| # | Platform | Thumbnail | Title | Duration | Rating | Tags |

- **Thumbnail** - the platform's thumbnail URL when you captured one, else a relative path to one of the run's screenshots.
- **Title** - a clickable link to the video URL (`target="_blank"`).
- **Rating** - the letter plus the one-line justification underneath in smaller muted text.
- **Tags** - your classification labels, comma-separated.

Include every candidate you actually verified - the below-threshold ones too, so the user can see what was rejected and why. HTML-escape titles and attribute values; write the file UTF-8; `Start-Process` it; print the path.

Finish the terminal side with a one-line summary: how many videos met the bar out of how many verified, and per-platform counts.
