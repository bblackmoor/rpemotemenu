# RP Emote Menu

## The Short Version

A customizable emote menu for **World of Warcraft** roleplayers.

- **Emotes:** Up to 100 across 10 categories, including targeted commands.
- **Profiles:** Create, copy, rename, delete, and share character profiles.
- **Sharing:** Import or export individual categories and complete profiles.
- **Appearance:** Customize fonts, colors, borders, opacity, and smooth fading.
- **Window:** Move, resize, minimize, or lock the menu.
- **Commands:** `/rpem` toggles the menu; `/rpem config` opens settings.

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

Enable **RP Emote Menu** from the character-selection screen's AddOns list if
necessary.

## Getting Started

1. Enter `/rpem` to show or hide the menu.
2. Choose a category and select an emote.
3. Open settings using the gear icon or `/rpem config`.
4. Under **Profiles**, create a profile before making changes.
5. Under **Categories**, choose a category from the dropdown and edit its emotes.

The included **Default** profile is protected. New profiles begin with the
default categories and emotes.

## Categories and Emotes

Each profile supports **10 categories** with up to **10 emotes** each. Open
**Categories** in the addon settings and choose a category from the dropdown.

Each emote includes:

- **Emote Label:** The name shown in the menu.
- **Default Command:** The command used when you have no other target.
- **Targeted Command:** An optional command used when targeting someone else.

Commands can use built-in emotes such as `/wave` or custom `/e` commands.

```text
Emote Label: Watches quietly
Default Command: /e watches quietly.
Targeted Command: /e watches {target} quietly.
```

An emote appears only when it has both a label and a default command. Categories
without names remain hidden from the main menu.

## Profiles

A profile contains every category and emote. Profiles are available to all of
your characters, and each character can choose a different active profile.

The **Default** profile cannot be edited, renamed, deleted, or used for category
imports. Create or copy a profile to customize your emotes.

The **Profiles** settings screen includes:

- **Create Profile:** Start a new profile with the default categories.
- **Copy Profile:** Duplicate the currently selected profile.
- **Rename Profile:** Rename the selected custom profile.
- **Delete Profile:** Delete the selected custom profile after confirmation.
- **Export Profile:** Copy the complete profile for sharing.
- **Import Profile:** Import a shared profile using a new profile name.

When a profile is deleted, characters using it return to **Default**.

Profile names cannot be blank, exceed 64 characters, duplicate another name
regardless of case, or use the reserved name **Default**.

## Import and Export

The **Categories** screen includes **Export** and **Import** buttons for the
selected category. Importing replaces that category in the current editable
profile.

The **Profiles** screen includes **Export Profile** and **Import Profile**.
Importing a profile creates a new profile; it does not overwrite an existing
profile or change **Default**.

Categories and profiles are shared as JSON text. Invalid imports do not replace
your existing emotes.

## Fonts and Colors

The **Fonts and Colors** settings screen lets you adjust:

- Font size and text color for category names and emote labels.
- Background color and opacity.
- Border color and style: **None**, **Thin**, or **Blizzard**.
- Window opacity while active.
- Optional smooth fading after inactivity, including the delay and faded
  opacity.

Changes appear immediately and apply to every profile. Select
**Reset Appearance** to restore the original appearance.

## Window Settings

The **General** settings screen lets you lock the window, hide the settings
gear, choose whether the menu appears when you log in, and remember whether it
was minimized.

You can also adjust or reset the window's position and size. Category settings
include an individual reset, and **General** can reset every category in the
current editable profile.

## Slash Commands

| Command          | Description                    |
| :--------------- | :----------------------------- |
| `/rpem`          | Show or hide the RP Emote Menu |
| `/rpem config`   | Open the addon settings        |
| `/rpem options`  | Open the addon settings        |
| `/rpem settings` | Open the addon settings        |

## Target Tokens

Use these tokens in emote commands to include character names:

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
