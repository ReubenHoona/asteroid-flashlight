# asteroid-flashlight (eos)

The Flashlight of AsteroidOS on the Pixel Watch 2 ("eos"), made to behave like
the stock Wear OS Flashlight (`com.google.android.clockwork.flashlight`), with
an adjustable brightness while the light is on.

- Opens white. A tap turns the light red, the next tap off (black, grey icon),
  the next white again.
- While white or red the screen stays on at the torch's brightness, adaptive
  brightness paused; the user's brightness and adaptive brightness come back
  when the light goes off. The light goes off by itself after 2 minutes, when
  the display is turned off, and when the app leaves the front.
- The brightness of the light: the crown (10 % per detent, 10 to 100 %) or the
  + and - buttons of the control that shows for a moment (laid out as the
  stock brightness control). The level is remembered
  (`/org/asteroidos/flashlight/brightness`).
- While Bedtime or Extra dim holds the brightness the torch leaves it alone and
  the control is greyed out.

Brightness goes through mce (`org.asteroid.settings` DisplaySettings). The
QML tests are in `tests/qml` (qmltestrunner with the mocks of
`tests/qml/mocks`).

Upstream: https://github.com/AsteroidOS/asteroid-flashlight (GPL-3.0-or-later).
