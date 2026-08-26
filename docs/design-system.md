# Design System Manifest

This document is the visual source of truth for `html2rss-web`.

If you change the UI, read this first. If a design decision is not reflected here, update this file in the same change. The goal is to prevent slow visual drift between the app shell, result flow, and RSS/XSL presentation.

## Core Rule

There is one shared design language and one shared primitive layer.

- Shared primitives live in [public/shared-ui.css](../public/shared-ui.css).
- App-specific composition lives in [frontend/src/styles/main.css](../frontend/src/styles/main.css).
- Feed-specific composition lives in [public/rss.xsl](../public/rss.xsl).
- Journey **chrome** copy lives in [frontend/src/journey/copy.ts](../frontend/src/journey/copy.ts): titles, buttons, local validation, loading labels, and aria (one string per chrome job).
- Classified API/feed **outcomes** show `Decision#message` from the wire (`error.message` / `warning.message`). Do not remap those codes through COPY.

Do not duplicate tokens, element resets, base canvas rules, card shells, inputs, item list grammar, rails, stack primitives, or brand-lockup styling in `main.css` or `rss.xsl`. If app and feed both need it, it belongs in `shared-ui.css`.

## Visual Thesis

The UI is not a generic SaaS dashboard. It should read as:

- stark
- editorial
- quiet but deliberate
- dark, with restrained light accents
- compact, not crowded
- gap-only vertical rhythm (no dual gaps, negative margins, or empty reserved error rows)

The experience should feel like one product across:

- `/` create
- the token gate
- the result page
- `/example.rss` and all XSL-rendered feeds

If a page looks like it came from a different product, the change is wrong even if the CSS is technically valid.

## Journey Grammar (enforced)

- **Create:** URL field is the task. Visiting `#/create` or `#!/create` remounts create; hashbang aliases canonicalize to `#/create`. Bare create does not auto-submit. When the typed query finds catalog entries (URL equivalence or text substring), show matching included feeds as a subordinate list under the field — never a second primary task or in-app catalog browser.
- **Token gate:** a native `<dialog>` over the still-mounted, inert URL task (one interactive task). Auth copy is in-field (`tokenError`); ActionFeedback stays on create. Access Token persists until Logout with no storage UI.
- **Result:** primary CTA is **Copy feed URL**. Open feed / JSON / feed-reader are demoted secondary actions and stay available while preview loads. Preview is non-blocking confirmation only.
- **Unmatched result:** `#/result/:token` is valid only with a matching in-memory result. Missing or mismatched tokens recover onto remounted `#/create` (no API rehydrate, no failure chrome, no durable shareable result page).
- **Status eyebrow:** one vocabulary (`Feed ready`) on the result header; preview progress lives in the preview section.
- **Focus:** create autofocuses the URL field; token autofocuses the token field; result focuses the Copy control.

### Vocabulary

| Job | Words |
| --- | --- |
| Input | **URL** |
| Output | **Feed URL** |
| Create | **Create feed** / **Creating feed** |
| Result | **Feed ready** / **Copy feed URL** |
| Retry | **Try again** (button only) |
| Preview | **Checking preview** / **Check again** |
| Catalog | **Included feeds** |
| Token | **Access token** |

## Non-Negotiable Surface Rules

- Background must use the same dark canvas and top-light treatment defined in `shared-ui.css`.
- Shared cards must use the same border, radius, and surface treatment via `.ui-card` (plus modifiers). No page-local framed-surface forks.
- Shared feed/preview items must use `.ui-item-list` / `.ui-item` / `.ui-item__*` grammar.
- Serif display typography is reserved for major titles (`.ui-display-title`) and the wordmark.
- Sans UI typography is the default for controls, supporting copy, and metadata.
- Mono is reserved for URLs, tokens, and machine-like values.
- Eyebrow text uses `.ui-eyebrow` (including `.ui-eyebrow--ghost` for visually hidden labels). Do not invent a parallel `.field-label` system.
- Spacing must come from the token scale only. Letter-spacing uses `--eyebrow-letter-spacing`, `--letter-spacing-meta`, `--letter-spacing-display`, and `--letter-spacing-title`.

Do not introduce:

- ad hoc colors or off-scale spacing
- page-local shadows that fight the shared card elevation
- one-off radii
- extra spacing scales
- component-specific typography systems
- dual-name shims or husk classes after a cutover

## Architecture

The CSS is intentionally split by responsibility, not by page count.

### 1. Shared Primitive Layer

Owned by [public/shared-ui.css](../public/shared-ui.css).

This file owns:

- tokens
- element reset (`h1`–`h6`, `p`, lists, `figure`, etc.)
- global box sizing and canvas behavior
- global typography baseline
- link behavior
- rails and stack primitives
- card primitives (`.ui-card*`)
- item list primitives (`.ui-item*`)
- eyebrow primitive (`.ui-eyebrow*`)
- input primitives (`.input*`)
- button primitives (`.btn*`)
- brand lockup

This file should stay small, boring, and reusable.

### 2. App Composition Layer

Owned by [frontend/src/styles/main.css](../frontend/src/styles/main.css).

This file owns:

- page-shell / workspace composition
- form and dominant-field composition
- notice state composition
- token dialog host (transparent) plus inner `.token-gate` with an opaque canvas fill; `::backdrop` uses `--overlay-scrim`
- result-page composition
- utility strip / footer composition

This file must not redefine shared primitives (`.btn`, `.input`, `.ui-card`, `.ui-eyebrow`, `.ui-item*`, `.layout-stack`, `.brand-lockup`).

### 3. Feed Composition Layer

