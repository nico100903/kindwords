# UI Specification — Quote CRUD Sprint
**Status:** READY FOR IMPLEMENTATION  
**Date:** 2026-03-27  
**Linked discovery:** `vault/ai/docs/sprint-crud-quotes-discovery.md`

---

## Design Principles

- Stay consistent with current Material 3 + amber seed color theme
- No new dependencies — use Material 3 components already available via Flutter
- Density: list screens use `ListTile` (established pattern); form screen uses comfortable card layout
- Destructive actions (delete) always require a confirmation step — no accidental data loss

---

## Screen 1 — Quote Catalog (`/quotes`)

### AppBar
```
← (back if pushed)   All Quotes   [search icon (future)]   [+ icon]
```
- Title: `"All Quotes"`
- Leading: back arrow only when pushed from another screen
- Trailing: `IconButton(icon: Icons.add)` — same action as FAB
- No elevation (consistent with HomeScreen)

### Filter Bar (below AppBar, above list)
```
[ All ] [ Mine ] [ Seeded ] [ #motivational ] [ #wisdom ] [ #humor ] [ #love ] [ #focus ]
```
- Horizontal `SingleChildScrollView` of `FilterChip` widgets
- Height: 48dp
- Active chip: filled (uses theme `colorScheme.primaryContainer`)
- Inactive chip: outlined
- `"All"` and `"Mine"` and `"Seeded"` are source filters
- Tag chips (`#tag`) are tag filters — mutually exclusive with each other (single active at a time)
- Source filter and tag filter can be active simultaneously

### List Body
```
┌──────────────────────────────────────────────────────┐
│ [📖]  "Believe you can and you're halfway there."    │ [✏️] [🗑️]
│       — Theodore Roosevelt  · #motivational          │
├──────────────────────────────────────────────────────┤
│ [✏️]  "My own words about this morning."             │ [✏️] [🗑️]
│       — (no author)  · #personal                     │
└──────────────────────────────────────────────────────┘
```

**QuoteListTile spec:**
- `leading`: `Icon(Icons.menu_book_outlined)` for seeded, `Icon(Icons.edit_note)` for user-created
- `title`: quote text, `maxLines: 2`, `overflow: TextOverflow.ellipsis`
- `subtitle`: two-line max — line 1: `"— Author"` or `"Anonymous"`, line 2: tag chips (max 2 shown, `+N` overflow if more)
- `trailing`: row of two `IconButton`s — `Icons.edit_outlined` (edit) and `Icons.delete_outline` (delete)
- Tap anywhere on tile: opens `QuoteFormScreen` in view-only mode (stretch goal — not required for CRUD demo)

**Empty state (when filter has no results):**
```
[filter_list_off icon, 48dp, grey]
No quotes match this filter.
[Clear filter] (text button)
```

**Empty state (no quotes at all — impossible in practice but handled):**
```
[format_quote icon, 64dp, grey]
Your quote collection is empty.
Tap + to write your first quote.
```

### FAB
- `FloatingActionButton.extended`
- Icon: `Icons.add`
- Label: `"New Quote"`
- Position: bottom-right
- Same action as AppBar `+`

### Delete Confirmation (bottom sheet, triggered from tile delete icon)
```
─────────── Delete Quote ───────────
"Believe you can and you're halfway..."
This quote will be removed from your local collection.
It cannot be undone.

[Cancel]                    [Delete]  ← red text
```
- `showModalBottomSheet` with rounded top corners
- Cancel: dismisses
- Delete: calls `repository.deleteQuote(id)`, pops, list refreshes reactively

---

## Screen 2 — Quote Form (`QuoteFormScreen`)

### Create mode AppBar
```
✕ (close)   New Quote   [Save]
```

### Edit mode AppBar
```
← (back)   Edit Quote   [Update]
```

- Leading icon differs: `✕` for create (discards), `←` for edit (warns if unsaved changes)
- Trailing action button: `TextButton("Save")` / `TextButton("Update")` in theme primary color
- Disabled (greyed) until form is valid (text ≥ 10 chars)

### Form Layout
```
┌─────────────────────────────────────────────────────┐
│  QUOTE TEXT                                          │
│  ┌─────────────────────────────────────────────┐   │
│  │ What's on your mind?                        │   │
│  │                                              │   │
│  │                                              │   │
│  └─────────────────────────────────────────────┘   │
│  ⚠ Quote must be at least 10 characters. (error)   │
├─────────────────────────────────────────────────────┤
│  AUTHOR (optional)                                   │
│  ┌─────────────────────────────────────────────┐   │
│  │ Who said this?                              │   │
│  └─────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────┤
│  TAGS (optional — pick up to 3)                     │
│  [#motivational] [#wisdom] [#humor]                 │
│  [#love] [#focus] [#personal ✓]                    │
├─────────────────────────────────────────────────────┤
│  SOURCE                                             │
│  📖 Seeded quote  /  ✏️ Your own quote (auto-set)  │
│  (read-only display — not user-editable)            │
└─────────────────────────────────────────────────────┘

[                  Delete this quote                  ]
← red text button, only shown in Edit mode
```

### Field specs

**Quote text field:**
- `TextFormField`, `maxLines: null` (expands), `minLines: 4`
- `hintText: "What's on your mind?"`
- `inputFormatters: [LengthLimitingTextInputFormatter(1000)]`
- Validator: required, min 10 chars
- `textCapitalization: TextCapitalization.sentences`

