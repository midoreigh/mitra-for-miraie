import SwiftUI

public extension EnvironmentValues {
    /// True while the view can't be seen, such as when the menu bar panel is closed. The animated
    /// AC and backdrop hold still, so a hidden panel costs no CPU.
    @Entry var isOffScreen = false
}
