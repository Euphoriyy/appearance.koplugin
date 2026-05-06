# Changelog

## [1.5.0](https://github.com/Euphoriyy/appearance.koplugin/compare/v1.4.0...v1.5.0) (2026-05-06)


### Features

* add about menu, in-plugin updater, and background update checks ([93d553b](https://github.com/Euphoriyy/appearance.koplugin/commit/93d553bb828c73d97f64e90d0a17365c956a9a8f)), closes [#41](https://github.com/Euphoriyy/appearance.koplugin/issues/41)
* **book/highlight_colors:** add option for setting the default color ([d50be25](https://github.com/Euphoriyy/appearance.koplugin/commit/d50be253726d9fedcc520b3a07d8a7f634694df0))
* **book:** apply background and font colors to footnote popups ([cc27611](https://github.com/Euphoriyy/appearance.koplugin/commit/cc27611d036f466297bf94c148879743f4432840)), closes [#45](https://github.com/Euphoriyy/appearance.koplugin/issues/45)
* **main:** implement method to delete plugin settings ([d2e22b5](https://github.com/Euphoriyy/appearance.koplugin/commit/d2e22b52410761b53259817d20ca2d5e8a22989b)), closes [#48](https://github.com/Euphoriyy/appearance.koplugin/issues/48)
* migrate plugin settings and add menu to plugin ([46319df](https://github.com/Euphoriyy/appearance.koplugin/commit/46319dfd7f42d92b264ad2f774c74f704cde8aa6)), closes [#49](https://github.com/Euphoriyy/appearance.koplugin/issues/49)
* **themes:** add option to reset theme link color ([487e515](https://github.com/Euphoriyy/appearance.koplugin/commit/487e5153073c227be3de1da68637866743661bea))
* **ui/background_image:** add transparency level and background color blending ([836a259](https://github.com/Euphoriyy/appearance.koplugin/commit/836a2598dd9a09235c421008eab32876a643a2d4)), closes [#42](https://github.com/Euphoriyy/appearance.koplugin/issues/42)
* **ui/transparency:** add transparent SimpleUI bottom bar setting ([09deecc](https://github.com/Euphoriyy/appearance.koplugin/commit/09deecc071a4e762d86c78010a321aaa59e1aedb)), closes [#32](https://github.com/Euphoriyy/appearance.koplugin/issues/32)
* **ui:** add optional system fonts support ([e9d6e97](https://github.com/Euphoriyy/appearance.koplugin/commit/e9d6e9766836fa25829de275db02f8f6187db5db))
* **widgets/colorwheelwidget:** add border to color wheel for better visibility ([c1aecdb](https://github.com/Euphoriyy/appearance.koplugin/commit/c1aecdb9cd3626499287f42fa1ecbf484a192dde))


### Bug Fixes

* **book/background_color:** only use Android recolor paths when using the C blitter ([92bf77e](https://github.com/Euphoriyy/appearance.koplugin/commit/92bf77e2c295cae746e04876e888948717ad3c5d))
* **book/link_color:** clear computed_hex when reverting to default link color ([7d02958](https://github.com/Euphoriyy/appearance.koplugin/commit/7d029587b12f44815f01e9bcc55957c573b2a318))
* **book/link_color:** disable "Reset color" when no custom link color is set ([915d266](https://github.com/Euphoriyy/appearance.koplugin/commit/915d266a26ee159c89bb4e88e7fd68d31214b056))
* **themes:** only show reset link color button when theme has a link color set ([e3e94fd](https://github.com/Euphoriyy/appearance.koplugin/commit/e3e94fdaabb4f9d464e3ad09d9a185bfc6bf6389))
* **ui/background_color:** correct highlight background inversion for buttons ([aad9439](https://github.com/Euphoriyy/appearance.koplugin/commit/aad9439ab0ca84246b91ae035564859ce93b2bf1))
* **ui/background_image:** restore compatibility with SimpleUI's currently reading module ([3be99bc](https://github.com/Euphoriyy/appearance.koplugin/commit/3be99bc1df114315c372438746d7985218a1c857)), closes [#51](https://github.com/Euphoriyy/appearance.koplugin/issues/51)


### Performance Improvements

* **book/background_color:** skip color application for fixed-layout docs when color is default ([f770bb8](https://github.com/Euphoriyy/appearance.koplugin/commit/f770bb800399a53f16c877194d29b5ab406dbe6e))

## [1.4.0](https://github.com/Euphoriyy/appearance.koplugin/compare/v1.3.7...v1.4.0) (2026-04-25)


### Features

* add book link color setting and integrate it into the theme system ([18c8d63](https://github.com/Euphoriyy/appearance.koplugin/commit/18c8d636a0b82d11dd26b6484a579c9a1de25192))
* **background-image:** add menu item to switch to last background image ([1995de4](https://github.com/Euphoriyy/appearance.koplugin/commit/1995de4eb501b66bde5c2a626914409bc801bb8f))
* **book/background_color:** add dispatcher actions for toggling fixed page background color ([ad5d9cd](https://github.com/Euphoriyy/appearance.koplugin/commit/ad5d9cd8631abd2f18e71c831813249d523d3a99))
* **book:** add highlight color customization menu to book settings ([d06f3a8](https://github.com/Euphoriyy/appearance.koplugin/commit/d06f3a84938610a1c639931006314eda6937c3d6)), closes [#27](https://github.com/Euphoriyy/appearance.koplugin/issues/27)
* **book:** add progress bar roundness settings with adjustable radius and rounded fill toggle ([fcce0a6](https://github.com/Euphoriyy/appearance.koplugin/commit/fcce0a6758eb9b86a61e7267f273128739173780))
* **ui/background_image:** cap image history to 20 entries with startup prune ([aec1db2](https://github.com/Euphoriyy/appearance.koplugin/commit/aec1db2c36f3f7e10a0ec9168794e21712540adf))
* **ui:** add dictionary font replacement setting ([af8de5d](https://github.com/Euphoriyy/appearance.koplugin/commit/af8de5dad635138af095402aa5453cc36823063d))
* **widgets:** apply UI font color settings to AlphaTextBoxWidget ([5f690f8](https://github.com/Euphoriyy/appearance.koplugin/commit/5f690f8687238ec675e56ed9c6af6c5dee711e3d))


### Bug Fixes

* **book/background_color:** refresh fixed-layout pages and consolidate refresh calls ([67f6027](https://github.com/Euphoriyy/appearance.koplugin/commit/67f6027dfa926e93f690ca05d7703625d2a8bab9))
* **book/background_color:** skip RedrawCurrentPage when set_fixed_color is disabled ([7dced54](https://github.com/Euphoriyy/appearance.koplugin/commit/7dced541bea46dac6acf5cacc60c760e19cda539))
* **book/highlight_colors:** add reflowable document support ([f085716](https://github.com/Euphoriyy/appearance.koplugin/commit/f085716b15396a31b4c35de782a6410112b590ac))
* **book/highlight_colors:** use static default hex values instead of Blitbuffer.HIGHLIGHT_COLORS ([2deebed](https://github.com/Euphoriyy/appearance.koplugin/commit/2deebed7bf89ea5558348fafeb0e9626f51ce984))
* **book/link_color:** guard against nil hex when using default link color ([b66aed3](https://github.com/Euphoriyy/appearance.koplugin/commit/b66aed3ec2a2457d4967a671cd5e8d6271edd2b4))
* guard touchmenu_instance before calling updateItems in color menus ([3244749](https://github.com/Euphoriyy/appearance.koplugin/commit/3244749f1500b323d4fd6ddf3f2a3ed7f73cb1fb))
* handle nil from getCssText and getHtmlDictionaryCss ([90687ab](https://github.com/Euphoriyy/appearance.koplugin/commit/90687abd9d4e3bfa6b4e80e46644a0f74635fe2d)), closes [#35](https://github.com/Euphoriyy/appearance.koplugin/issues/35)
* replace named colors with hex values for edit menu button backgrounds ([9df9b97](https://github.com/Euphoriyy/appearance.koplugin/commit/9df9b978bceb8793959cb6c42363402480ec954e))
* restore custom highlight color name display on nightly by hooking init and editHighlightColor ([56bfb72](https://github.com/Euphoriyy/appearance.koplugin/commit/56bfb7285e0df3d70f4fa5fd94eef7a18e26068b))
* **themes:** prevent skipping link color when editing existing theme ([574c2f2](https://github.com/Euphoriyy/appearance.koplugin/commit/574c2f2158a55478b59712231dafd9f4b58744e9))
* **ui/background_image:** skip adding duplicate entries to image history ([8ba183c](https://github.com/Euphoriyy/appearance.koplugin/commit/8ba183c6a1c28a79e1745d6911803eda44e0a8cd))

## [1.3.7](https://github.com/Euphoriyy/appearance.koplugin/compare/v1.3.6...v1.3.7) (2026-04-17)


### Bug Fixes

* **ui/background_image:** missing side padding on widgets in SimpleUI homescreen ([14e9b86](https://github.com/Euphoriyy/appearance.koplugin/commit/14e9b86a2cca713b95b6711f1bc106a43e750892))
* **ui/font_color:** apply font color on non-color screens ([91f68f7](https://github.com/Euphoriyy/appearance.koplugin/commit/91f68f77d87afca763c1ccd2849bca4fa6efdbb9))
* **widgets/colorwheelwidget:** cap wheel cache and free FFI buffers on rebuild and close ([21f2bf6](https://github.com/Euphoriyy/appearance.koplugin/commit/21f2bf60581f168347b06778a86a1181998592ad))

## [1.3.6](https://github.com/Euphoriyy/appearance.koplugin/compare/v1.3.5...v1.3.6) (2026-04-12)


### Bug Fixes

* **ui/background_image:** save last background image before unsetting ([8bcd2fa](https://github.com/Euphoriyy/appearance.koplugin/commit/8bcd2faa369ecd776312408640fafeda67e86889))
* **ui/background_image:** use sensible default path in image picker ([8439082](https://github.com/Euphoriyy/appearance.koplugin/commit/8439082c36c4765ada22908d4e0caf4302d4647c))
* **ui:** prevent color patches from overriding transparent TextBoxWidgets ([f7343da](https://github.com/Euphoriyy/appearance.koplugin/commit/f7343daa4a703c95b786e4301d200aff7aa5f479))

## [1.3.5](https://github.com/Euphoriyy/appearance.koplugin/compare/v1.3.4...v1.3.5) (2026-04-12)


### Bug Fixes

* **ui/background_image:** make SimpleUI quotes aligned properly ([4243b4d](https://github.com/Euphoriyy/appearance.koplugin/commit/4243b4da93571deec73d0c500e4fa2c6361dce60)), closes [#19](https://github.com/Euphoriyy/appearance.koplugin/issues/19)

## [1.3.4](https://github.com/Euphoriyy/appearance.koplugin/compare/v1.3.3...v1.3.4) (2026-04-11)


### Bug Fixes

* **book/progress_bar_colors:** footer settings setter failing when not in a book ([778914f](https://github.com/Euphoriyy/appearance.koplugin/commit/778914fce9776ab55b8edab75bb193c1bcce4576))
* **ui/font_face:** add nil check when retrieving the bold path of a font ([04da70c](https://github.com/Euphoriyy/appearance.koplugin/commit/04da70c8e5c2ccc93b7ee8c14fe63972b46cf6d7))

## [1.3.3](https://github.com/Euphoriyy/appearance.koplugin/compare/v1.3.2...v1.3.3) (2026-04-10)


### Bug Fixes

* **book/progress_bar_colors:** footer settings getter failing when not in a book ([136910d](https://github.com/Euphoriyy/appearance.koplugin/commit/136910d1df02c96e5dc3f5bba4a875ad924db478))

## [1.3.2](https://github.com/Euphoriyy/appearance.koplugin/compare/v1.3.1...v1.3.2) (2026-04-10)


### Bug Fixes

* **book/progress_bar_colors:** add missing function for getting footer settings ([8d9af0a](https://github.com/Euphoriyy/appearance.koplugin/commit/8d9af0a21c805014c7178eee0e6ef756f3e45807))

## [1.3.1](https://github.com/Euphoriyy/appearance.koplugin/compare/v1.3.0...v1.3.1) (2026-04-10)


### Bug Fixes

* **ui/background_color:** correct SimpleUI reading goals progress bar fg/bg colors ([7a38104](https://github.com/Euphoriyy/appearance.koplugin/commit/7a3810483f70393ea2cef4c2dfaa934e7668d03c))

## [1.3.0](https://github.com/Euphoriyy/appearance.koplugin/compare/v1.2.0...v1.3.0) (2026-04-10)


### Features

* **ui/font_face:** show “(no bold)” label for fonts missing bold variant ([c6ae338](https://github.com/Euphoriyy/appearance.koplugin/commit/c6ae338e6e4c9383bf13ca3c874b14e1813fb230))


### Bug Fixes

* **ui/background_image:** update patching of SimpleUI to match latest version ([a5b491c](https://github.com/Euphoriyy/appearance.koplugin/commit/a5b491c98bb60441db909bffa3621f5a45c7ab24)), closes [#10](https://github.com/Euphoriyy/appearance.koplugin/issues/10)
* **ui/font_color:** apply ToggleSwitch update without delayed scheduling ([27ce86a](https://github.com/Euphoriyy/appearance.koplugin/commit/27ce86a863bcc393cce3a4688c3f9c030d2cd34e))


### Performance Improvements

* **ui/background_image:** close picture document after use ([12bfa65](https://github.com/Euphoriyy/appearance.koplugin/commit/12bfa6526269320c862d10c1f62c8b5207fd5e52))

## [1.2.0](https://github.com/Euphoriyy/appearance.koplugin/compare/v1.1.2...v1.2.0) (2026-04-10)


### Features

* **book:** add progress bar color customization menu ([ef214e5](https://github.com/Euphoriyy/appearance.koplugin/commit/ef214e5d28a5b4a7dd095c7f2518fd3e5d0c8b2a))
* **ui:** add UI font replacement menu ([3923d43](https://github.com/Euphoriyy/appearance.koplugin/commit/3923d436fe38a17da9275889f18a03469cf59250))

## [1.1.2](https://github.com/Euphoriyy/appearance.koplugin/compare/v1.1.1...v1.1.2) (2026-04-08)


### Bug Fixes

* **ui/background_image:** use fgcolor for SimpleUI progress bar track background ([8b2ee4f](https://github.com/Euphoriyy/appearance.koplugin/commit/8b2ee4f07e994406e26406ee120b3a29c8647751))

## [1.1.1](https://github.com/Euphoriyy/appearance.koplugin/compare/v1.1.0...v1.1.1) (2026-04-08)


### Bug Fixes

* **ui/background_color:** correct SimpleUI progress bar fg/bg colors ([5adac75](https://github.com/Euphoriyy/appearance.koplugin/commit/5adac7543ac2608d943fc914d2c126bd5a79bf68))
* **ui/background_image:** SimpleUI quotes having opaque backgrounds ([037c209](https://github.com/Euphoriyy/appearance.koplugin/commit/037c209db028bc828739cf70290b5e66c0297251))

## [1.1.0](https://github.com/Euphoriyy/appearance.koplugin/compare/v1.0.0...v1.1.0) (2026-04-08)


### Bug Fixes

* themes module not being packaged with releases ([58e03af](https://github.com/Euphoriyy/appearance.koplugin/commit/58e03af6a8f4a9b4184d0c5abbecfce881e59d58))

## 1.0.0 (2026-04-08)


### Features

* add automatic packaging workflow ([87b1d34](https://github.com/Euphoriyy/appearance.koplugin/commit/87b1d34bdc18e80a59380b2c2ae82042231de273))
* add Book menu with book-specific color settings ([9dd1a72](https://github.com/Euphoriyy/appearance.koplugin/commit/9dd1a72592b4a8f3cfa639b4b781f09f7e02f611))
* add book-specific themes with UI/Book/Both target selection ([9806eb1](https://github.com/Euphoriyy/appearance.koplugin/commit/9806eb1785eccd57dee6538b33ffff467bbc7452))
* add purple theme named "Wisteria Night" ([fb94d12](https://github.com/Euphoriyy/appearance.koplugin/commit/fb94d12238974643a52f630c1a699f428406f076))
* add setting to use book background color for reader UI sides and gaps ([aa394c1](https://github.com/Euphoriyy/appearance.koplugin/commit/aa394c1774a268903084b08066329ababb65158f))
* add UI border color setting using foreground color ([2f2087c](https://github.com/Euphoriyy/appearance.koplugin/commit/2f2087cdb1b7c5326813410ef0186dbf963b5c45))
* change default settings for background color application in the reader ([de0b453](https://github.com/Euphoriyy/appearance.koplugin/commit/de0b4530545769960492daee0b73c1850d4a7d24))
* expose bgcolor/fgcolor accessors and add UI outline color setting ([3a18405](https://github.com/Euphoriyy/appearance.koplugin/commit/3a18405948df00a33281ed1dd71c5f3f5999ed82))
* init plugin & import from patches ([b9154e2](https://github.com/Euphoriyy/appearance.koplugin/commit/b9154e23e9bc4aa1449f0a9687c7dcdf983c8d96))
* **themes:** add dispatcher actions for selecting day/night UI and book themes ([b30c00b](https://github.com/Euphoriyy/appearance.koplugin/commit/b30c00bfdf5bbf0d3439c501aa0e7c5748e9a751))
* **ui/background_image:** add dispatcher action for selecting background image ([2f9ec82](https://github.com/Euphoriyy/appearance.koplugin/commit/2f9ec82265092b51e97d69a819f874b3fdbeedd2))
* **ui/background_image:** add dispatcher action for setting last background image ([62f8429](https://github.com/Euphoriyy/appearance.koplugin/commit/62f8429434629d6524a17e37f5ab66fe93aabfdb))
* **ui/background_image:** add support for SimpleUI's homescreen ([adffebb](https://github.com/Euphoriyy/appearance.koplugin/commit/adffebb3bf92d51fc8f2ae18f1d561065704d83b))
* **ui/background_image:** enable "Show in homescreen" option only if SimpleUI is enabled ([24a975e](https://github.com/Euphoriyy/appearance.koplugin/commit/24a975e67ae27e85f9abe1f92ba1e161f36e6869))


### Bug Fixes

* default footer to transparent to match book background color ([245886f](https://github.com/Euphoriyy/appearance.koplugin/commit/245886fd26ecd07e84aa2aba33f645a84f89db9d))
* lowercase "interface" in User Interface menu title ([ac54b46](https://github.com/Euphoriyy/appearance.koplugin/commit/ac54b4683564886bf9fea91d92046c77a780411d))
* replace MultiConfirmBox with new TripleConfirmBox widget to support three choices ([51b02de](https://github.com/Euphoriyy/appearance.koplugin/commit/51b02deca69d36e692eaec27dee98ab093562f57))
* **ui/background_color:** exclude button dialog/table buttons from transparency ([6a49d07](https://github.com/Euphoriyy/appearance.koplugin/commit/6a49d07b5143d8db5e358088e202ae1854daaa4e))
* **ui/background_image:** replace opaque title label on SimpleUI homescreen ([9afa312](https://github.com/Euphoriyy/appearance.koplugin/commit/9afa312441d0e66e6b5d8da39d15acd0f1c300a6))
* **ui/transparency:** remove unnecessary UI restart when toggling button transparency ([9ed8446](https://github.com/Euphoriyy/appearance.koplugin/commit/9ed84468ade2921033d49600604146fd6a2aeafb))
* **widgets/colorwheelwidget:** background behind color wheel does not match UI ([8ee2cd6](https://github.com/Euphoriyy/appearance.koplugin/commit/8ee2cd632009826466b3ea9c6422feb38bba0d47))


### Performance Improvements

* lazy load font and book color modules in paint functions ([c0b6ecb](https://github.com/Euphoriyy/appearance.koplugin/commit/c0b6ecb863bd4c4d4e09c75d7dab14d6872faebe))
