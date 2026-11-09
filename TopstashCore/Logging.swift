import os

extension Logger {
    /// A logger in Topstash's subsystem, shared by the app and TopstashCore.
    public init(category: String) {
        self.init(subsystem: "io.github.armmgh.topstash", category: category)
    }
}
