---
name: b-table
description: Use this skill when the user prefixes a task with "/b-table" or asks for results in a table. Triggers include "/b-table test a curl on 5 websites", "/b-table compare these 3 services", "/b-table show me the results before and after", "put that in a table", "give me a table of X", or any phrasing pairing a task with tabular output. Everything after the trigger is the actual task — perform it normally, then present the results as a Markdown table where each row is one item and each column is one measured or compared attribute.
version: 1.0.0
---

# Present Results as a Table

The text after `/b-table` is the real task. Do that task exactly as you normally would — run the commands, fetch the data, make the comparison. This skill only changes how the results are delivered: the centerpiece of the final answer must be a Markdown table.

## Steps

1. Perform the requested task. Nothing about execution changes — only the output format.
2. Identify the rows: one row per item being tested, compared, or measured (a domain, a service, a file, a run, a metric).
3. Identify the columns: the item identifier first, then one column per attribute worth comparing (result, status, latency, size, before, after, notes...). Only include columns where values actually differ or matter — drop columns that would read the same on every row.
4. Render a Markdown table and make it the centerpiece of the final answer.
5. Add at most a sentence or two of prose around the table: lead with the takeaway (e.g. "4 of 5 responded, one returned 404"), and put any detail that doesn't fit a cell (error messages, caveats) below the table as prose or footnotes — not crammed into cells.

## Table rules

- First column identifies the item (Domain, Service, File, Metric...). Give every column a clear header.
- Use a consistent vocabulary down each column so rows scan easily (don't mix `ok` / `success` / `200 OK` in one column).
- "Before and after" tasks get `Before` and `After` columns (plus a `Change`/`Diff` column when the delta is the point).
- Comparison tasks: prefer one row per item and one column per criterion. Flip the axes only if there are many criteria and few items and the table would otherwise be too wide.
- If an item failed, it still gets a row — record the failure in the result column rather than omitting it.
- Multiple unrelated result sets get multiple small tables, each with a short heading — not one franken-table.
- If the result is genuinely not tabular (a single value, free-form prose), say so briefly and give the closest useful summary instead of forcing a fake table.
