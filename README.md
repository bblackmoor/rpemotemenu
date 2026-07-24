# RP Emote Menu

A lightweight, configurable roleplaying emote menu for **World of
Warcraft**.

RP Emote Menu provides a compact, collapsible window that gives quick
access to your favorite roleplaying emotes and custom `/e` commands.
Emotes are organized into categories, and each entry can optionally use
a different command when another unit is targeted.

## Features

-   Up to **5 customizable categories**
-   Up to **10 emotes per category**
-   Editable category names, button labels, and commands from the
    in-game Settings panel
-   Optional targeted commands using `{target}`, `{target-full}`,
    `{player}`, and `{player-full}`
-   Collapsible, resizable, and lockable window
-   Remembers its position, size, and minimized state
-   Reset individual categories to their default values
-   Supports both built-in emotes (such as `/smile`) and custom `/e`
    emotes

## Slash Commands

| Command            | Description                    |
| :----------------- | :----------------------------- |
| `/emotes`          | Show or hide the RP Emote Menu |
| `/emotes config`   | Open the addon settings        |
| `/emotes options`  | Open the addon settings        |
| `/emotes settings` | Open the addon settings        |

## Target Tokens

| Token           | Description                               |
| :-------------- | :---------------------------------------- |
| `{target}`      | Target's name without the realm           |
| `{target-full}` | Target's name including the realm         |
| `{player}`      | Your character's name without the realm   |
| `{player-full}` | Your character's name including the realm |

The **Targeted Command** is used only when another unit is targeted.

## Screenshot

<img width="299" height="392" alt="image" src="https://github.com/user-attachments/assets/521b118e-d581-4186-8a34-a6b914fc86e7" />

------------------------------------------------------------------------

Copyright © 2026 Brandon Blackmoor (<bblackmoor@blackgate.net>)\
Licensed under the GNU General Public License v3.0:
https://www.gnu.org/licenses/gpl-3.0.en.html\
Source: https://github.com/bblackmoor/rpemotemenu
