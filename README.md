# appearance.koplugin

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![GitHub Release](https://img.shields.io/github/v/release/Euphoriyy/appearance.koplugin)](https://github.com/Euphoriyy/appearance.koplugin/releases)
[![Lua](https://img.shields.io/badge/Lua-%232C2D72.svg?logo=lua&logoColor=white)](#)

The ultimate plugin to customize [<img src="img/koreader.png" width="24" /> KOReader](https://koreader.rocks)'s appearance in any way you would like! It adds features that are similar to those found in other ebook readers like [Readest](https://readest.com), [Librera](https://librera.mobi), & [Moon+ Reader](https://moondownload.com), making it the ideal reader.

## Features

| Category | What you can change |
|---|---|
| **Themes** | Apply full UI & book themes with one tap |
| **Colors** | Customize background, font, link, highlight, and progress bar colors |
| **Color wheel** | Choose colors with a visual RGB color wheel |
| **Font** | Customize your own unique UI and dictionary fonts |
| **Page style** | Adjust page colors for a comfortable reading experience (both reflowable & fixed-layout documents such as EPUBs, PDFs, DJVUs, & CBZs) |
| **Backgrounds** | Set custom background images (like a wallpaper) |

## Installation
1. Download the latest release.
2. Extract the `appearance.koplugin` directory from the archive.
3. Move the `appearance.koplugin` directory to the `koreader/plugins` folder on your device.
4. Restart KOReader.

## Configuration
The plugin can be fully configured under the new **Appearance** menu on the <sub><img src="img/appbar.settings.svg" style="width:2%; height:auto;"></sub> **Settings** tab. The appearance of the *User interface* and *Book* can be configured separately as well together via *Themes*.

## Usage

<details>
<summary><strong>Applying a Theme</strong></summary>

<br>

Navigate to **🞂 Appearance 🞂 Themes** and select any theme from the list. The UI updates instantly without needing to restart.
 
To go back to the default look, choose **🞂 Appearance 🞂 Themes 🞂 Reset themes 🞂 Reset to default themes**. This clears all theme overrides and restores KOReader's original colors.

Themes can also be selected automatically using dispatcher actions (e.g., via profiles or gestures).

</details>

<details>
<summary><strong>Adding/Configuring Themes</strong></summary>

<br>

Themes can be added by pressing **🞂 Appearance 🞂 Themes 🞂 Add a theme**, from there you can choose the background and foreground colors for the theme.

Themes can be configured by holding down on them when selecting them from the list. Then, an option menu will show that gives you the ability to rename, change the colors of, and delete the theme.

</details>

<details>
<summary><strong>Setting a Background Image</strong></summary>
 
<br>

Go to **🞂 Appearance 🞂 User interface 🞂 Background image** and pick an image from your device storage. The background will apply immediately across the UI.

You can select where you want the background image to be shown, such as in the file browser, reader, the top menu, and SimpleUI homescreen.
 
To remove it, return to the same menu and hold down on the currently selected image.

A background image can also be automatically set/changed by using the "Select background image" action in profiles. This allows you to set one of the past background images automatically or by gestures.

</details>
 
<details>
<summary><strong>Changing Colors</strong></summary>

<br>

Under **🞂 Appearance 🞂 User interface**:
 
- **Background color** - the main canvas behind text and UI elements
- **Font color** - the color of all rendered text

Under **🞂 Appearance 🞂 Book**:
 
- **Background color** - the color of the page background
- **Font color** - the color of the page text
- **Link color** - the color of the page links
- **Highlight colors** - the colors used when annotating (each name can also be edited)
- **Progress bar colors** - the read/unread colors of the book progress bar in the footer
 
Each color can be chosen by color picker and code. Changes apply live so you can preview as you go. There are **Advanced settings** as well that allow you to experiment with more fine-tuned tweaking.

</details>

<details>
<summary><strong>Changing the UI/Dictionary Font</strong></summary>

<br>

Go to **🞂 Appearance 🞂 User interface 🞂 Font** or **🞂 Appearance 🞂 User interface 🞂 Dictionary font**. From there you will see a list of the fonts found (the exact same as the ones for books), and you can select whatever font you would like.

If at any time, you would like the original look, you can toggle **Enable font replacement** to disable your changes.

The supported font formats are `.ttf`, `.otf`, `.pfb`, and `.pfa`.

These are the folders where you may place your fonts:
- Android/Boox: `koreader/fonts/`
- PocketBook: `applications/koreader/fonts` (Create the folder) 
- Kobo: `.adds/koreader/fonts` (Create the folder)
- Desktop/Linux: Install the font for the system *OR* `.local/share/fonts`

[For more information, read here.](https://github.com/koreader/koreader/wiki/Fonts)

</details>

## Compatibility
Tested fully on e-ink, desktop, and mobile devices. Fully compatible with popular plugins like [Rakuyomi](https://github.com/tachibana-shin/rakuyomi) and [SimpleUI](https://github.com/doctorhetfield-cmd/simpleui.koplugin).

PDF background color customization is compatible with the dual pages feature introduced by [ComicReader](https://github.com/KORComic/comicreader.koplugin) by [@OGKevin](https://github.com/OGKevin).

For rounded book & folder covers to work properly with the background color, [my special rounded cover patches](https://github.com/Euphoriyy/KOReader.patches#-2-rounded-coverslua) should be used.

## Acknowledgements
- Features originally integrated from [my KOReader patches](https://github.com/Euphoriyy/KOReader.patches).
- Theming functionality inspired by [2-color-theme.lua](https://github.com/artemartemenko/koreader-color-themes) by [@artemartemenko](https://github.com/artemartemenko).
- The packaging system in use is based on work from [ComicReader](https://github.com/KORComic/comicreader.koplugin).
- UI font replacement based on the based on the patch [2--ui-font.lua](https://github.com/sebdelsol/KOReader.patches/#-2-ui-font) by [@sebdelsol](https://github.com/sebdelsol).
- Dictionary font replacement based on the patch [2-custom-ui-fonts.lua](https://github.com/gennaro-tedesco/KOReader.patches/#2-custom-ui-fonts) by [@gennaro-tedesco](https://github.com/gennaro-tedesco).

## Support
If you want to support me, you can star this repository or buy me a coffee. :)

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/X8X21UH4E1)

## License
This project is licensed under the **GNU General Public License v3.0**.
See the [LICENSE](./LICENSE) file for full details.
