import SwiftUI
import AVKit

/// Wraps AVRoutePickerView (the system AirPlay/Bluetooth output picker) for
/// SwiftUI — there's no native SwiftUI equivalent.
struct RoutePickerView: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.tintColor = .label
        view.activeTintColor = UIColor(Color.accentColor)
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
