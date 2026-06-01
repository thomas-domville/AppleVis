import { useEffect } from 'react';
import { registerKeyboardShortcuts } from '../native/nativeModules';
import type { KeyboardShortcut } from '../native/nativeModules';

/**
 * App-wide iPadOS keyboard shortcuts.
 * These appear in the system shortcut overlay (hold ⌘ while app is focused).
 *
 * When the native module is built, shortcuts will be dispatched via a
 * NativeEventEmitter "onKeyCommand" event — add a subscriber here or in
 * _layout.tsx alongside the registration call.
 *
 * Called once from _layout.tsx — do not call per-screen.
 */
export const APP_KEYBOARD_SHORTCUTS: KeyboardShortcut[] = [
  {
    input: 'f',
    modifierFlags: ['command'],
    discoverabilityTitle: 'Search',
    identifier: 'search',
  },
  {
    input: 'r',
    modifierFlags: ['command'],
    discoverabilityTitle: 'Refresh',
    identifier: 'refresh',
  },
  {
    input: '1',
    modifierFlags: ['command'],
    discoverabilityTitle: 'Forums',
    identifier: 'tab_forums',
  },
  {
    input: '2',
    modifierFlags: ['command'],
    discoverabilityTitle: 'Apps',
    identifier: 'tab_apps',
  },
  {
    input: '3',
    modifierFlags: ['command'],
    discoverabilityTitle: 'Podcasts',
    identifier: 'tab_podcasts',
  },
  {
    input: '4',
    modifierFlags: ['command'],
    discoverabilityTitle: 'Resources',
    identifier: 'tab_resources',
  },
  {
    input: ',',
    modifierFlags: ['command'],
    discoverabilityTitle: 'Settings',
    identifier: 'settings',
  },
];

/**
 * Registers keyboard shortcuts for iPadOS hardware keyboard.
 * Call once at app startup from _layout.tsx.
 */
export function useKeyboardShortcuts() {
  useEffect(() => {
    registerKeyboardShortcuts(APP_KEYBOARD_SHORTCUTS);
  }, []);
}
