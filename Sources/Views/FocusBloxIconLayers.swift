import SwiftUI

// MARK: - FocusWave Shape (Der "Flow" im Block)
struct FocusWave: Shape {
    var frequency: Double = 3.0
    var amplitude: Double = 0.15

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midHeight = height / 2

        path.move(to: CGPoint(x: 0, y: midHeight))

        for x in stride(from: 0, through: width, by: 1) {
            let relX = x / width
            let sine = sin(relX * frequency * 2 * .pi)
            let y = midHeight + (sine * (height * amplitude))
            path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }
}

// MARK: - Background Layer (Dark Matter + Termin-Blöcke)
struct FocusBloxBackground: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            ZStack {
                RoundedRectangle(cornerRadius: w * 0.22, style: .continuous)
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.05), .clear],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(height: h * 0.28)
                        .overlay(
                            Rectangle().stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                    
                    Spacer().frame(height: h * 0.35)
                    
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.05)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(height: h * 0.28)
                        .overlay(
                            Rectangle().stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                }
                .clipShape(RoundedRectangle(cornerRadius: w * 0.22, style: .continuous))
            }
        }
    }
}

// MARK: - Foreground Layer (Leuchtender Focus Block + Wave)
struct FocusBloxForeground: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            VStack(spacing: 0) {
                Spacer().frame(height: h * 0.28)
                
                ZStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.0, green: 0.7, blue: 0.8),
                                    Color(red: 0.0, green: 0.4, blue: 0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Rectangle()
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: w * 0.01)
                                .blur(radius: 2)
                        )
                        .shadow(color: Color(red: 0.0, green: 0.8, blue: 0.9).opacity(0.4), radius: w * 0.08)
                    
                    FocusWave()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.2), .white, .white.opacity(0.2)],
                                startPoint: .leading, endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: w * 0.03, lineCap: .round)
                        )
                        .frame(width: w * 0.6, height: h * 0.2)
                        .shadow(color: .white, radius: 2)
                }
                .frame(height: h * 0.35)
                .mask(Rectangle())
                
                Spacer().frame(height: h * 0.28)
            }
            .clipShape(RoundedRectangle(cornerRadius: w * 0.22, style: .continuous))
        }
    }
}

// MARK: - Combined FocusBlox Icon
struct FocusBloxIcon: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                FocusBloxBackground()
                FocusBloxForeground()
                
                RoundedRectangle(cornerRadius: geo.size.width * 0.22, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            }
        }
    }
}

// MARK: - Preview
#Preview("FocusBlox Icon") {
    FocusBloxIcon()
        .frame(width: 512, height: 512)
        .padding()
        .background(Color.black)
}

#Preview("Icon Layers") {
    HStack(spacing: 20) {
        VStack {
            FocusBloxBackground()
                .frame(width: 200, height: 200)
            Text("Background")
        }
        VStack {
            FocusBloxForeground()
                .frame(width: 200, height: 200)
                .background(Color.gray.opacity(0.3))
            Text("Foreground")
        }
    }
    .padding()
}
