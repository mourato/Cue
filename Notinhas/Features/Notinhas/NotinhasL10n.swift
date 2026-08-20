import Foundation

enum NotinhasL10n {
    static let noteTool = L10n.Notinhas.noteTool
    static let noteToolGestureHint = L10n.Notinhas.noteToolGestureHint
    static func noteToolTooltip(title: String, gestureHint: String = noteToolGestureHint) -> String {
        L10n.Notinhas.noteToolTooltip(title: title, gestureHint: gestureHint)
    }

    static let noteEditorTitle = L10n.Notinhas.noteEditorTitle
    static let noteEditorPlaceholder = L10n.Notinhas.noteEditorPlaceholder
    static let save = L10n.Notinhas.save
    static let cancel = L10n.Notinhas.cancel
    static let sidePanelTitle = L10n.Notinhas.sidePanelTitle
    static let sidePanelEmpty = L10n.Notinhas.sidePanelEmpty
    static let emptyNoteLabel = L10n.Notinhas.emptyNoteLabel
    static let deleteNote = L10n.Notinhas.deleteNote
    static let noteEditorColorButton = L10n.Notinhas.noteEditorColorButton
    static let noteEditorDragHint = L10n.Notinhas.noteEditorDragHint
    static let pointTargetLabel = L10n.Notinhas.pointTargetLabel
    static let rectTargetLabel = L10n.Notinhas.areaTargetLabel
    static let areaStyleOutline = L10n.Notinhas.areaStyleOutline
    static let areaStyleTinted = L10n.Notinhas.areaStyleTinted
    static let areaStyleHatched = L10n.Notinhas.areaStyleHatched
    static let areaStylePickerLabel = L10n.Notinhas.areaStylePicker
    static let areaStrokeWidthLabel = L10n.Notinhas.areaStrokeWidthLabel
    static let colorRed = L10n.Notinhas.colorRed
    static let colorOrange = L10n.Notinhas.colorOrange
    static let colorBlue = L10n.Notinhas.colorBlue
    static let colorGreen = L10n.Notinhas.colorGreen
    static let colorPurple = L10n.Notinhas.colorPurple
    static let colorMagenta = L10n.Notinhas.colorMagenta
    static let colorBlack = L10n.Notinhas.colorBlack
    static let colorYellow = L10n.Notinhas.colorYellow
    static let colorGray = L10n.Notinhas.colorGray
    static let colorWhite = L10n.Notinhas.colorWhite
    static let colorDarkGray = L10n.Notinhas.colorDarkGray
    static let colorMediumGray = L10n.Notinhas.colorMediumGray
    static let colorLightGray = L10n.Notinhas.colorLightGray
    static let colorPink = L10n.Notinhas.colorPink
    static let colorNearWhite = L10n.Notinhas.colorNearWhite
    static let settingsSection = L10n.Notinhas.settingsSection
    static let panelSideTitle = L10n.Notinhas.panelSideTitle
    static let panelSideDescription = L10n.Notinhas.panelSideDescription
    static let left = L10n.Notinhas.left
    static let right = L10n.Notinhas.right
    static let imgbbMissingAPIKey = L10n.Notinhas.imgbbMissingAPIKey
    static let imgbbInvalidImageData = L10n.Notinhas.imgbbInvalidImageData
    static let imgbbInvalidResponse = L10n.Notinhas.imgbbInvalidResponse
    static let uploadToImgBB = L10n.Notinhas.uploadToImgBB
    static let imgbbUploadFailed = L10n.Notinhas.imgbbUploadFailed
    static let imgbbUploading = L10n.Notinhas.imgbbUploading
    static let imgbbUploadedAndCopied = L10n.Notinhas.imgbbUploadedAndCopied
    static let imageKitMissingPrivateKey = L10n.Notinhas.imageKitMissingPrivateKey
    static let imageKitUploadFailed = L10n.Notinhas.imageKitUploadFailed
    static let selected = L10n.Notinhas.selected
}
