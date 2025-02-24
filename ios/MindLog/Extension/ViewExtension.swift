import SwiftUI

extension View {
    func commonBackground() -> some View {
        self.background(
            Group {
                if let _ = UIImage(named: "back1") {  // 이미지 존재 여부 확인
                    Image("back1")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .edgesIgnoringSafeArea(.all)
                } else {
                    Color.red  // 이미지가 없을 경우 빨간색으로 표시
                        .onAppear {
                            print("❌ back1 이미지를 찾을 수 없습니다")
                        }
                }
            }
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

    func angerBackground() -> some View {
        self.background(
            Image("Anger")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
        )
    }

    func trustBackground() -> some View {
        self.background(
            Image("Trust")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
        )
    }

    func surpriseBackground() -> some View {
        self.background(
            Image("Surprise")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
        )
    }

    func sadnessBackground() -> some View {
        self.background(
            Image("Sadness")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
        )
    }

    func joyBackground() -> some View {
        self.background(
            Image("Joy")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
        )
    }

    func fearBackground() -> some View {
        self.background(
            Image("Fear")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
        )
    }

    func disgustBackground() -> some View {
        self.background(
            Image("Disgust")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
        )
    }

    func anticipationBackground() -> some View {
        self.background(
            Image("Anticipation")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
        )
    }
}
