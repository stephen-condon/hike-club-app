import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color("LaunchGreen").ignoresSafeArea()
            VStack(spacing: 20) {
                Text("🥾").font(.system(size: 120))
                Text("Pack 134 Hike Club")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
    }
}
