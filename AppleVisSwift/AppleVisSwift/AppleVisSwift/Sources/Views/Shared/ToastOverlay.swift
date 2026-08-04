import SwiftUI

struct ToastOverlay: View {
    @EnvironmentObject private var toast: ToastStore

    var body: some View {
        VStack {
            if let current = toast.current {
                HStack(spacing: 10) {
                    Image(systemName: current.systemImage)
                        .foregroundStyle(current.color)
                    Text(current.message)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassEffect(in: Capsule())
                .shadow(radius: 4)
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 8)
            }
            Spacer()
        }
        .animation(.spring(duration: 0.3), value: toast.current?.id)
    }
}
