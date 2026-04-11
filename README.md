# India Election Compass · இந்தியா தேர்தல் திசைகாட்டி

A non-partisan, open-source voter information tool for Indian elections.  
Answer policy questions and discover which party or candidate best represents your views.

**Live site:** https://darepalli.github.io/ElectionDiksoochi/

---

## Overview

India Election Compass presents policy theses — clear, testable statements on governance, health, education, economy, language, and more. Users rate each thesis and the tool calculates which party or candidate position set is the closest match.

- No personal data is collected or stored — all scoring is done in-browser
- Multilingual by election config: currently English + Tamil (TN), and English + Bengali (WB preview)
- Alliance-aware: sub-party positions within an alliance can be shown individually
- Source citations are displayed inline for every position statement

---

## Current Elections

| State | Election | Status |
|---|---|---|
| Tamil Nadu | State Assembly 2026 | ✅ Live |
| Tamil Nadu | All 234 Constituencies | 🔜 Coming Soon |
| West Bengal | State Assembly 2026 (Preview) | 🧪 Preview Live |

---

## Repository Structure

```
india-election-compass/
│
├── index.html                  Hub page — lists all available elections
├── compass.html                Main compass interface (shared across all elections)
├── party-form.html             Form for parties/candidates to submit their positions
├── resources.html              Methodology & data sources transparency page
│
├── admin/
│   └── review.html             Admin tool for reviewing and merging position submissions
│
├── assets/
│   ├── hub.css                 Styles for index.html / resources.html / party-form.html
│   ├── compass-devtools.css    Dev/debug UI styles (only active with ?debug=1 or dev modes)
│   ├── compass-devtools.js     Dev tools: debug panel, random-results preview, party-positions table
│   ├── open-election-compass.umd.min.js  OEC library (bundled, no CDN dependency)
│   └── favicon.svg
│
├── elections/
│   ├── tn/
│   │   ├── 2026-state/
│   │   │   └── config.json     TN 2026 State Assembly election data
│   │   └── constituencies/
│   │       ├── index.html      Constituency list / preview page
│   │       ├── constituencies.json
│   │       └── {name}/         One directory per constituency (234 total)
│   └── wb/
│       └── 2026-state/
│           └── config.json     WB 2026 State Assembly preview data
│
├── _templates/
│   ├── config-state.json       Annotated template for a new state-level election
│   └── config-constituency.json  Annotated template for a constituency-level election
│
└── .github/
    └── workflows/
        └── deploy-pages.yml    GitHub Actions: auto-deploys main branch to GitHub Pages
```

---

## How It Works

The compass is a static site with no backend. The flow is:

