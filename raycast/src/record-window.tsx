import { launchCue } from "./cue";

export default function Command() {
  return launchCue("record/application", "Cue window recording started");
}
