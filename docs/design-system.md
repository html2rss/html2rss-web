# Design System Manifest

This document is the visual source of truth for `html2rss-web`.

If you change the UI, read this first. If a design decision is not reflected here, update this file in the same change. The goal is to prevent slow visual drift between the app shell, result flow, and RSS/XSL presentation.

## Core Rule

There is one shared design language and one shared primitive layer.

- Shared primitives live in [public/shared-ui.css](../public/shared-ui.css).
- App-specific composition lives in [frontend/src/styles/main.css](../frontend/src/styles/main.css).
- Feed-specific composition lives in [public/rss.xsl](../public/rss.xsl).

Do not duplicate tokens, base canvas rules, card shells, rails, stack primitives, or brand-lockup styling in `main.css` or `rss.xsl`. If app and feed both need it, it belongs in `shared-ui.css`.

## Visual Thesis

The UI is not a generic SaaS dashboard. It should read as:

- stark
- editorial
- quiet but deliberate
- dark, with restrained light accents
- compact, not crowded

The experience should feel like one product across:

- `/`
- the token gate
- the result page
- `/example.rss` and all XSL-rendered feeds

If a page looks like it came from a different product, the change is wrong even if the CSS is technically valid.

## Non-Negotiable Surface Rules

- Background must use the same dark canvas and top-light treatment defined in `shared-ui.css`.
- Shared cards must use the same border, radius, and surface treatment.
- Serif display typography is reserved for major titles and the wordmark.
- Sans UI typography is the default for controls, supporting copy, and metadata.
- Mono is reserved for URLs, tokens, and machine-like values.
- Eyebrow text is uppercase, compact, and low-noise.
- Spacing should come from the token scale only.

Do not introduce:

- ad hoc colors
- page-local shadows that fight the shared card elevation
- one-off radii
- extra spacing scales
- component-specific typography systems

## Architecture

The CSS is intentionally split by responsibility, not by page count.

### 1. Shared Primitive Layer

Owned by [public/shared-ui.css](../public/shared-ui.css).

This file owns:

- tokens
- global box sizing and canvas behavior
- global typography baseline
- link behavior
- rails
- stack primitives
- card primitives
- eyebrow primitive
- brand lockup

This file should stay small, boring, and reusable.

### 2. App Composition Layer

Owned by [frontend/src/styles/main.css](../frontend/src/styles/main.css).

This file owns:

- page-shell composition
- workspace layout
- form behavior
- dominant-field behavior
- button behavior
- notice state behavior
- token-gate composition
- result-page composition
- utility strip behavior

This file should not redefine shared primitives.

### 3. Feed Composition Layer

Owned by [public/rss.xsl](../public/rss.xsl).

This file owns only feed-page specifics:

- feed hero composition
- feed metadata rows
- feed list/card content styling
- feed empty/error presentation

This file should compose shared classes rather than restyle them.

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
- `ui-eyebrow`
- `brand-lockup`
- `input`
- `input--lg`
- `input--minimal`
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
- multiple near-identical surface tokens

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
- `ui-eyebrow` is the preferred pattern for small uppercase metadata labels.

Do not create alternate display systems per page.

## Layout Rules

The layout language is narrow on purpose.

- Use rails to control readable width.
- Use stack primitives for vertical rhythm.
- Keep shells centered and calm.
- Prefer composition over custom grid declarations.

If you add `display: grid`, be able to explain why an existing stack or rail primitive was insufficient.

## Agent Checklist

When changing UI, an agent must verify:

1. Does the change reuse `shared-ui.css` where appropriate?
2. Did I avoid duplicating a shared primitive in `main.css` or `rss.xsl`?
3. Does the app still match the RSS/XSL rendering in overall tone and framing?
4. Did I avoid inventing a page-local variant for something that should be a modifier or attribute?
5. If I added a token, modifier, or primitive, did I justify it in this file?

## Drift Triggers

These are common signs that the system is drifting:

- app and RSS page use different canvas/background treatment
- same content type gets different card shells
- page-local spacing values appear outside the token scale
- headings start mixing unrelated type styles
- new input or card variants appear with overlapping purpose
- semantic states are encoded as a growing list of presentational classes

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
