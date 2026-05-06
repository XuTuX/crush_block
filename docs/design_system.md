# link_your_area Mobile UI System

## Direction

The app uses one soft, minimal product language across home, login, settings, ranking sheets, dialogs, and multiplayer support surfaces.

- Minimal and clean: whitespace and hierarchy lead the layout.
- Refined and minimal: a soft neutral base with restrained blue emphasis keeps the UI calm, modern, and premium.
- Mobile-first: tap targets, padding, and vertical rhythm are optimized for phone widths.
- Consistent by default: screens should reuse tokens and shared components before adding local styling.

## Core Tokens

Implemented in [lib/theme/app_design_system.dart](/Users/kik/Documents/ma-neoreo/link_your_area/lib/theme/app_design_system.dart) and [lib/theme/app_typography.dart](/Users/kik/Documents/ma-neoreo/link_your_area/lib/theme/app_typography.dart).

### Colors

Primary UI palette:

- `AppColors.ink` `#161A23`: primary text, icons, strong contrast
- `AppColors.primary` `#3563F0`: main action color used sparingly
- `AppColors.secondary` `#6FA7B7`: subdued supporting accent
- `AppColors.danger` `#E08A63`: warm destructive and alert accent
- `AppColors.success` `#61A89E`: calm positive state accent

Neutral system:

- `AppColors.background` `#F6F7FB`
- `AppColors.surface` `#F2F4FA`
- `AppColors.surfaceMuted` `#F8F9FC`
- `AppColors.borderSoft` `#DCE2F0`
- `AppColors.textMuted` `#161A23` at reduced opacity
- `AppColors.textSubtle` `#161A23` at lower opacity
- `AppColors.overlay` for dimmed modal backdrops

Semantic states:

- `AppColors.success`
- `AppColors.danger`
- `AppColors.dangerSoft`

Rules:

- Product screens use a neutral base first and rely on the primary accent only for active or CTA states.
- Background and surface separation provides depth instead of bright white cards.
- Supporting accents should stay soft and mostly appear as tinted fills, not large saturated blocks.
- Gameplay can keep mechanic-specific colors, but supporting UI chrome should still use the core palette.

### Typography

The app now uses a single family through the theme: `Noto Sans KR`.

Hierarchy:

- `display` 36 / 700: hero titles
- `headline` 28 / 700: prominent screen statements
- `title` 22 / 700: screen and modal titles
- `subtitle` 18 / 600: section headers
- `body` 15 / 500: primary content
- `bodySmall` 14 / 500: supporting content
- `label` 12 / 600: metadata labels
- `caption` 12 / 500: small helper copy
- `button` 15 / 600: all buttons

Rules:

- Keep titles short and body copy compact.
- Do not introduce extra display fonts for individual screens.
- Use weight and spacing for hierarchy before changing color.

### Spacing

The system uses an 8px rhythm with smaller 4px adjustments when needed.

- `xxs` 4
- `xs` 8
- `sm` 12
- `md` 16
- `lg` 20
- `xl` 24
- `xxl` 32
- `xxxl` 40

Rules:

- Section gaps: `24`
- Card padding: `20` to `24`
- Control gaps: `8` to `12`
- Page side padding: `24` on primary screens

### Radius and Shadow

- Primary component radius: `20`
- Pill/circle radius: `999`
- Dialog/sheet shells: `28` when a larger container is needed
- Shared soft shadow: `AppShadows.softCard`
- Shared elevated shadow: `AppShadows.liftedCard`

Rules:

- Cards, buttons, inputs, nav pills, and list rows should stay in the same rounded family.
- Use one shadow language only: soft and diffuse, never hard comic-style offsets.

## Shared Components

Implemented in [lib/theme/app_components.dart](/Users/kik/Documents/ma-neoreo/link_your_area/lib/theme/app_components.dart).

- `AppSurface`: default card/container surface
- `AppActionButton`: primary, secondary, destructive buttons
- `AppIconCircleButton`: rounded icon button
- `AppModalSurface`: modal and bottom-sheet shell
- `AppTextInput`: shared input styling
- `AppSectionHeader`: title + subtitle block
- `AppListRow`: reusable settings/list row
- `AppScreenHeader`: top navigation header

Component rules:

- Buttons are 56px tall and reuse the same text style.
- Inputs always use muted fills, soft borders, and the same focus color.
- Modals and sheets use the same surface, overlay, and elevation logic as main cards.
- Icons stay simple, rounded, and medium-weight.

## Example Screens

### Home

Defined in [lib/screens/home_screen.dart](/Users/kik/Documents/ma-neoreo/link_your_area/lib/screens/home_screen.dart).

- Soft background wash
- Elevated hero card for ranked play
- Shared nickname summary card
- Pill-style bottom navigation with the same radius, border, and shadow

### Login

Defined in [lib/screens/auth_gate_screen.dart](/Users/kik/Documents/ma-neoreo/link_your_area/lib/screens/auth_gate_screen.dart) and [lib/widgets/home_screen/login_sheet.dart](/Users/kik/Documents/ma-neoreo/link_your_area/lib/widgets/home_screen/login_sheet.dart).

- One onboarding card on the page
- Same modal surface for the login sheet
- Reused button spacing, copy scale, and muted support text

### Settings

Defined in [lib/screens/settings_screen.dart](/Users/kik/Documents/ma-neoreo/link_your_area/lib/screens/settings_screen.dart).

- Shared screen header
- Reused section headers and list rows
- Same card shells, icon tiles, spacing, and destructive treatment

### Modal / Popup

Defined in:

- [lib/widgets/dialogs/custom_dialog.dart](/Users/kik/Documents/ma-neoreo/link_your_area/lib/widgets/dialogs/custom_dialog.dart)
- [lib/widgets/dialogs/edit_nickname_dialog.dart](/Users/kik/Documents/ma-neoreo/link_your_area/lib/widgets/dialogs/edit_nickname_dialog.dart)
- [lib/screens/multiplayer_game/mp_leave_dialog.dart](/Users/kik/Documents/ma-neoreo/link_your_area/lib/screens/multiplayer_game/mp_leave_dialog.dart)
- [lib/screens/ranking_screen.dart](/Users/kik/Documents/ma-neoreo/link_your_area/lib/screens/ranking_screen.dart)

- Same overlay
- Same elevated surface
- Same button system
- Same typography hierarchy

## Consistency Check

Verification targets for every UI change:

1. Colors are reused from `AppColors` instead of screen-local values.
2. Typography uses `AppTypography` roles without ad hoc hierarchies.
3. Buttons, surfaces, rows, inputs, and modal shells come from shared components.
4. Spacing follows the 8px rhythm and standard page/card padding.
5. Modals and sheets match the same surface, radius, shadow, and overlay treatment as the main app.

If a new screen breaks one of these checks, promote the new pattern into the shared system instead of redesigning locally.
