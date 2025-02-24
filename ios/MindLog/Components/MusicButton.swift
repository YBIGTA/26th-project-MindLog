import SwiftUI

struct MusicButton: View {
    let albumArtwork: String
    let artistName: String
    let songTitle: String
    let isPlaying: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Image(albumArtwork)
                        .resizable()
                        .frame(width: 58, height: 58)
                        .cornerRadius(8)
                    
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 24))
                        .symbolEffect(.bounce.up.down, options: .repeating)
                }
                .padding(.leading, 6)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(artistName)
                        .font(.system(size: 12))
                        .foregroundColor(.black)
                    Text(songTitle)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                }
                
                Spacer()
            }
            .frame(width: 354, height: 70)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.45))
            .cornerRadius(24)
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
