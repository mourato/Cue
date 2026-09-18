import { launchCue } from "./cue";

export default function Command() {
  return launchCue("record/screen", "Cue screen recording started");
}
