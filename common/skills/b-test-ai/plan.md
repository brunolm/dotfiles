# Project: TripLedger

Create a web application in the current directory using create-react-app with the TypeScript template.

TripLedger is a travel expense tracker for trips that involve multiple currencies. Users record what they spend in whatever local currency they paid in, and the app shows everything converted to the trip's home currency.

Each screen has its own URL and works with the browser's back/forward buttons. The finished app must run with `npm start`.

## Trips

- Create a trip with: name, destination, home currency, total budget (in the home currency), start date, end date.
- Edit and delete trips.
- The trips list shows each trip's name, dates, total spent converted to the home currency, and how much of the budget has been used.

## Expenses

- Inside a trip: add an expense with amount, currency, category, date, and an optional note.
- Edit and delete expenses.
- Categories: a built-in set (Food, Transport, Lodging, Activities, Shopping, Other) plus custom categories the user can define.
- The expense list can be filtered by category and by date range, searched by note text, and sorted by date or amount.

## Currency conversion

- Exchange rates come from the Frankfurter API (free, no API key). Base URL: `https://api.frankfurter.dev/v1`
  - `GET /currencies` — supported currencies
  - `GET /latest?base=USD` — today's rates
  - `GET /2026-05-20?base=USD&symbols=EUR,JPY` — rates on a given date
- An expense is converted to the trip's home currency at the exchange rate of the expense's date.
- The dashboard has a toggle to instead convert everything at today's rates.

## Dashboard (per trip)

- Total spent in the home currency and budget remaining.
- Spending broken down by category.
- The 5 largest expenses.
- Average spending per day of the trip so far.

## Settings

- Default home currency used when creating new trips.
- Manage custom categories (add, rename, delete).

## Data

- All data survives page reloads and browser restarts.
