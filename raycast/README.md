# Cue for Raycast

Direct Raycast commands for Cue's capture, annotation, OCR, history, and recording flows.

The extension only opens Cue's existing `cue://` routes. Cue remains responsible for permissions, capture settings, clipboard output, Quick Access, Annotate, history, and recording controls.

## Commands

- Capture Area
- Capture Active Window
- Capture All-In-One
- Capture Area + Annotate
- Capture Text (OCR)
- Open History
- Record Screen
- Record Window

Recording commands require a Cue build with `CUE_VIDEO_MODULE` enabled. The recording toolbar in Cue chooses Video or GIF output and owns pause, resume, and stop controls.

## Development

```sh
npm install
npm run lint
npm run typecheck
npm run build
```

The Cue app must be installed with URL Scheme integration enabled. Screen Recording, Accessibility, and Microphone permissions remain Cue responsibilities.
