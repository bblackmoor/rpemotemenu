# RP Emote Menu

A lightweight, configurable roleplaying emote menu for **World of Warcraft**.

RP Emote Menu provides a compact, movable, resizable, and collapsible window
with quick access to your favorite roleplaying emotes and custom `/e` commands.
Choose a category from the left sidebar, then select an emote from the list on
the right. Each emote can optionally use a different command when another unit
is targeted.

## Features

- Up to **10 customizable categories**, with up to **10 emotes per category**.
- A left-hand category sidebar with direct category selection, a highlighted
  active category, and independent scrolling.
- Blank categories are automatically hidden, and long category names show
  their full text in a tooltip.
- Editable category names, emote labels, default commands, and targeted
  commands.
- Built-in emotes such as `/smile`, plus custom `/e` commands.
- `{target}` and `{player}` name-replacement tokens.
- Named profiles shared between characters, with a separate active profile
  selected for each character.
- A protected **Default** profile that always reflects the addon's current
  supplied categories and emotes.
- JSON import and export for individual categories and complete profiles.
- A movable, collapsible, resizable, and lockable main window.
- Remembered category selection, window position, size, and minimized state.
- Exact window position and size controls, including mouse-wheel adjustment.
- Scroll indicators for additional emotes above or below the visible list.
- An optional title-bar settings gear and configurable login visibility.
- Category and complete-profile reset controls for editable profiles.
- No external addon-library dependencies.

## Installation

Place the `RPEmoteMenu` directory in your World of Warcraft addon folder:

```text
World of Warcraft/_retail_/Interface/AddOns/RPEmoteMenu/
```

The directory must contain `RPEmoteMenu.toc`. Enable **RP Emote Menu** from the
character-selection screen's AddOns list if necessary.

## Getting Started

1. Enter `/rpem` to show or hide the main window.
2. Select a category from the left sidebar.
3. Select an emote to execute its command.
4. Open settings with the title-bar gear icon or `/rpem config`.
5. Open **Profiles**, enter a new profile name, and select **Create Profile**
   before customizing categories or emotes.

The selected category is remembered. Categories without names do not appear in
the sidebar.

## Profiles

A profile contains every category and emote. Profiles are shared across
characters, while each character chooses its own active profile.

The **Default** profile is read-only. It cannot be edited, renamed, deleted, or
used as the destination for category imports. Its contents are refreshed from
the categories and emotes supplied with the addon.

The **Profiles** settings screen includes:

- **Create Profile:** Create an editable profile using the supplied defaults.
- **Copy Profile:** Copy the selected profile, including its custom categories
  and emotes.
- **Rename Profile:** Rename the selected editable profile in a separate dialog.
- **Delete Profile:** Confirm deletion of the selected editable profile.
  Characters using that profile return to **Default**.
- **Export Profile:** Export the selected profile as JSON.
- **Import Profile:** Import profile JSON into a new profile using the name
  entered in the new-profile-name field.

Profile names cannot be blank, exceed 64 characters, duplicate another name
regardless of case, or use the reserved name **Default**.

## Categories and Emotes

Open **Options → AddOns → RP Emote Menu**, select a category, and edit its
category name and emotes. Each emote includes:

- **Emote Label:** The label shown in the main window.
- **Default Command:** The command used without another target.
- **Targeted Command:** An optional command used when another unit is targeted.

An emote appears in the menu only when its label and default command are both
present. Leaving a category name blank hides that category from the sidebar.

Example:

```text
Emote Label: Watches quietly
Default Command: /e watches quietly.
Targeted Command: /e watches {target} quietly.
```

## Import and Export

Category settings include **Export** and **Import** buttons. Export creates a
JSON document containing that category and its emotes. Import validates the
JSON and replaces the selected category in the current editable profile.

The **Profiles** screen provides **Export Profile** and **Import Profile**.
Profile import always creates and selects a new named profile. It never
overwrites the currently selected profile or changes **Default**.

Export documents include the addon format, document type, and format version.
Invalid, malformed, or incompatible documents are rejected without replacing
existing data.

## Window Settings

The **General** settings screen controls window movement, resizing, login
visibility, the optional settings gear, and whether the minimized state is
remembered. It also displays and edits the exact window position and size.

You can reset the window position and size, reset an individual category, or
reset every category in the active editable profile to the supplied defaults.

## Slash Commands

| Command          | Description                    |
| :--------------- | :----------------------------- |
| `/rpem`          | Show or hide the RP Emote Menu |
| `/rpem config`   | Open the addon settings        |
| `/rpem options`  | Open the addon settings        |
| `/rpem settings` | Open the addon settings        |

## Target Tokens

RP Emote Menu replaces supported tokens in emote commands before sending them:

| Token      | Description                             |
| :--------- | :-------------------------------------- |
| `{target}` | Target's name without the realm         |
| `{player}` | Your character's name without the realm |

The **Targeted Command** is used only when another unit is targeted. Without a
target, or when targeting yourself, the **Default Command** is used instead.

---

Copyright © 2026 Brandon Blackmoor (<bblackmoor@blackgate.net>)  
Licensed under the GNU General Public License v3.0 (GPL-3.0):  
https://www.gnu.org/licenses/gpl-3.0.en.html  
Source: https://github.com/bblackmoor/rpemotemenu
