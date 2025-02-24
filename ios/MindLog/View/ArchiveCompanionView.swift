import SwiftUI

struct ArchiveCompanionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var companions: [(String, String)] = []  // (name, thumbnail_url)
    @State private var isLoading = true
    @State private var selectedPerson: String? = nil  // 추가
    
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        Heading(title: "Companion", buttonIcon: nil, menuItems: [])
                        
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(.top, 100)
                        } else {
                            CompanionGrid(companions: companions) { name in
                                selectedPerson = name  // 선택된 사람 저장
                            }
                        }
                    }
                }
                
                VStack {
                    Spacer()
                    FloatingButtonContainer(buttons: [
                        FloatingButton(icon: "arrow.left", text: nil, action: {
                            dismiss()
                        })
                    ])
                    .padding(.bottom, 16)
                }
            }
            .commonBackground()
            .navigationDestination(isPresented: Binding(
                get: { selectedPerson != nil },
                set: { if !$0 { selectedPerson = nil } }
            )) {
                if let personName = selectedPerson {
                    CompanionLogListView(personName: personName)
                }
            }
        }
        .task {
            await fetchCompanions()
        }
    }
    
    private func fetchCompanions() async {
        do {
            print("\n=== fetchCompanions 시작 ===")
            let response = try await DiaryService.shared.getGroupedByPerson()
            
            await MainActor.run {
                // Dictionary를 사용하여 동일한 이름의 인물은 가장 최근 썸네일로 유지
                var uniqueCompanions: [String: String] = [:]  // [name: thumbnailUrl]
                
                response.people.forEach { person in
                    uniqueCompanions[person.person_name] = person.thumbnail_url
                }
                
                // Dictionary를 다시 배열로 변환
                self.companions = uniqueCompanions.map { (name, url) in
                    print("✅ 인물 추가: \(name)")
                    print("  썸네일: \(url)")
                    return (name, url)
                }
                
                print("\n=== 총 인물 수: \(self.companions.count) ===")
                self.isLoading = false
            }
        } catch {
            print("❌ 동행인 데이터 가져오기 실패:", error)
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

struct CompanionGrid: View {
    let companions: [(String, String)]  // (name, thumbnail_url)
    let onCompanionSelected: (String?) -> Void
    
    var balancedColumns: (left: [(String, String)], right: [(String, String)]) {
        var leftColumn: [(String, String)] = []
        var rightColumn: [(String, String)] = []
        var leftHeight: CGFloat = 0
        var rightHeight: CGFloat = 0
        
        for companion in companions {
            let height = CGFloat.random(in: 120...360)
            
            if leftHeight <= rightHeight {
                leftColumn.append(companion)
                leftHeight += height + 16
            } else {
                rightColumn.append(companion)
                rightHeight += height + 16
            }
        }
        
        return (leftColumn, rightColumn)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            LazyVStack(spacing: 16) {
                ForEach(balancedColumns.left, id: \.0) { companion in
                    Button {
                        onCompanionSelected(companion.0)
                    } label: {
                        Companion(image: companion.1, name: companion.0) {
                            onCompanionSelected(companion.0)
                        }
                    }
                }
            }
            
            LazyVStack(spacing: 16) {
                ForEach(balancedColumns.right, id: \.0) { companion in
                    Button {
                        onCompanionSelected(companion.0)
                    } label: {
                        Companion(image: companion.1, name: companion.0) {
                            onCompanionSelected(companion.0)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

// ✅ 미리보기
struct ArchiveCompanionView_Previews: PreviewProvider {
    static var previews: some View {
        ArchiveCompanionView()
            .preferredColorScheme(.dark)
            .previewLayout(.sizeThatFits)
    }
}