**Author field:**
- `TextFormField`, single line
- `hintText: "Who said this? (optional)"`
- `inputFormatters: [LengthLimitingTextInputFormatter(100)]`

**Tag chips:**
- `Wrap` of `FilterChip` widgets, one per predefined tag
- Max 3 selectable — when 3 are selected, remaining unselected chips are disabled
- `selected` chip shows checkmark
- `#personal` auto-selected and non-removable for user-created quotes
- For seeded quotes in edit mode: `#personal` is not auto-applied

**Source indicator:**
- `ListTile` with `enabled: false`, shows icon + label, read-only
- Create mode: `Icons.edit_note`, label `"Your own quote"`
- Edit mode: shows the quote's actual source

**Delete button (edit mode only):**
- `TextButton` in `Colors.red`
- Label: `"Delete this quote"`
- Positioned below a `Divider` at the bottom of the scrollable form content
- Tap: shows `AlertDialog` (not bottom sheet — more serious action)

### Delete confirmation dialog (form)
```
     Delete this quote?

"Believe you can and you're halfway..."
will be permanently removed from your
local collection.

[Cancel]  [Delete]← red
```

### Unsaved changes dialog (edit mode, back tap)
```
     Discard changes?

You have unsaved edits to this quote.

[Keep editing]  [Discard]← destructive
```

---

## Screen 3 — Favorites (modified)

### Existing list tile → extended

```
┌──────────────────────────────────────────────────────┐
│  "Believe you can and you're halfway there."         │ [✏️] [🗑️]
│  — Theodore Roosevelt                               │
└──────────────────────────────────────────────────────┘
```

- `trailing` changes from a single delete `IconButton` to a `Row` of two:
  - `IconButton(icon: Icons.edit_outlined)` — opens `QuoteFormScreen` in edit mode
  - `IconButton(icon: Icons.delete_outline)` — existing delete behavior (no change)
- The edit and delete icons share the trailing row at consistent 40dp width each

---

## Updated Bottom Navigation (HomeScreen)

| Tab | Icon | Label | Route |
|-----|------|-------|-------|
| 0 | `Icons.home_outlined` / `Icons.home` | Home | `/` |
| 1 | `Icons.format_quote_outlined` / `Icons.format_quote` | Quotes | `/quotes` |
| 2 | `Icons.favorite_outline` / `Icons.favorite` | Favorites | `/favorites` |
| 3 | `Icons.settings_outlined` / `Icons.settings` | Settings | `/settings` |

Active icon uses filled variant. Inactive uses outlined variant.  
The existing bottom nav `BottomNavigationBar` must be updated from 3 to 4 items, and navigation case index offsets adjusted.

---

## Tag chip visual spec

**In list tile subtitle (read-only):**
- `Chip` widget, height 20dp, label `fontSize: 10`, padding minimal
- Background: `colorScheme.surfaceVariant`
- Max 2 shown in tile — if 3 tags, show first 2 + `+1` overflow chip

**In form (selectable):**
- `FilterChip`, height 32dp, normal label size
- Selected: `colorScheme.primaryContainer` background, checkmark leading
- Disabled (when 3 already selected and this one is not): 50% opacity

**Tag label format:** `#tagname` (lowercase, always prefixed with `#`)

---

## Color / Icon Reference

| Element | Icon | Color |
|---------|------|-------|
| Seeded quote | `Icons.menu_book_outlined` | `colorScheme.primary` |
| User quote | `Icons.edit_note` | `colorScheme.secondary` |
| Edit action | `Icons.edit_outlined` | default icon color |
| Delete action | `Icons.delete_outline` | default icon color |
| Delete confirm button | — | `Colors.red` |
| Active tag chip | — | `colorScheme.primaryContainer` |
| FAB | `Icons.add` | `colorScheme.primaryContainer` |
| Save/Update button | — | `colorScheme.primary` (TextButton) |

---

## Accessibility Notes

- All `IconButton`s have `tooltip:` set (`"Edit quote"`, `"Delete quote"`)
- Form fields have `labelText` set (not just `hintText`) for screen readers
- Delete confirmation dialogs are `AlertDialog` / bottom sheet — dismissable by back gesture
- Tag chips have `semanticsLabel` set: `"Tag: motivational, selected"` etc.

---

## Navigation Flow Diagram

```
HomeScreen (/)
  ├── /quotes (QuoteCatalogScreen)
  │     ├── QuoteFormScreen [create]   (push, returns true on save → catalog refreshes)
  │     └── QuoteFormScreen [edit]     (push, returns true on save/delete → catalog refreshes)
  ├── /favorites (FavoritesScreen)
  │     └── QuoteFormScreen [edit]     (push, returns true on save/delete → favorites refreshes)
  └── /settings (unchanged)
```

---

## States to handle per screen

### QuoteCatalogScreen
| State | UI |
|-------|----|
| Loading | `CircularProgressIndicator` centered |
| Loaded, no filter | Full list |
| Loaded, filter active | Filtered list or empty-filter state |
| No quotes (impossible in v1) | Empty state with FAB prompt |

### QuoteFormScreen
| State | UI |
|-------|----|
| Create — pristine | Empty fields, Save button disabled |
| Create — valid | Save button enabled (blue) |
| Create — invalid submit | Inline field error |
| Edit — pristine (no changes) | Update button enabled, no unsaved changes |
| Edit — dirty (changes made) | Back button triggers discard dialog |
| Saving | Brief loading indicator in AppBar Save button area |
| Save error | `SnackBar` with error message |
