# RP Emote Menu

A lightweight, configurable roleplaying emote menu for **World of Warcraft**.

RP Emote Menu provides a compact, movable, resizable, and collapsible window that gives quick access to your favorite roleplaying emotes and custom `/e` commands. Emotes are organized into customizable categories, and each entry can optionally use a different command when another unit is targeted.

## Features

- Up to **10 customizable categories**
- Up to **10 emotes per category**
- Editable category names, button labels, and commands from the in-game Options panel
- Three-category carousel for quickly switching between categories
- Categories with blank names are automatically hidden from the main menu
- Optional targeted `/e` commands using `{target}`, `{target-full}`, `{player}`, and `{player-full}`
- Supports both built-in emotes (such as `/smile`) and custom `/e` emotes
- Movable, collapsible, resizable, and lockable window
- Remembers its position, size, and minimized state
- Exact window position and size can be viewed and edited in Options
- Position and size values can be adjusted with the mouse wheel
- Scroll indicators show when additional emotes are above or below the visible list
- Settings can be opened from the title-bar gear icon
- Optional setting to hide the gear icon
- Reset individual categories to their default values
- Reset all categories and emotes to their default values

## Configuration

Open **Options → AddOns → RP Emote Menu**, click the gear icon on the main window, or use `/rpem config`.

Each category can be renamed and can contain up to ten emotes. An emote has a button label, a default command, and an optional targeted command. Leave a category name blank to hide that category from the main menu.

## Slash Commands

| Command          | Description                    |
| :--------------- | :----------------------------- |
| `/rpem`          | Show or hide the RP Emote Menu |
| `/rpem config`   | Open the addon settings        |
| `/rpem options`  | Open the addon settings        |
| `/rpem settings` | Open the addon settings        |

## Target Tokens

Target tokens are supported in custom `/e` commands. They are replaced by RP Emote Menu before the emote is sent.

| Token           | Description                                               |
| :-------------- | :-------------------------------------------------------- |
| `{target}`      | Target's name without the realm                           |
| `{target-full}` | Target's name including the realm when applicable         |
| `{player}`      | Your character's name without the realm                   |
| `{player-full}` | Your character's name including the realm when applicable |

The **Targeted Command** is used only when another unit is targeted.

## Screenshot
<img width="418" height="426" alt="image" src="https://github.com/user-attachments/assets/7d182745-9eff-4da4-b215-408de047143a" />

------------------------------------------------------------------------

Copyright © 2026 Brandon Blackmoor (<bblackmoor@blackgate.net>)\
Licensed under the GNU General Public License v3.0:\
https://www.gnu.org/licenses/gpl-3.0.en.html\
Source: https://github.com/bblackmoor/rpemotemenu
