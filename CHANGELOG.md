# Changelog

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
