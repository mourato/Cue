import Foundation

enum CueL10n {
    static let cloudflareMissingWorkerURL = L10n.Cue.cloudflareMissingWorkerURL
    static let cloudflareMissingToken = L10n.Cue.cloudflareMissingToken
    static let cloudflareInvalidResponse = L10n.Cue.cloudflareInvalidResponse
    static let cloudflareUploadFailed = L10n.Cue.cloudflareUploadFailed
    static let cloudflareOffline = L10n.Cue.cloudflareOffline
    static let noteTool = L10n.Cue.noteTool
    static let noteToolGestureHint = L10n.Cue.noteToolGestureHint
    static func noteToolTooltip(title: String, gestureHint: String = noteToolGestureHint) -> String {
        L10n.Cue.noteToolTooltip(title: title, gestureHint: gestureHint)
    }

    static let noteEditorTitle = L10n.Cue.noteEditorTitle
    static let noteEditorPlaceholder = L10n.Cue.noteEditorPlaceholder
    static let save = L10n.Cue.save
    static let cancel = L10n.Cue.cancel
    static let sidePanelTitle = L10n.Cue.sidePanelTitle
    static let sidePanelEmpty = L10n.Cue.sidePanelEmpty
    static let emptyNoteLabel = L10n.Cue.emptyNoteLabel
    static let deleteNote = L10n.Cue.deleteNote
    static let noteEditorColorButton = L10n.Cue.noteEditorColorButton
    static let noteEditorDragHint = L10n.Cue.noteEditorDragHint
    static let pointTargetLabel = L10n.Cue.pointTargetLabel
    static let rectTargetLabel = L10n.Cue.areaTargetLabel
    static let areaStyleOutline = L10n.Cue.areaStyleOutline
    static let areaStyleTinted = L10n.Cue.areaStyleTinted
    static let areaStyleHatched = L10n.Cue.areaStyleHatched
    static let areaStylePickerLabel = L10n.Cue.areaStylePicker
    static let areaStrokeWidthLabel = L10n.Cue.areaStrokeWidthLabel
    static let colorRed = L10n.Cue.colorRed
    static let colorOrange = L10n.Cue.colorOrange
    static let colorBlue = L10n.Cue.colorBlue
    static let colorGreen = L10n.Cue.colorGreen
    static let colorPurple = L10n.Cue.colorPurple
    static let colorMagenta = L10n.Cue.colorMagenta
    static let colorBlack = L10n.Cue.colorBlack
    static let colorYellow = L10n.Cue.colorYellow
    static let colorGray = L10n.Cue.colorGray
    static let colorWhite = L10n.Cue.colorWhite
    static let colorDarkGray = L10n.Cue.colorDarkGray
    static let colorMediumGray = L10n.Cue.colorMediumGray
    static let colorLightGray = L10n.Cue.colorLightGray
    static let colorPink = L10n.Cue.colorPink
    static let colorNearWhite = L10n.Cue.colorNearWhite
    static let settingsSection = L10n.Cue.settingsSection
    static let panelSideTitle = L10n.Cue.panelSideTitle
    static let panelSideDescription = L10n.Cue.panelSideDescription
    static let left = L10n.Cue.left
    static let right = L10n.Cue.right
    static let imgbbMissingAPIKey = L10n.Cue.imgbbMissingAPIKey
    static let imgbbInvalidImageData = L10n.Cue.imgbbInvalidImageData
    static let imgbbInvalidResponse = L10n.Cue.imgbbInvalidResponse
    static let uploadToImgBB = L10n.Cue.uploadToImgBB
    static let imgbbUploadFailed = L10n.Cue.imgbbUploadFailed
    static let imgbbUploading = L10n.Cue.imgbbUploading
    static let imgbbUploadedAndCopied = L10n.Cue.imgbbUploadedAndCopied
    static let imageKitMissingPrivateKey = L10n.Cue.imageKitMissingPrivateKey
    static let imageKitUploadFailed = L10n.Cue.imageKitUploadFailed
    static let selected = L10n.Cue.selected
}
