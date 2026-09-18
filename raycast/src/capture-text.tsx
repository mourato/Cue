import { launchCue } from "./cue";

export default function Command() {
  return launchCue("capture/ocr", "Cue text capture started");
}
