---
name: brunolm-invoice-generate
description: Use this skill when the user wants to generate an invoice for a month. Triggers include "/brunolm-invoice-generate", "generate an invoice", "create my invoice for June", "make the invoice for last month", or any phrasing pairing an invoice with a billing period. Takes an optional month argument like "june", "2026-06", or "last month" (default is the current month) and covers that whole month. Reads private billing details (name, line items, payment info) from `local/invoice-details.md`; if that file doesn't exist it asks the user for the details instead, so no personal information ever lives in the skill itself. Renders the invoice into `local/invoices/` as HTML plus a PDF (via headless Edge) and opens the PDF.
version: 1.0.0
allowed-tools:
  - Read
  - Write
  - AskUserQuestion
  - PowerShell
  - mcp__toggl__me
  - mcp__toggl__list_workspaces
  - mcp__toggl__summary_report
  - mcp__toggl__list_time_entries
  - mcp__harvest__get_time_report
  - mcp__harvest__list_time_entries
---

# Generate invoice

Generate a monthly invoice as a self-contained HTML file. The skill is generic — every piece of personal or business information comes from `local/invoice-details.md` (gitignored) or from asking the user; never hardcode names, prices, or payment details here.

## 1. Resolve the billing month (argument)

The optional argument — the text after the skill name — names the month, matched case-insensitively:

- **(omitted)** — the current month.
- **`2026-06`** / **`06/2026`** — that year-month.
- **`june`** / **`jun`** — that month in the current year.
- **`june 2025`** — that month in that year.
- **`last month`** — the previous calendar month.

The invoice always covers the **whole month** — the 1st through the last day. The user may also state an issue date (e.g. "issue date 07/20"); otherwise the issue date is today.

Do the date math in PowerShell — never by hand:

```powershell
# Set $y/$m from the argument (current month when omitted)
# Set $issue to the user-provided issue date, or today
$start = (Get-Date -Year $y -Month $m -Day 1).Date
$end = $start.AddMonths(1).AddDays(-1)
$issue = (Get-Date).Date
$due = $issue.AddDays(5)
[pscustomobject]@{
  PeriodStart = $start.ToString('MM/dd/yyyy')
  PeriodEnd   = $end.ToString('MM/dd/yyyy')
  IssueDate   = $issue.ToString('MM/dd/yyyy')
  DueDate     = $due.ToString('MM/dd/yyyy')
} | ConvertTo-Json
```

If the argument is unparseable, fall back to the current month and note in one line that it wasn't recognized.

## 2. Load the private details

Read **`local/invoice-details.md`** (relative to the repository root). This file is gitignored, so it can safely hold personal information. Expected content:

```markdown
# Invoice details

## From
Jane Doe

## Invoice for
Acme Corp
Acme Holdings, Inc
billing@acme.example

## Currency
USD

## Items
| Item type | Description                    | Quantity | Unit Price |
| --------- | ------------------------------ | -------- | ---------- |
| Service   | Software development services  | 1        | 5000.00    |

## Pay to
Bank: Example Bank
Account holder: Jane Doe
IBAN: XX00 0000 0000 0000
```

- **From** — the full name shown on the invoice.
- **Invoice for** — who is being billed (client/company/contact); free-form, rendered line by line with the first line as the name.
- **Currency** — optional; default `USD`. Use the matching symbol/code when formatting amounts.
- **Items** — the line items. A description may reference the billing period (e.g. contain `<period>`); replace such placeholders with the resolved dates.
- **Pay to** — free-form; rendered on the invoice **exactly as written**, preserving line breaks.

**If the file doesn't exist**, ask the user for each piece (full name, currency, line items with item type / description / quantity / unit price, and the pay-to block). After collecting the answers, offer to save them to `local/invoice-details.md` in the format above so future runs don't need to ask — but only write it if the user agrees.

If the file exists but is missing a section, ask only for the missing pieces.

## 3. Resolve the billed hours (hourly items)

When an item is billed per hour (e.g. "Rate per hour" with no fixed quantity), its quantity is the hours worked in the billing month. The user provides the source — in the argument, the conversation, or the details file:

