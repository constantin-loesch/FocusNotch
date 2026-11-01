import SwiftUI

/// FocusNotch-Logo: dunkles macOS-Icon, oben die Island (Start-Button + Fortschrittsleiste),
/// darunter der Pomodoro-Ring. Gezeichnet auf einem 1024er-Raster.
struct AppIconView: View {
    var size: CGFloat = 1024
    var accent: Color = AccentColor.orange.color

    var body: some View {
        let s = size / 1024
        let squircle = RoundedRectangle(cornerRadius: 185 * s, style: .continuous)
        let accentDeep = Color(red: 1.0, green: 0.36, blue: 0.0)

        ZStack {
            ZStack {
                // Hintergrund
                LinearGradient(colors: [Color(white: 0.16), Color(white: 0.02)], startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [accent.opacity(0.22), .clear], center: UnitPoint(x: 0.5, y: 0.6),
                               startRadius: 0, endRadius: 420 * s)

                // Pomodoro-Ring
                ZStack {
                    Circle().stroke(Color.white.opacity(0.09), lineWidth: 58 * s)
                    Circle()
                        .trim(from: 0, to: 0.72)
                        .stroke(AngularGradient(colors: [accentDeep, accent, accent], center: .center,
                                                startAngle: .degrees(0), endAngle: .degrees(260)),
                                style: StrokeStyle(lineWidth: 58 * s, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: accent.opacity(0.55), radius: 26 * s)
                }
                .frame(width: 400 * s, height: 400 * s)
                .offset(y: 62 * s)

                // Island oben (bündig mit der Oberkante)
                ZStack {
                    NotchShape(topRadius: 22 * s, bottomRadius: 52 * s)
                        .fill(Color.black)
                    HStack(spacing: 0) {
                        Circle().fill(accent)
                            .frame(width: 46 * s, height: 46 * s)
                            .overlay(
                                Image(systemName: "play.fill")
                                    .font(.system(size: 22 * s, weight: .black))
                                    .foregroundStyle(.white)
                                    .offset(x: 2 * s)
                            )
                        Spacer()
                        Capsule().fill(Color.white.opacity(0.18))
                            .frame(width: 130 * s, height: 16 * s)
                            .overlay(alignment: .leading) {
                                Capsule().fill(accent).frame(width: 84 * s, height: 16 * s)
                            }
                    }
                    .padding(.horizontal, 62 * s)
                    .offset(y: -6 * s)
                }
                .frame(width: 500 * s, height: 104 * s)
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .frame(width: 824 * s, height: 824 * s)
            .clipShape(squircle)
            .overlay(squircle.strokeBorder(Color.white.opacity(0.10), lineWidth: 3 * s))
            .shadow(color: .black.opacity(0.35), radius: 18 * s, y: 10 * s)
        }
        .frame(width: size, height: size)
    }
}
