// Custom entry point so the app launches with AppleVisApplication — a
// UIApplication subclass — as its principal class instead of plain
// UIApplication. That's required for AppleVisApplication's keyCommands
// override to receive iPadOS hardware keyboard shortcuts app-wide (see
// AppleVisKeyboardShortcuts.swift for why UIApplication is the only
// responder-chain link guaranteed to be consulted).
//
// This replaces the @UIApplicationMain attribute the Expo/RN template puts
// on AppDelegate, which only supports the default UIApplication principal
// class — plugins/withKeyboardShortcuts.js strips that attribute and adds
// this file in its place.

import UIKit

UIApplicationMain(
  CommandLine.argc,
  CommandLine.unsafeArgv,
  NSStringFromClass(AppleVisApplication.self),
  NSStringFromClass(AppDelegate.self)
)
