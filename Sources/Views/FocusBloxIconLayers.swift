import SwiftUI

struct FocusBloxIcon: View {
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let cornerRadius = width * 0.225

            ZStack {
                // ---------------------------------------------------------
                // LAYER 0: THE VOID (Hintergrund)
                // ---------------------------------------------------------
                Color(red: 0.08, green: 0.08, blue: 0.10) // Fast Schwarz

                // Ein leichter radialer Schein im Hintergrund zentriert den Fokus
                RadialGradient(
                    colors: [Color.white.opacity(0.08), Color.clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: width * 0.8
                )

                VStack(spacing: height * 0.06) {

                    // ---------------------------------------------------------
                    // BLOCK 1 (Oben): Inaktives "Rauchglas"
                    // ---------------------------------------------------------
                    GlassBlock(width: width * 0.6, height: height * 0.18, isActive: false)

                    // ---------------------------------------------------------
                    // BLOCK 2 (Mitte): Aktives "Neon-Glas" (Der Fokus)
                    // ---------------------------------------------------------
                    ZStack {
                        // Der Glas-Körper
                        GlassBlock(width: width * 0.9, height: height * 0.38, isActive: true)

                        // Das Symbol (Graviert im Glas -> Leuchtet)
                        ViewfinderSymbol(width: width)
                            // Schein nach außen (Bloom)
                            .shadow(color: Color.white.opacity(0.8), radius: width * 0.02)
                    }

                    // ---------------------------------------------------------
                    // BLOCK 3 (Unten): Inaktives "Rauchglas"
                    // ---------------------------------------------------------
                    GlassBlock(width: width * 0.6, height: height * 0.18, isActive: false)
                }
            }
            // Clip auf App-Icon Form
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            // Finaler, technischer Rand um das gesamte Icon
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }
}

// ---------------------------------------------------------
// COMPONENT: Der 3D Glas-Block
// ---------------------------------------------------------
// Hier passiert die Magie für Tiefe & Haptik
struct GlassBlock: View {
    let width: CGFloat
    let height: CGFloat
    let isActive: Bool // Steuert Farbe & Leuchtkraft

    var body: some View {
        let cornerRadius = width * (isActive ? 0.09 : 0.08)

        ZStack {
            // LAYER 1: SHADOW (Der Schattenwurf nach unten)
            // Sorgt dafür, dass der Block "schwebt"
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.black)
                .blur(radius: isActive ? 15 : 5)
                .offset(y: isActive ? 10 : 5)
                .opacity(0.6)
                .frame(width: width * 0.9, height: height)

            // LAYER 2: BODY (Das Volumen)
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: isActive
                        ? [ // Aktives Cyan-Glas
                            Color(red: 0.1, green: 0.9, blue: 0.95).opacity(0.9), // Oben Hell
                            Color(red: 0.0, green: 0.5, blue: 0.6).opacity(0.8)   // Unten Dunkel
                          ]
                        : [ // Inaktives Rauchglas
                            Color.white.opacity(0.15), // Oben etwas Licht
                            Color.white.opacity(0.05)  // Unten dunkel
                          ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: width, height: height)

            // LAYER 3: INNER GLOW (Volumen-Licht von innen)
            // Simuliert, dass das Material dick ist
            if isActive {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(red: 0.0, green: 0.8, blue: 0.9).opacity(0.2))
                    .blur(radius: 10)
                    .padding(5)
            }

            // LAYER 4: SPECULAR HIGHLIGHT (Die Lichtkante)
            // Das ist der wichtigste Teil für den "Premium"-Look.
            // Eine feine weiße Linie oben, die nach unten verblasst.
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isActive ? 0.9 : 0.4), // Oben: Hartes Licht
                            Color.white.opacity(0.0)                   // Unten: Kein Licht
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
                .frame(width: width, height: height)

            // LAYER 5: REFLECTION (Optional: Ein Glanzlicht oben drauf)
            // Simuliert eine Studiolampe über dem Objekt
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .frame(width: width, height: height)
                .padding(1) // Inset damit die Kante bleibt
        }
    }
}

// ---------------------------------------------------------
// COMPONENT: Das Viewfinder Symbol
// ---------------------------------------------------------
struct ViewfinderSymbol: View {
    let width: CGFloat

    var body: some View {
        let symbolWidth = width * 0.32   // Gesamtbreite des Symbols
        let symbolHeight = width * 0.22  // Gesamthöhe des Symbols
        let arm = width * 0.08           // Länge der waagerechten Striche
        let strokeWidth = width * 0.035

        return Canvas { context, size in
            let centerX = size.width / 2
            let centerY = size.height / 2
            let halfW = symbolWidth / 2
            let halfH = symbolHeight / 2

            // Linke Klammer [
            var leftBracket = Path()
            leftBracket.move(to: CGPoint(x: centerX - halfW + arm, y: centerY - halfH))
            leftBracket.addLine(to: CGPoint(x: centerX - halfW, y: centerY - halfH))
            leftBracket.addLine(to: CGPoint(x: centerX - halfW, y: centerY + halfH))
            leftBracket.addLine(to: CGPoint(x: centerX - halfW + arm, y: centerY + halfH))

            context.stroke(
                leftBracket,
                with: .color(.white),
                style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
            )

            // Rechte Klammer ]
            var rightBracket = Path()
            rightBracket.move(to: CGPoint(x: centerX + halfW - arm, y: centerY - halfH))
            rightBracket.addLine(to: CGPoint(x: centerX + halfW, y: centerY - halfH))
            rightBracket.addLine(to: CGPoint(x: centerX + halfW, y: centerY + halfH))
            rightBracket.addLine(to: CGPoint(x: centerX + halfW - arm, y: centerY + halfH))

            context.stroke(
                rightBracket,
                with: .color(.white),
                style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
            )

            // Zen-Punkt in der Mitte •
            let dotSize = width * 0.07
            let dotRect = CGRect(
                x: centerX - dotSize / 2,
                y: centerY - dotSize / 2,
                width: dotSize,
                height: dotSize
            )
            context.fill(Path(ellipseIn: dotRect), with: .color(.white))
        }
        .frame(width: width * 0.5, height: width * 0.4)
    }
}

#Preview {
    ZStack {
        // Schwarzer Hintergrund für die Preview
        Color.black.ignoresSafeArea()
        // Das Icon in voller Größe (512x512pt)
        FocusBloxIcon()
            .frame(width: 512, height: 512)
            .padding()
    }
}
