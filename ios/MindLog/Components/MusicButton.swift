import SwiftUI

struct MusicButton: View {
    let albumArtwork: String
    let artistName: String
    let songTitle: String
    let isPlaying: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(albumArtwork)
                    .resizable()
                    .frame(width: 58, height: 58)
                    .cornerRadius(5)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(artistName)
                        .font(.system(size: 12))
                        .foregroundColor(.black)
                    Text(songTitle)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                }
                
                Spacer()
                
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .foregroundColor(.black)
                    .font(.system(size: 24))
                    .symbolEffect(.bounce.up.down, options: .repeating)
                    .padding(.trailing, 16)
            }
            .frame(width: 354, height: 70)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.7))
            .cornerRadius(10)
        }
    }
}

#Preview {
    ZStack {
        Color.black
        
        VStack(spacing: 20) {
            MusicButton(
                albumArtwork: "lucy_album", // Assets에 추가할 이미지 이름
                artistName: "LUCY",
                songTitle: "아지랑이",
                isPlaying: true,
                action: {}
            )
        }
    }
} 