import Foundation
import AVKit
import UIKit

@objc(AppleVisRoutePicker)
class AppleVisRoutePicker: NSObject {

  @objc static func requiresMainQueueSetup() -> Bool { return true }

  /// Presents the system AirPlay / audio output route picker.
  /// Works by adding a hidden AVRoutePickerView to the key window and
  /// programmatically triggering its internal button.
  @objc func showPicker() {
    DispatchQueue.main.async {
      let pickerView = AVRoutePickerView(frame: .zero)
      pickerView.isHidden = true

      guard let window = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .flatMap({ $0.windows })
        .first(where: { $0.isKeyWindow }) else { return }

      window.addSubview(pickerView)

      // AVRoutePickerView contains a UIButton subview; send it a tap.
      for subview in pickerView.subviews {
        if let button = subview as? UIButton {
          button.sendActions(for: .touchUpInside)
          break
        }
      }

      // Remove the hidden view shortly after the sheet appears.
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        pickerView.removeFromSuperview()
      }
    }
  }
}
