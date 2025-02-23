import SwiftUI

extension View {
    func commonBackground() -> some View {
        self.background(
            Image("back1")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
        )
    }
    func commonsecondBackground() -> some View {
        self.background(
            Image("back2")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
        )
    }
}