Owned by [public/rss.xsl](../public/rss.xsl).

This file owns only feed-page specifics:

- feed hero composition
- feed metadata rows
- feed signal chips
- empty/error presentation

Item title / meta / excerpt / actions must reuse the shared `.ui-item__*` classes.

### Self-hosted feed surface (XSL)

The XSL feed view is a human-browser presentation layer only:

- local assets only (`/shared-ui.css`, `/feed-page.js`, `/feed.svg`) — zero third-party network requests
- format and copy actions are demoted secondary controls; primary reader action keeps the orange treatment
- no analytics hooks, cookie banners, consent UI, or privacy-policy copy
- item lists use the same uncarded `.ui-item-list` / `.ui-item` grammar as the app result preview
- brand lockup links to `/` as the instance discovery on-ramp

## Approved Primitive API

Prefer composing these primitives before inventing new classes:

- `layout-shell`
- `layout-rail-reading`
- `layout-rail-copy`
- `layout-stack`
- `layout-stack--tight`
- `ui-card`
- `ui-card--padded`
- `ui-card--roomy`
- `ui-card--notice`
- `ui-card--framed`
- `ui-eyebrow`
- `ui-eyebrow--ghost`
- `ui-item-list`
- `ui-item`
- `ui-item__meta`
- `ui-item__title`
- `ui-item__excerpt`
- `ui-item__actions`
- `ui-actions`
- `ui-display-title`
- `layout-shell-padding`
- `brand-lockup`
- `input`
- `input--lg`
- `input--mono`
- `btn`
- `btn--primary`
- `btn--ghost`
- `btn--quiet`
- `btn--linkish`

Semantic state should prefer attributes over extra visual variants:

- `data-tone="error"`
- `data-tone="success"`
- `data-state="loading"`

This is deliberate. We want a small CSS API with composable primitives, not endless component-local variants.

## Variant Discipline

Before adding a new class or modifier, ask:

1. Can this be expressed by composing existing primitives?
2. Is this a reusable primitive or only page-local composition?
3. Is this visual difference actually perceptible and meaningful?
4. Does this belong to structure, modifier, or semantic state?

Default answers:

- New primitive: rare
- New modifier: suspicious
- New component-specific variant: usually wrong
- New semantic attribute: acceptable when behavior or tone truly changes

Avoid returning to patterns like:

- `input--hero`
- `input--select`
- `status-card`
- `--state-frame-*` surface forks
- `field-label` parallel to `ui-eyebrow`
- featured-feed tile systems that re-own card chrome

Those create variant creep.

## Color And Surface Rules

Use only the shared tokens unless there is a strong system-level reason to extend them.

Key expectations:

- `--surface-base` is the default card plane.
- `--surface-elevated` is for stronger inputs and interactive surfaces.
- success and error backgrounds are semantic overlays, not new card systems.
- border strength should increase only for focus or meaningful emphasis.

If you think you need another surface token, the burden of proof is high.

## Typography Rules

- `--font-family-display` is for primary titles and the wordmark only.
- `--font-family-ui` is the default everywhere else.
- `--font-family-mono` is for feed URLs, tokens, and similarly mechanical strings.
- `ui-eyebrow` is the only pattern for small uppercase metadata labels.

Do not create alternate display systems per page.

## Layout Rules

The layout language is narrow on purpose.

- Use rails to control readable width.
- Use stack primitives for vertical rhythm (`gap` only).
- Keep shells centered and calm.
- Prefer composition over custom grid declarations.
- Hide empty field errors (`.field-error:empty { display: none }`) instead of reserving min-height.

If you add `display: grid`, be able to explain why an existing stack or rail primitive was insufficient.

## Enforcement

`make lint-css-primitives` (wired into `make lint-js`) fails when:

- `frontend/src/styles/main.css` or `public/rss.xsl` redefine shared primitive selectors (including indented rules)
- `--state-frame-*` tokens reappear
- raw off-scale `letter-spacing` or `font-size` literals appear in app/feed composition CSS (use tokens; override shared controls via host CSS vars such as `--control-input-lg-*`)

Stylelint continues to enforce selector naming on CSS files.

## Agent Checklist

When changing UI, an agent must verify:

1. Does the change reuse `shared-ui.css` where appropriate?
2. Did I avoid duplicating a shared primitive in `main.css` or `rss.xsl`?
3. Does the app still match the RSS/XSL rendering in overall tone and framing?
4. Did I avoid inventing a page-local variant for something that should be a modifier or attribute?
5. If I added a token, modifier, or primitive, did I justify it in this file?
6. Did journey chrome go through `frontend/src/journey/copy.ts`? Classified outcome bodies are wire text (`error.message` / `warning.message`), not a COPY remap.
7. Did create / token / result keep one primary task and matching focus?

## Drift Triggers

These are common signs that the system is drifting:

- app and RSS page use different canvas/background treatment
- same content type gets different card shells or item title styles
- page-local spacing values appear outside the token scale
- headings start mixing unrelated type styles
- new input or card variants appear with overlapping purpose
- semantic states are encoded as a growing list of presentational classes
- result actions gated on preview loading
- ActionFeedback stacked under the token dialog
- token gate replacing the URL composer instead of a dialog over inert create

If you see one of these, consolidate instead of layering more CSS.

## Change Policy

When changing the design system:

- update the shared primitive first if the rule is cross-surface
- update this manifest if the rule changes
- keep the primitive API smaller, not larger, when possible
- validate both app UI and RSS/XSL output

The right direction is brutal clarity:

- fewer primitives
- fewer variants
- stronger shared identity
- less local exception code
