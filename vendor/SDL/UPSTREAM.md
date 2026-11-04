# Vendored CangjieSDL

Source: https://gitcode.com/CangjieArts/SDL.git
Version: 0.9.6
Base revision: 79afc41fed8436df2dc9fe1ba7046a7ee3d20b93
License: MIT (see LICENSE).

This directory is included as ordinary source, not an external Git submodule.
The Windows x64 runtime/link DLLs in .sdl3 must be included in submissions.
Existing local changes in src/window.cj and src/window_spec.cj add transparent,
borderless and always-on-top window options. These changes are preserved.
SDL, SDL_image, SDL_ttf and font license notices are in the project's licenses/.

Local src/renderer.cj also adds fitCanvas for a centered, proportionally scaled
canvas. Native text passes preserve its physical viewport while rasterizing at
the fitted pixel size. Explicit viewport changes clear the canvas override.

Local src/window_icon.cj exposes SDL_SetWindowIcon with renderer-thread and
surface-lifetime checks, following the local Firebreak binding extension.
