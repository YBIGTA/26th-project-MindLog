import SwiftUI

struct LogOnMap: View {
    let latitude: Double
    let longitude: Double
    let image: String
    let action: () -> Void
    
    @State private var imageData: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        Button(action: action) {
            if let image = imageData {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(radius: 3)
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    )
            }
        }
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let url = URL(string: image) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    self.imageData = image
                    self.isLoading = false
                }
            }
        } catch {
            print("이미지 로딩 실패:", error)
            self.isLoading = false
        }
    }
}

// 미리보기
struct LogOnMap_Previews: PreviewProvider {
    static var previews: some View {
        LogOnMap(
            latitude: 37.5665,
            longitude: 126.9780,
            image: "https://example.com/image.jpg"
        ) {
            print("Log tapped!")
        }
        .previewLayout(.sizeThatFits)
    }
} 