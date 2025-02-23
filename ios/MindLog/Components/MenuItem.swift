import SwiftUI

struct MenuItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    // Hashable 구현
    static func == (lhs: MenuItem, rhs: MenuItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
} 