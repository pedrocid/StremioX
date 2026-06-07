# Product

## Register

product

## Users

People who own an Apple TV and want to watch what they actually care about. Cord-cutters and film and TV enthusiasts who already use Stremio on other platforms and refuse to settle for the stale official Apple build. Their context is lean-back: a remote in hand, ten feet from a large screen, in a dim room, usually at night. They are not browsing for fun; they want to find a title and start playing it with as few clicks as possible, then have the interface disappear so the content can take over. A second audience is the same person on an iPhone or iPad, where the native client will inherit this same system.

## Product Purpose

StremioX is an independent, updated, native Stremio client for Apple devices, built on stremio-core (the same Rust engine Stremio's own apps use). It exists because the official Apple builds went stale and the official Apple TV option is the feature-limited "Lite." Success is when an Apple TV user stops noticing the app at all: their Continue Watching is correct, every catalog and addon is there, a title is two clicks from playing, and the chrome never competes with the film.

## Brand Personality

Cinematic, curated, honest. The voice is plain and unhyped (the README openly credits AI for the code and never oversells). The interface should feel like a thoughtful film programmer's tool, not a content firehose. Calm confidence over flash. It respects the user's attention and their living room.

## Anti-references

- **Netflix**: the wall-to-wall autoplay firehose, red accent, and grid that treats every title as interchangeable.
- **Plex**: amber-on-pure-black, busy server-dashboard density.
- **Generic Apple TV / tvOS template**: translucent blur everywhere, default cyan/blue tint, system everything, no point of view.
- **The current StremioX**: flat pure-black background with a single cyan accent and default focus bounce. Functional but characterless.
- **AI-generated dark dashboard**: even spacing everywhere, identical card grids, neon-on-black, gradient text, side-stripe accents.

## Design Principles

1. **Content is the light.** Poster and backdrop art is the only saturated color on screen. The chrome is warm monochrome and recedes. If a UI element competes with the artwork, the UI is wrong.
2. **Focus is the hero.** On tvOS the single most-used interaction is moving focus with the remote. The focused element must read instantly from ten feet through scale, a warm glow, and lift, not a generic system bounce.
3. **Curated, not a firehose.** Generous rhythm, confident typography, and clear hierarchy over maximum density. Make a few things feel important rather than everything feel equal.
4. **Honest and unbranded.** No fake premium sheen, no dark patterns, no borrowed trade dress. The craft shows through restraint.
5. **Consistent at ten feet.** One spacing scale, one type scale, one accent meaning, one focus treatment, everywhere. Legibility and predictability at distance beat per-screen cleverness.

## Accessibility & Inclusion

- Ten-foot legibility: minimum on-screen text large and high-contrast; body and labels meet WCAG AA on their surfaces.
- Focus is always visible and never relies on color alone (scale and lift accompany the accent).
- No meaning carried by color alone (watched state uses a check plus dimming, not just a tint).
- Respect Reduce Motion: focus and transitions fall back to opacity and instant state.
- Warm-neutral palette chosen to stay legible for common color-vision differences; the accent is distinguishable by brightness and position, not hue alone.
