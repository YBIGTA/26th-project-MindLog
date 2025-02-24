import SwiftUI

struct MenuItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let isSelected: Bool
    let isDivider: Bool
    let action: () -> Void
    
    init(title: String, isSelected: Bool, isDivider: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.isDivider = isDivider
        self.action = action
    }
    
    // Hashable 구현
    static func == (lhs: MenuItem, rhs: MenuItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
} 