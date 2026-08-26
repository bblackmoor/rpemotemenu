# RP Emote Menu

## The Short Version

A customizable emote menu for **World of Warcraft** roleplayers.

- **Emotes:** Up to 100 emotes across 10 categories, with optional targeted commands.
- **Profiles:** Create, copy, rename, delete, and share character profiles.
- **Sharing:** Import or export individual categories and complete profiles.
- **Appearance:** Customize fonts, colors, selection effects, borders, opacity, and fading per profile.
- **Window:** Move, resize, minimize, or lock the menu, with a separate width for each column.
- **Commands:** `/rpem` toggles the menu; `/rpem config` opens its settings.

## Screenshots

<img width="263" height="220" hspace="2" vspace="2" alt="image" src="https://github.com/user-attachments/assets/1254befc-aff1-4d43-9d79-637b11d78cc6" />

<img width="274" height="274" hspace="2" vspace="2" alt="image" src="https://github.com/user-attachments/assets/f47248c0-2155-4d4a-a525-ebdbba53701d" />

<img width="298" height="318" hspace="2" vspace="2" alt="image" src="https://github.com/user-attachments/assets/6cd6da55-1187-41eb-99d0-a14bb8659515" />

<img width="400" height="270" hspace="2" vspace="2" alt="image" src="https://github.com/user-attachments/assets/74ddee17-9166-462c-a1f6-b70c77e40b82" />

<img width="400" height="270" hspace="2" vspace="2" alt="image" src="https://github.com/user-attachments/assets/7ca0d26d-5426-4716-b150-dbf3dc124c92" />

## Installation

Place the `RPEmoteMenu` folder in your World of Warcraft addons directory:

```text
World of Warcraft/_retail_/Interface/AddOns/RPEmoteMenu/
```

Enable **RP Emote Menu** from the character-selection screen's AddOns list if necessary.

## Getting Started

1. Enter `/rpem` to show or hide the menu.
2. Choose a category, then select an emote.
3. Open settings with the gear icon or `/rpem config`.
4. Under **Profiles**, create or copy a profile if you want to customize categories and emotes.
5. Under **Emotes**, choose a category and edit its name and commands.

The built-in **Default** profile is always available. Its categories and emotes are protected, but its window and appearance settings can be customized.

## Categories and Emotes

Each profile supports **10 categories** with up to **10 emotes** each. Open **Emotes** in the addon settings and choose a category from the dropdown.

Each emote includes:

- **Emote Label:** The text shown in the menu.
- **Default Command:** The command used when you have no other target.
- **Targeted Command:** An optional command used when targeting another unit.

Commands can use built-in emotes such as `/wave` or custom `/e` commands.

```text
Emote Label: Watches quietly
Default Command: /e watches quietly.
Targeted Command: /e watches {target} quietly.
```

An emote appears only when it has both a label and a default command. A category appears only when it has a name.

The **Emotes** screen can restore the selected category or every category in the current custom profile to the built-in set.

## Profiles

A profile contains its categories, emotes, window layout, and appearance. Profiles are available to all of your characters, while each character independently chooses which profile to use.

The **Default** profile has protected categories and is local only. It cannot be imported, exported, renamed, or deleted. Its window and appearance settings remain customizable and persistent.

The **Profiles** settings screen includes:

- **Create Profile:** Create a profile with the built-in categories and the current profile's settings.
- **Copy Profile:** Duplicate the current profile, including its categories, emotes, layout, and appearance.
- **Rename Profile:** Rename the current custom profile.
- **Delete Profile:** Delete the current custom profile after confirmation.
- **Export Profile:** Copy the current custom profile as JSON.
- **Import Profile:** Add a profile from exported JSON.

Imported profiles do not replace or activate existing profiles. If an imported name is already in use, the addon assigns the new profile a unique name. Deleting a profile returns characters using it to **Default**.

Profile names cannot be blank, exceed 64 characters, duplicate another name regardless of case, or use the reserved name **Default**.

## Import and Export

The **Emotes** screen can export the selected category or replace that category in the current custom profile with an imported one.

The **Profiles** screen can import or export one custom profile. The separate **Import & Export** screen can import or export all custom profiles at once.

Profile exports include sharable window settings, appearance, categories, and emotes. They do not include the local **Default** profile, character names, realms, character assignments, the last selected category, or the current minimized state.

All transfers use JSON text. Imports are validated before any existing category is replaced or any new profiles are added. Bulk imports skip **Default**, preserve existing profiles, and automatically rename conflicts.

## Fonts and Colors

The **Fonts & Colors** settings screen customizes the current profile:

- Separate fonts and font sizes for category names and emote labels.
- Category text, selected text, emote text, selection, background, and border colors.
- Selection effects: **Background**, **Outline**, **Separator**, **Underline**, or **Drop shadow**.
- Border styles: **None**, **Thin**, or **Blizzard**.
- Background opacity and active window opacity.
- Optional inactivity fading, with configurable delay and inactive opacity.

The font menus include WOW's built-in fonts and fonts made available by LibSharedMedia-3.0 (if any). A custom font may take 10 to 30 seconds to appear the first time it is selected.

Changes appear immediately. **Restore Defaults** resets the current profile's appearance.

## Window Settings

The **General** settings screen controls the current profile's window behavior and layout:

- Lock movement and resizing.
- Hide the settings gear icon.
- Show or hide the addon at login.
- Remember whether the window was minimized.
- Set the window position, height, left-column width, and right-column width.
- Restore the default position and size.

The window can also be moved and resized directly while it is unlocked. Its category pane scrolls when necessary, and the title-bar button minimizes or restores it.

## Slash Commands

| Command          | Description                    |
| :--------------- | :----------------------------- |
| `/rpem`          | Show or hide the RP Emote Menu |
| `/rpem config`   | Open the addon settings        |
| `/rpem options`  | Open the addon settings        |
| `/rpem settings` | Open the addon settings        |

## Target Tokens

Use these tokens in either command to include character names:

| Token      | Description                             |
| :--------- | :-------------------------------------- |
| `{target}` | Target's name without the realm         |
| `{player}` | Your character's name without the realm |

The **Targeted Command** is used only when another unit is targeted. Without a target, or when targeting yourself, the **Default Command** is used instead.

---

Copyright © 2026 Brandon Blackmoor (<bblackmoor@blackgate.net>)  
Licensed under the GNU General Public License v3.0 (GPL-3.0):  
https://www.gnu.org/licenses/gpl-3.0.en.html  
Source: https://github.com/bblackmoor/rpemotemenu
