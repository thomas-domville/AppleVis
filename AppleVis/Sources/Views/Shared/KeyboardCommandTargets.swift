import Combine
import SwiftUI

// Lets a screen answer a hardware-keyboard shortcut while it's on screen:
// Command-F (search), Command-N (new topic), Command-Shift-S (save or
// unsave). A screen registers on appear and unregisters on disappear, so
// the shortcut only reaches what's actually showing, and the Go menu only
// offers it when something can act on it (Adaptive Experience,
// 2026-10-06).

private struct KeyboardTargetModifier: ViewModifier {
    let target: KeyCommandRouter.Target
    let isActive: Bool
    let action: () -> Void

    @State private var token = UUID()
    @State private var isOnScreen = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                isOnScreen = true
                if isActive { KeyCommandRouter.current?.register(target, token) }
            }
            .onDisappear {
                isOnScreen = false
                KeyCommandRouter.current?.unregister(target, token)
            }
            .onChange(of: isActive) { _, active in
                guard isOnScreen else { return }
                if active { KeyCommandRouter.current?.register(target, token) }
                else { KeyCommandRouter.current?.unregister(target, token) }
            }
            .onReceive(KeyCommandRouter.current?.requests.eraseToAnyPublisher() ?? Empty().eraseToAnyPublisher()) { requested in
                guard requested == target, isOnScreen, isActive else { return }
                action()
            }
    }
}

extension View {
    /// Command-F moves to this screen's search field. `isActive` is false
    /// while something else covers the screen (Discover's hub with a
    /// section pushed over it). Needs iOS 18 to move focus into the field;
    /// on iOS 17 the shortcut does nothing here.
    func keyboardSearchTarget(_ focus: FocusState<Bool>.Binding, isActive: Bool = true) -> some View {
        modifier(KeyboardTargetModifier(target: .search, isActive: isActive) { focus.wrappedValue = true })
    }

    /// Command-N starts a new topic from here.
    func keyboardNewTopicTarget(_ action: @escaping () -> Void) -> some View {
        modifier(KeyboardTargetModifier(target: .newTopic, isActive: true, action: action))
    }

    /// Command-Shift-S saves or unsaves what this screen shows.
    func keyboardSaveTarget(_ action: @escaping () -> Void) -> some View {
        modifier(KeyboardTargetModifier(target: .save, isActive: true, action: action))
    }
}