- **`from toggl`** — pull the tracked total from the Toggl MCP: `me` for the default workspace (fall back to `list_workspaces`), then `summary_report` for the whole billing month; sum buckets if needed. Toggl durations are in **seconds** — convert to hours.
- **`from harvest`** — pull the tracked total from the Harvest MCP: `get_time_report` (or `list_time_entries`) for the billing month and sum the hours.
- **`from timelog`** — pull the total from the self-hosted time log: `& 'C:\BrunoLM\Projects\time-tracking\time.ps1' report -Month <yyyy-MM>` and use the `Total:` line.
- **a number** — use it as-is.

Round fetched totals to two decimals and state the source and the fetched total in the report.

**If no source was provided, ask** which to use: get from Toggl, get from Harvest, get from the timelog, or enter a number. Fixed-quantity items (e.g. a product with quantity 1) are unaffected.

## 4. Compute the amounts

For each item: `Amount = Quantity × Unit Price`. The **amount due** is the sum of all item amounts. Compute in PowerShell (or with obvious arithmetic double-checked), format with two decimals and thousands separators, and prefix with the currency.

## 5. Render the invoice

Write a single self-contained HTML file (inline CSS, no external assets) to **`local/invoices/invoice-YYYY-MM.html`** (billing year-month). Create the folder if needed. Layout, top to bottom:

1. Top row (flex, space-between): **`INVOICE`** — large title (~34px, letter-spaced) top left; **Issue date** and **Due date** (issue + 5 days) stacked top right, `MM/DD/YYYY`.
2. Parties row (flex, space-between): on the left, **From** — the full name, slightly larger and semibold (~18px) — with **Subject** — `Invoice for <period start> ~ <period end>` (both `MM/DD/YYYY`) — under it; on the right, **Invoice for** — the bill-to block line by line, first line larger and semibold like the From name.
3. Items table with columns: **Item type | Description | Quantity | Unit Price | Amount**. Right-align the numeric columns; make the Amount cells semibold; thin light row separators with a stronger rule under the header; generous vertical margin above and below the table (~56px / ~32px) so it breathes.
4. Below the table, right-aligned, an **Amount due** label with the total under it in the biggest font on the page (~32px, bold): `<currency> <total>`.
5. At the bottom, a **Pay to** section in a subtle light-gray rounded box, with the pay-to block reproduced as-is (preserve its line breaks).

Styling rules that make it read well:

- **Labels vs values** — every label (From, Issue date, Due date, Subject, Amount due, Pay to, table headers) is small, uppercase, letter-spaced, and muted gray (e.g. `#9ca3af`); values are dark (`#111827`) so they stand out.
- **Font-size hierarchy** — total > title > From name > values > table body > labels.
- Clean and printable: white page, standard fonts, sensible margins, and a `@media print` block that drops any page background/shadow so printing to PDF looks right.

Then convert it to **`local/invoices/invoice-YYYY-MM.pdf`** with headless Edge (ships with Windows — no extra dependencies) and open the PDF:

```powershell
$edge = (Get-Command msedge -ErrorAction SilentlyContinue).Source
if (-not $edge) { $edge = @("$env:ProgramFiles (x86)\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1 }
$html = (Resolve-Path 'local/invoices/invoice-YYYY-MM.html').Path
$pdf = [IO.Path]::ChangeExtension($html, 'pdf')
& $edge --headless --disable-gpu --no-pdf-header-footer --print-to-pdf="$pdf" "file:///$($html -replace '\\','/')" 2>$null | Out-Null
Start-Sleep -Seconds 2
if (Test-Path $pdf) { Start-Process $pdf } else { Start-Process $html; 'PDF conversion failed - opened the HTML instead' }
```

Keep the HTML next to the PDF — it's the editable source if the user asks for tweaks.

## 6. Report

End with a one-line summary: the file path, the period, and the amount due. Never echo the pay-to details or other personal data into the conversation beyond what's needed to confirm the invoice was generated.