1. User opens the hub (`index.html`) and selects an election
2. They are redirected to `compass.html?config=elections/{state}/{election}/config.json`
3. `compass.html` fetches the config JSON, passes it to the embedded [OpenElectionCompass](https://open-election-compass.com) library, and adds a custom UI layer on top
4. The user answers policy theses and gets a match result
5. In pagewise mode, users can choose up to 3 priority areas directly on Page 1 (no popup), then continue to area-by-area response pages
6. A **Party Links** panel appears (top-right/menu) with alliance or party links and seat-share visual context when applicable; if all listed groups contest the full seat count, seat numbers/sources are intentionally hidden for cleaner display
7. Users can also open **Party Positions** for a full issue-by-issue tabular view

---

## Running Locally

No build step required — this is a plain static site.

```bash
# Python
python -m http.server 8080

# Windows (Python launcher)
py -m http.server 8080

# Node.js
npx serve .
```

Then open `http://localhost:8080` in your browser.

> **Note:** Loading a config works correctly only from `localhost` or `127.0.0.1` because the compass auto-selects the default config only on localhost. On file:// origins some fetch requests may be blocked by the browser.

---

## URL Parameters

| Parameter | Values | Description |
|---|---|---|
| `config` | `elections/tn/2026-state/config.json` | Load a specific election config |
| `lang` | `en` · `ta` · `bn` | Set UI language (persisted in localStorage; available languages depend on election config) |
| `partypositions` | `1` | Show full issue-by-issue party positions table |
| `viewmode` | `tabular` | Used alongside `partypositions=1` |
| `debug` | `1` | Show debug log panel (any host) |
| `randomresults` | `1` | Simulate random user answers and show scored results — **localhost only** |

Example — Tamil UI + party positions table:
```
compass.html?config=elections/tn/2026-state/config.json&lang=ta&partypositions=1&viewmode=tabular
```

---

## Adding a New Election

### 1. State-level election

Copy `_templates/config-state.json` to `elections/{state}/{year-level}/config.json` and fill in:

- `languages` — language codes (e.g. `en`, `ta`, `kn`)
- `parties` — one entry per party or alliance, with `alias`, `name`, `short`, `description`
- `theses` — 10–20 policy statements with `title`, `statement`, and `positions` for each party
- Each party position entry supports:
  - `position` — `approve` · `partly` · `neutral` · `reject` (or strongly- variants)
  - `explanation` — bilingual text explaining the party's stance
  - `source` — URL to a public source document
- `alliancePartnerSeats` — seat allocation per alliance partner (shown in the sidebar panel)
- `allianceMetadata` — display labels and member lists for each alliance

Then add a card to `index.html` pointing to:
```
compass.html?config=elections/{state}/{year-level}/config.json
```

### 2. Constituency-level election

Copy `_templates/config-constituency.json`. At constituency level, the `parties` array represents **individual candidates** (one entry per candidate). Thesis positions should cover both local issues and relevant state/national issues.

---

## Party Position Submission Workflow

To collect positions from parties or campaigns:

1. Direct them to **`party-form.html`** on the live site
2. They fill in party/candidate details and rate each thesis with a position + explanation
3. They download a `.json` file and email it to the admin
4. Admin opens **`admin/review.html`**, loads the submission JSON alongside the current config, reviews/edits positions inline, then downloads the merged config for deployment

The election selector in `party-form.html` includes both TN and WB state-level entries, plus live TN constituency entries.

---

## Configuration Reference

The key fields in a `config.json`:

```json
{
  "version": "1",
  "algorithm": "hybrid",
  "languages": [{ "name": "English", "code": "en" }],
  "title":    { "en": "Election Name" },
  "subtitle": { "en": "Subtitle" },
  "introduction": {
    "heading": { "en": "..." },
    "text":    { "en": "..." }
  },
  "parties": [
    {
      "alias":       "party-slug",
      "name":        { "en": "Full Party Name" },
      "short":       { "en": "ABBR" },
      "description": { "en": "2-3 sentence factual background." },
      "profile":     { "en": "https://link-to-candidate-profile" }
    }
  ],
  "theses": [
    {
      "title":     { "en": "Short Label" },
      "statement": { "en": "Clear, testable policy statement." },
      "positions": {
        "party-slug": {
          "position":    "approve",
          "explanation": { "en": "Why this party supports it." },
          "source":      "https://source-url"
        }
      }
    }
  ],
  "alliancePartnerSeats": {
    "alliance-alias": [
      { "code": "PARTY", "name": "Party Name", "symbol": "🏷", "seats": 100, "source": "https://..." }
    ]
  },
  "allianceMetadata": {
    "alliance-alias": {
      "majorMembers":   ["PARTY1", "PARTY2"],
      "displayMembers": { "en": ["Party One", "Party Two"] }
    }
  }
}
```

**`algorithm`** options:
- `hybrid` — 5 response buttons (strongly agree → strongly disagree); best discrimination
- `cityblock/approve-neutral-reject` — 3 buttons

Party positions always use `approve` / `neutral` / `reject` regardless of the user-facing algorithm.

---

## Tech Stack

| Component | Details |
|---|---|
| Core library | [OpenElectionCompass](https://open-election-compass.com) (Vue, bundled UMD) |
| Custom layer | Vanilla JS + CSS in `compass.html` |
| Dev tools | `assets/compass-devtools.js` — debug panel, random-results & party-positions renderers |
| Hosting | GitHub Pages via GitHub Actions (`deploy-pages.yml`) |
| Languages | English, Tamil, Bengali (config-driven; architecture supports any BCP-47 language) |
| Dependencies | None — no npm, no bundler, no build step |

---

## Contributing

Contributions are welcome for:

- **New elections** — add a config for any Indian state or constituency
- **Data accuracy** — correcting or sourcing party positions
- **Translations** — Tamil translations of UI labels are in `compass.html`; other languages welcome
- **Features** — improve the compass UI, admin tools, or submit form

Please open an issue or pull request at https://github.com/darepalli/ElectionDiksoochi.

---

## License

Open source. Non-partisan. Built for civic information only.  
The embedded OpenElectionCompass library is used under its own [open-source license](https://open-election-compass.com).
