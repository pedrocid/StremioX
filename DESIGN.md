# Design

The visual system for StremioX. The tvOS app is the reference implementation; the iOS native client inherits these tokens. Values are expressed as OKLCH intent plus the sRGB the SwiftUI tokens ship (iOS 16 has no native OKLCH). Tokens live in `app/SourcesTV/Theme.swift`.

## Theme

Dark, warm. One theme only (the living-room scene forces it). The canvas is a deep warm near-black so poster art is the only saturated thing on screen. Elevation is expressed by stepping lightness up on warm-tinted surfaces and by soft shadow, never by borders or glassy blur.

## Color

Strategy: **Restrained**. Warm-neutral monochrome chrome plus one accent. The accent means focus, current selection, primary action, and progress. Nothing decorative is colored.

Neutrals (warm, hue ~60, very low chroma):

| Token | OKLCH intent | sRGB hex | Use |
|---|---|---|---|
| `canvas` | 14% 0.008 60 | `#15120E` | App background |
| `surface1` | 19% 0.009 60 | `#211C16` | Rows, cards, panels |
| `surface2` | 24% 0.010 60 | `#2D261D` | Chips, controls, elevated |
| `surface3` | 30% 0.011 60 | `#3A3127` | Hover / selected fill |
| `hairline` | 32% 0.010 60 | `#403629` | 1px separators only |
| `textPrimary` | 96% 0.006 75 | `#F6F1E9` | Titles, primary text |
| `textSecondary` | 76% 0.012 75 | `#BCB1A1` | Secondary text, labels |
| `textTertiary` | 56% 0.012 75 | `#8C8273` | Captions, disabled |

Accent (ember / warm coral, hue ~38):

| Token | OKLCH intent | sRGB hex | Use |
|---|---|---|---|
| `accent` | 72% 0.16 38 | `#F2784B` | Focus ring, selection, primary action, progress fill |
| `accentBright` | 78% 0.15 45 | `#FF9163` | Focus glow highlight |
| `accentSoft` | accent @ 18% alpha | rgba | Selected-chip fill, glow base |

Semantic: destructive uses the system red (kept distinct from the warm accent). Success and warning are not introduced until a screen needs them; add to this table when they do.

## Typography

Two families, both system (no bundled fonts, zero load risk):

- **Display (editorial moments only)**: SF Pro Rounded is avoided; use the system serif **New York** (`Font.system(..., design: .serif)`) at heavy/bold for the wordmark and the detail-page hero title. This is the editorial-cinema signature.
- **UI (everything else)**: **SF Pro** (`design: .default`). Carries section headers, card titles, body, labels, data.

Scale (tvOS, fixed, ratio ~1.25), defined as `Theme.Font` helpers:

| Role | Size / weight / tracking | Family |
|---|---|---|
| `hero` | 64 heavy, tracking -1.5 | serif |
| `wordmark` | 40 bold, tracking -0.5 | serif |
| `screenTitle` | 52 heavy, tracking -1 | sans |
| `sectionTitle` | 30 semibold, tracking -0.3 | sans |
| `cardTitle` | 22 semibold | sans |
| `body` | 24 regular, line height 1.4 | sans |
| `label` | 20 medium | sans |
| `eyebrow` | 15 bold, tracking +1.5, uppercase | sans |

Prose blocks (synopsis) cap around 70 characters per line.

## Spacing

8pt base. Scale: `xs 8, sm 12, md 20, lg 32, xl 48, xxl 72`. Rhythm is intentional, not uniform: section gaps use `xl`, in-card gaps use `sm`. tvOS safe-area inset for screen edges is `60`.

## Radius & Elevation

- Radius: `card 16`, `chip 12`, `control 14`, `pill 999`.
- Shadow: resting cards have a soft low shadow (y 8, blur 24, black 35%). Focused cards lift to (y 18, blur 44, black 50%) plus an ember glow.
- No borders for elevation. A single `hairline` separator is allowed for true dividers only.

## Components

- **PosterCard**: rounded `card` radius, resting shadow, title below in `cardTitle`. On focus: scale 1.08, lift, ember glow, title brightens to `textPrimary`. Watched state: 55% opacity plus a check badge.
- **Chip / filter**: `surface2` fill, `chip` radius, `label` text in `textSecondary`. Selected: `accentSoft` fill, `accent` text. Focus: ember ring + scale 1.06.
- **Row**: `sectionTitle` header with an `eyebrow` kicker, horizontal scroll of PosterCards, `xl` vertical gap between rows.
- **EmptyState**: centered icon, title, one line; warm and instructive, never a spinner when signed out.
- **Primary button (play / resume)**: `accent` fill, `textPrimary`-on-accent, `control` radius, leading icon. Focus: brighten + scale + glow.

## Motion

- Focus: spring (response 0.32, damping 0.78) on scale and lift. Feels like a soft magnetic snap, no overshoot beyond the spring.
- State changes: 180ms ease-out.
- Reduce Motion: drop scale and spring, keep opacity and instant selection.
- Never animate layout-bound properties; scale and opacity and shadow only.

## Iconography

SF Symbols throughout, filled variants for primary affordances (`play.fill`, `checkmark.circle.fill`), consistent weight. No mixed icon families.
