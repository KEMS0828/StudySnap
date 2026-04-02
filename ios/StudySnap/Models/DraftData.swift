import Foundation

nonisolated struct DraftData: Codable, Sendable {
    let subject: String
    let reflection: String
    let duration: TimeInterval
    let capturedPhotos: [Data]
    let editedPhotos: [Data]
    let modeRawValue: String
    let savedAt: Date
    let editablePhotos: [CodableEditablePhoto]?

    var mode: StudyMode {
        StudyMode(rawValue: modeRawValue) ?? .normal
    }
}
