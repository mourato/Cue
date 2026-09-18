import { launchCue } from "./cue";

export default function Command() {
  return launchCue(
    "capture/active-window",
    "Cue active-window capture started",
  );
}
