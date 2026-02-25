import Foundation
import SwiftData

@Model
final class Script {
    var title: String
    var content: String
    var createdAt: Date
    var fontSize: Double
    var scrollSpeed: Double

    init(
        title: String = "",
        content: String = "",
        createdAt: Date = Date(),
        fontSize: Double = 24,
        scrollSpeed: Double = 145
    ) {
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.fontSize = fontSize
        self.scrollSpeed = scrollSpeed
    }
}
