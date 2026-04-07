# appearance.koplugin

The ultimate plugin to customize <img src="img/koreader.png" width="24" /> KOReader's appearance in any way you would like!

## Features

| Category | What you can change |
|---|---|
| **Themes** | Apply full UI & book themes with one tap |
| **Colors** | Customize background and font colors |
| **Color wheel** | Choose colors with a visual RGB color wheel  |
| **Page style** | Adjust page colors for a comfortable reading experience (both reflowable & fixed-layout documents such as EPUBs, PDFs, DJVUs, & CBZs) |
| **Backgrounds** | Set custom background images (like a wallpaper) |

## Installation
1. Download the latest release.
2. Copy the `appearance.koplugin` directory to the `koreader/plugins` folder on your device.
3. Restart KOReader.

## Configuration
The plugin can be fully configured under the new **Appearance** menu on the <sub><img src="img/appbar.settings.svg" style="width:2%; height:auto;"></sub> **Settings** tab. The appearance of the *User interface* and *Book* can be configured separately as well together via *Themes*.

## Usage

<details>
<summary><strong>Applying a Theme</strong></summary>

<br>

Navigate to **🞂 Appearance 🞂 Themes** and select any theme from the list. The UI updates instantly without needing to restart.
 
To go back to the default look, choose **🞂 Appearance 🞂 Themes 🞂 Reset themes 🞂 Reset to default themes**. This clears all theme overrides and restores KOReader's original colors.

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

Go to **🞂 Appearance 🞂 Background image** and pick an image from your device storage. The background will apply immediately across the UI.

You can select where you want the background image to be shown, such as in the file browser, reader, the top menu, and SimpleUI homescreen.
 
To remove it, return to the same menu and hold down on the currently selected image.

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
 
Each color can be chosen by color picker and code. Changes apply live so you can preview as you go. There are **Advanced settings** as well that allow you to experiment with more fine-tuned tweaking.

</details>

## Compatibility
Tested fully on e-ink, desktop, and mobile devices. Fully compatible with popular plugins like [Rakuyomi](https://github.com/tachibana-shin/rakuyomi) and [SimpleUI](https://github.com/doctorhetfield-cmd/simpleui.koplugin).

For rounded book & folder covers to work properly with the background color, [my special rounded cover patches](https://github.com/Euphoriyy/KOReader.patches#-2-rounded-coverslua) should be used.

## Acknowledgements
- Features originally integrated from [my KOReader patches](https://github.com/Euphoriyy/KOReader.patches).
- Theming functionality inspired by [2-color-theme.lua](https://github.com/artemartemenko/koreader-color-themes) by [@artemartemenko](https://github.com/artemartemenko).

## License
This project is licensed under the **GNU General Public License v3.0**.
See the [LICENSE](./LICENSE) file for full details.
