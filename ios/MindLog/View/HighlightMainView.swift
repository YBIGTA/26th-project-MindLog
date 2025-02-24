import SwiftUI

struct StoryPopupView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @State private var isPaused = false
    @State private var finalPageCompleted: Bool = false
    
    let storyPages: [StoryPage] = [
        StoryPage(
            mainTitle: "성장통과 함께한\n2024년이었네요.",
            subTitle: "103개의 소중한 순간들,\n되돌아봐요",
            description: "하이라이트 필름은 Archive 탭에서\n언제든 다시 확인할 수 있어요."
        ),
        StoryPage(
            mainTitle: "올해의 감정은\n기쁨과 놀람이에요",
            subTitle: "당신의 용기가\n빛나는 순간들이에요",
            description: "지금까지 잘 해왔어요"
        ),
        StoryPage(
            mainTitle: "올해의 새로운 동반자는\n석희예요.",
            subTitle: "당신의 용기가\n빛나는 순간들이에요",
            description: "지금까지 잘 해왔어요"
        ),
        StoryPage(
            mainTitle: "새로운 도전으로\n가득했던 한 해",
            subTitle: "당신의 용기가\n빛나는 순간들이에요",
            description: "지금까지 잘 해왔어요"
        ),
        StoryPage(
            mainTitle: "새로운 도전으로\n가득했던 한 해",
            subTitle: "당신의 용기가\n빛나는 순간들이에요",
            description: "지금까지 잘 해왔어요"
        )
    ]

    var body: some View {
        ZStack {
            Image("desert_background")
                .resizable()
                .scaledToFill()
                .edgesIgnoringSafeArea(.all)
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.black.opacity(0.3), Color.clear]),
                        startPoint: .top,
                        endPoint: .center
                    )
                )

            VStack {
                AudioPlayerHeader(
                    currentStep: currentPage,
                    totalSteps: storyPages.count,
                    isPaused: $isPaused,
                    finalPageCompleted: $finalPageCompleted,
                    onPageComplete: {
                        if currentPage < storyPages.count - 1 {
                            currentPage += 1
                        }
                    }
                )
                .padding(.top, 60)

                Spacer()
                
                StoryTextView(page: storyPages[currentPage])
                
                Spacer()
            }
            .padding(.horizontal, 24)

            HStack(spacing: 0) {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { goToPrevious() }

                Color.clear
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { goToNext() }
            }

            VStack {
                Spacer()
                FloatingButtonContainer(buttons: [
                    FloatingButton(icon: "arrow.left", text: nil) {
                        isPresented = false
                    }
                ])
                .padding(.bottom, 16)
                .padding(.bottom, UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0)
            }
        }
        .interactiveDismissDisabled()
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.1)
                .onChanged { _ in
                    isPaused = true
                }
                .onEnded { _ in
                    isPaused = false
                }
        )
    }

    private func goToPrevious() {
        if currentPage > 0 {
            currentPage -= 1
        }
    }

    private func goToNext() {
        if currentPage < storyPages.count - 1 {
            currentPage += 1
        }
    }
}

// ✅ 상단 진행 바
struct AudioPlayerHeader: View {
    let currentStep: Int
    let totalSteps: Int
    @Binding var isPaused: Bool
    @Binding var finalPageCompleted: Bool
    let onPageComplete: () -> Void

    let timerDuration: Double = 6.0
    @State private var progress: CGFloat = 0.0
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 4) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.white.opacity(0.3))
                                .frame(height: 2)
                                .cornerRadius(1)

                            Rectangle()
                                .fill(Color.white)
                                .frame(width: getProgressWidth(geometry: geometry, index: index), height: 2)
                                .cornerRadius(1)
                        }
                    }
                    .frame(height: 2)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 12))
                Text("Kendrick Lamar · GOD.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }
        }
        .onAppear { startTimer() }
        .onChange(of: currentStep) { _ in startTimer() }
        .onDisappear { timer?.invalidate() }
    }

    private func getProgressWidth(geometry: GeometryProxy, index: Int) -> CGFloat {
        if index < currentStep {
            return geometry.size.width
        } else if index == currentStep {
            return geometry.size.width * progress
        }
        return 0
    }

    private func startTimer() {
        timer?.invalidate()
        
        if currentStep == totalSteps - 1 && finalPageCompleted {
            progress = 1.0
            return
        }
        
        progress = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if isPaused {
                timer.invalidate()
                return
            }
            
            progress += 0.05 / timerDuration
            
            if progress >= 1.0 {
                timer.invalidate()
                progress = 1.0
                
                DispatchQueue.main.async {
                    if currentStep == totalSteps - 1 {
                        finalPageCompleted = true
                    } else {
                        onPageComplete()
                    }
                }
            }
        }
    }
}

// ✅ 텍스트 뷰
struct StoryTextView: View {
    let page: StoryPage

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text(page.mainTitle)
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)

                Text(page.subTitle)
                    .font(.system(size: 20, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
            }

            Text(page.description)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }
}

// ✅ 미리보기
struct StoryPopupView_Previews: PreviewProvider {
    static var previews: some View {
        StoryPopupView(isPresented: .constant(true))
    }
}

// ✅ 데이터 모델
struct StoryPage {
    let mainTitle: String
    let subTitle: String
    let description: String
}
