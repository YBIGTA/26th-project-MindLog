import SwiftUI

struct ContentView: View {
    @StateObject private var authService = AuthService()
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                MainView()
            } else {
                OnboardingView()
            }
        }
        .environmentObject(authService)  // AuthService를 환경 객체로 제공
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService())  // Preview에 AuthService 제공
}

