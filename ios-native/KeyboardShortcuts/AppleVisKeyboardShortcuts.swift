// iPadOS hardware keyboard shortcuts for AppleVis.
//
// UIKit only asks the *responder chain* for keyCommands, and that chain
// always ends at UIApplication — so a UIApplication subclass is the one
// place a key command is guaranteed to be offered regardless of which
// view currently has focus. AppleVisApplication (below) is installed as
// the app's principal class from main.swift.
//
// The JS side registers the shortcut list once via registerShortcuts();
// AppleVisApplication reads the shared store when UIKit asks for
// keyCommands and reports the tapped identifier back to JS as the
// "onKeyCommand" event.

import UIKit
import React

struct AppleVisShortcut {
  let input: String
  let modifierFlags: UIKeyModifierFlags
  let discoverabilityTitle: String
  let identifier: String
}

final class AppleVisKeyboardShortcutsStore {
  static let shared = AppleVisKeyboardShortcutsStore()
  private init() {}
  var shortcuts: [AppleVisShortcut] = []
  weak var emitter: AppleVisKeyboardShortcuts?
}

@objc(AppleVisKeyboardShortcuts)
class AppleVisKeyboardShortcuts: RCTEventEmitter {

  override init() {
    super.init()
    AppleVisKeyboardShortcutsStore.shared.emitter = self
  }

  @objc static func requiresMainQueueSetup() -> Bool { true }

  override func supportedEvents() -> [String]! { ["onKeyCommand"] }

  @objc func registerShortcuts(_ shortcuts: [[String: Any]]) {
    let parsed: [AppleVisShortcut] = shortcuts.compactMap { dict in
      guard
        let input = dict["input"] as? String,
        let discoverabilityTitle = dict["discoverabilityTitle"] as? String,
        let identifier = dict["identifier"] as? String,
        let modifierNames = dict["modifierFlags"] as? [String]
      else { return nil }

      var flags: UIKeyModifierFlags = []
      for name in modifierNames {
        switch name {
        case "command":   flags.insert(.command)
        case "shift":     flags.insert(.shift)
        case "alternate": flags.insert(.alternate)
        case "control":   flags.insert(.control)
        default: break
        }
      }
      return AppleVisShortcut(input: input, modifierFlags: flags,
                               discoverabilityTitle: discoverabilityTitle, identifier: identifier)
    }

    DispatchQueue.main.async {
      AppleVisKeyboardShortcutsStore.shared.shortcuts = parsed
    }
  }

  func dispatch(identifier: String) {
    sendEvent(withName: "onKeyCommand", body: ["identifier": identifier])
  }
}

/// Installed as the app's principal class by main.swift.
class AppleVisApplication: UIApplication {
  override var keyCommands: [UIKeyCommand]? {
    let shortcuts = AppleVisKeyboardShortcutsStore.shared.shortcuts
    guard !shortcuts.isEmpty else { return nil }

    return shortcuts.map { s in
      let command = UIKeyCommand(
        input: s.input,
        modifierFlags: s.modifierFlags,
        action: #selector(handleAppleVisKeyCommand(_:)),
        discoverabilityTitle: s.discoverabilityTitle
      )
      command.propertyList = s.identifier
      return command
    }
  }

  @objc func handleAppleVisKeyCommand(_ command: UIKeyCommand) {
    guard let identifier = command.propertyList as? String else { return }
    AppleVisKeyboardShortcutsStore.shared.emitter?.dispatch(identifier: identifier)
  }
}
