# DESIGN_SYSTEM.md

## Overview

Life OS follows a design system inspired by **Apple's Human Interface Guidelines** — minimal, premium, with soft aesthetics and calm interactions.

---

## Design Principles

1. **Clarity** — Every element should be immediately understandable
2. **Deference** — The UI defers to the content, not itself
3. **Depth** — Subtle layering creates visual hierarchy without clutter
4. **Calm** — Nothing should feel urgent or overwhelming

---

## Color Palette

### Primary

| Token | Hex | Usage |
|-------|-----|-------|
| `primary` | `#007AFF` | Brand color, buttons, links, active states |
| `primaryLight` | `#E8F2FF` | Light backgrounds, selected states |
| `primaryDark` | `#0056CC` | Pressed states, dark mode accents |

### Neutrals

| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| Background | `#F5F5F7` | `#1C1C1E` | Screen backgrounds |
| Surface | `#FFFFFF` | `#2C2C2E` | Cards, sheets, elevated surfaces |
| Text Primary | `#1C1C1E` | `#F5F5F7` | Headlines, body text |
| Text Secondary | `#8E8E93` | `#98989D` | Captions, metadata |

### Semantic

| Token | Hex | Usage |
|-------|-----|-------|
| Success | `#34C759` | Confirmations, completed states |
| Warning | `#FF9500` | Cautions, pending states |
| Error | `#FF3B30` | Destructive actions, errors |
| Info | `#5AC8FA` | Informational messages |

---

## Typography

### Typeface

**Inter** — A clean, modern sans-serif optimized for screens.

### Scale

| Style | Size | Weight | Letter Spacing | Usage |
|-------|------|--------|---------------|-------|
| `displayLarge` | 57px | 700 | -0.5 | Hero titles |
| `displayMedium` | 45px | 700 | -0.5 | Screen titles |
| `displaySmall` | 36px | 600 | 0 | Section headers |
| `headlineLarge` | 32px | 700 | 0 | Page titles |
| `headlineMedium` | 28px | 600 | 0 | Card titles |
| `headlineSmall` | 24px | 600 | 0 | List titles |
| `titleLarge` | 22px | 600 | 0 | App bar titles |
| `titleMedium` | 16px | 500 | 0 | List tiles |
| `titleSmall` | 14px | 500 | 0 | Subtitles |
| `bodyLarge` | 16px | 400 | 0 | Body text |
| `bodyMedium` | 14px | 400 | 0 | Secondary text |
| `bodySmall` | 12px | 400 | 0 | Captions |
| `labelLarge` | 14px | 500 | 0 | Buttons |
| `labelMedium` | 12px | 500 | 0 | Chips, badges |
| `labelSmall` | 11px | 500 | 0 | Overlines |

---

## Spacing

Life OS uses an **8-point grid system**:

| Token | Value | Usage |
|-------|-------|-------|
| `xxs` | 2px | Tight spacing |
| `xs` | 4px | Icon padding |
| `sm` | 8px | Item gaps, base unit |
| `md` | 12px | Content gaps |
| `lg` | 16px | Card padding |
| `xl` | 20px | Section gaps |
| `xxl` | 24px | Large gaps |
| `xxxl` | 32px | Screen sections |
| `huge` | 40px | Hero spacing |
| `massive` | 48px | Major separators |

### Screen Padding

- Horizontal: `20px`
- Vertical: `16px`
- Card padding: `16px` all sides

---

## Border Radius

| Token | Value | Usage |
|-------|-------|-------|
| `xs` | 4px | Small chips, badges |
| `sm` | 8px | Inputs, buttons |
| `md` | 12px | Cards (default) |
| `lg` | 16px | Large cards |
| `xl` | 20px | Modals, sheets |
| `xxl` | 24px | Hero elements |
| `circular` | 999px | Pills, avatars |

---

## Shadows

Life OS uses **subtle, soft shadows**:

- Light mode: `rgba(0, 0, 0, 0.04)` — barely visible
- Dark mode: `rgba(0, 0, 0, 0.2)` — deeper for contrast
- No hard shadows — everything feels soft and layered

---

## Icons

All icons use the **rounded** variant of Material Icons for a softer, more premium feel:

```dart
Icons.home_rounded        // Instead of Icons.home
Icons.search_rounded      // Instead of Icons.search
Icons.settings_rounded    // Instead of Icons.settings
```

---

## Animations

### Durations

| Token | Value | Usage |
|-------|-------|-------|
| `fast` | 150ms | Micro-interactions |
| `standard` | 250ms | Most transitions |
| `slow` | 350ms | Emphasis, reveals |
| `pageTransition` | 300ms | Screen transitions |

### Curves

| Token | Curve | Usage |
|-------|-------|-------|
| `defaultCurve` | `easeInOut` | Standard transitions |
| `decelerate` | `easeOut` | Elements coming to rest |
| `accelerate` | `easeIn` | Elements entering |
| `spring` | `elasticOut` | Playful interactions |

### Page Transitions

Pages slide up slightly with a fade for a natural, iOS-inspired feel.

---

## Components

### Buttons

- **Primary**: Filled, brand color, 52px height
- **Secondary**: Outlined, brand color border
- **Text**: No background, brand color text

### Cards

- White surface (light) / Dark surface (dark)
- 12px border radius
- Subtle border (`rgba(0,0,0,0.08)`)
- No elevation shadow (flat design)
- 16px internal padding

### Input Fields

- Filled background
- 8px border radius
- 1.5px focused border (brand color)
- Clear labels and validation states

---

## Theme Support

Life OS supports three theme modes:

1. **Light** — Clean, bright, minimal
2. **Dark** — Deep, calm, premium
3. **System** — Follows device preference

Theme switching will be implemented in the Settings feature.

---

*This design system will evolve as new components are added.*