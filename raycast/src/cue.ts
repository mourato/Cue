import { open, showHUD, showToast, Toast } from "@raycast/api";

type CueRoute =
  | "capture/area"
  | "capture/active-window"
  | "capture/all-in-one"
  | "capture/area-annotate"
  | "capture/ocr"
  | "open/history"
  | "record/screen"
  | "record/application";

export async function launchCue(
  route: CueRoute,
  successMessage: string,
): Promise<void> {
  try {
    await open(`cue://${route}`);
    await showHUD(successMessage);
  } catch {
    await showToast({
      style: Toast.Style.Failure,
      title: "Cue is unavailable",
      message:
        "Install Cue and enable URL Scheme integration in Advanced settings.",
    });
  }
}
