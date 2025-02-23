import SwiftUI

struct ArchiveCompanionView: View {
    @Environment(\.dismiss) private var dismiss  // dismiss 환경 변수 추가
    
    // ✅ 예제 데이터 (사용자 리스트)
    let companions: [(image: String, name: String?)] = [
        ("preview", "대연"), ("preview", "지수"), ("preview", "민혁"), ("preview", "서연"),
        ("preview", "태민"), ("preview", "수아"), ("preview", "윤기"), ("preview", "해준"),
        ("preview", "정호"), ("preview", "예림"), ("preview", nil), ("preview", "승현")
    ]
    
    // 높이 균형을 맞추기 위한 열 분배 로직
    private var balancedColumns: (left: [(String, String?)], right: [(String, String?)]) {
        var leftColumn: [(String, String?)] = []
        var rightColumn: [(String, String?)] = []
        var leftHeight: CGFloat = 0
        var rightHeight: CGFloat = 0
        
        for companion in companions {
            let height = CGFloat.random(in: 120...360)
            
            if leftHeight <= rightHeight {
                leftColumn.append(companion)
                leftHeight += height + 16 // spacing 포함
            } else {
                rightColumn.append(companion)
                rightHeight += height + 16 // spacing 포함
            }
        }
        
        return (leftColumn, rightColumn)
    }
    
    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    Heading(title: "Companion", buttonIcon: nil, menuItems: [])
                    
                    HStack(alignment: .top, spacing: 16) {
                        // 왼쪽 열
                        LazyVStack(spacing: 16) {
                            ForEach(balancedColumns.left, id: \.1) { companion in
                                Companion(image: companion.0, name: companion.1) {
                                    print("\(companion.1 ?? "비활성화 사용자") 클릭됨!")
                                }
                            }
                        }
                        
                        // 오른쪽 열
                        LazyVStack(spacing: 16) {
                            ForEach(balancedColumns.right, id: \.1) { companion in
                                Companion(image: companion.0, name: companion.1) {
                                    print("\(companion.1 ?? "비활성화 사용자") 클릭됨!")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
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
