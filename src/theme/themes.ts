/**
 * AppleVis Theme System
 *
 * 13 themes across three groups:
 *   Standard    — System, Light, Dark, Midnight, Warm, Sepia
 *   AppleVis    — Classic, Mouse Light, Mouse Dark, Orchard, Golden Gate, Nebula
 *   Accessibility — High Contrast Light, High Contrast Dark
 *
 * The "system" theme resolves at runtime based on the iOS Light/Dark setting.
 * All other themes are fixed regardless of system appearance.
 */

export type ThemeId =
  | 'system'
  | 'light'
  | 'dark'
  | 'midnight'
  | 'warm'
  | 'sepia'
  | 'applevisClassic'
  | 'mouseLight'
  | 'mouseDark'
  | 'orchard'
  | 'goldenGate'
  | 'nebula'
  | 'highContrastLight'
  | 'highContrastDark';

export type ThemeGroup = 'standard' | 'applevis' | 'accessibility';

export type ThemeColors = {
  background: string;
  card: string;
  text: string;
  textSecondary: string;
  border: string;
  accent: string;
  accentText: string;
  pill: string;
  pillText: string;
  inputBackground: string;
  inputBorder: string;
  statusBar: 'light' | 'dark';
  /** Semantic aliases kept for component compatibility */
  appleVisBlue: string;
  secondary: string;
};

export type ThemeDefinition = {
  id: ThemeId;
  name: string;
  group: ThemeGroup;
  isDark: boolean;
  /** One sentence shown in the wizard and Settings. */
  description: string;
  /** Concrete example of what the theme looks like — read by VoiceOver. */
  example: string;
  colors: ThemeColors;
};

// ─── Colour palettes ─────────────────────────────────────────────────────────

const APPLE_BLUE = '#0A84FF';

const light: ThemeColors = {
  background:     '#F5F7FA',
  card:           '#FFFFFF',
  text:           '#101828',
  textSecondary:  '#475467',
  border:         '#D0D5DD',
  accent:         APPLE_BLUE,
  accentText:     '#FFFFFF',
  pill:           '#E8F1FF',
  pillText:       APPLE_BLUE,
  inputBackground:'#FAFAFA',
  inputBorder:    '#D0D5DD',
  statusBar:      'dark',
  appleVisBlue:   APPLE_BLUE,
  secondary:      '#475467',
};

const dark: ThemeColors = {
  background:     '#1C1C1E',
  card:           '#2C2C2E',
  text:           '#FFFFFF',
  textSecondary:  '#AEAEB2',
  border:         '#38383A',
  accent:         APPLE_BLUE,
  accentText:     '#FFFFFF',
  pill:           '#1A3A5C',
  pillText:       '#4DA6FF',
  inputBackground:'#1C1C1E',
  inputBorder:    '#38383A',
  statusBar:      'light',
  appleVisBlue:   APPLE_BLUE,
  secondary:      '#AEAEB2',
};

const midnight: ThemeColors = {
  background:     '#000000',
  card:           '#111111',
  text:           '#FFFFFF',
  textSecondary:  '#8E8E93',
  border:         '#222222',
  accent:         APPLE_BLUE,
  accentText:     '#FFFFFF',
  pill:           '#001A3A',
  pillText:       '#4DA6FF',
  inputBackground:'#111111',
  inputBorder:    '#222222',
  statusBar:      'light',
  appleVisBlue:   APPLE_BLUE,
  secondary:      '#8E8E93',
};

const warm: ThemeColors = {
  background:     '#FFF8F0',
  card:           '#FFFBF5',
  text:           '#2D1B00',
  textSecondary:  '#7A5533',
  border:         '#E8D5B7',
  accent:         '#C17D2B',
  accentText:     '#FFFFFF',
  pill:           '#FFF0D0',
  pillText:       '#A86820',
  inputBackground:'#FFFBF5',
  inputBorder:    '#E8D5B7',
  statusBar:      'dark',
  appleVisBlue:   '#C17D2B',
  secondary:      '#7A5533',
};

const sepia: ThemeColors = {
  background:     '#F5F0E8',
  card:           '#FAF6EE',
  text:           '#3B2E1E',
  textSecondary:  '#7A6650',
  border:         '#D9CCBA',
  accent:         '#8B6914',
  accentText:     '#FFFFFF',
  pill:           '#EDE0CC',
  pillText:       '#8B6914',
  inputBackground:'#FAF6EE',
  inputBorder:    '#D9CCBA',
  statusBar:      'dark',
  appleVisBlue:   '#8B6914',
  secondary:      '#7A6650',
};

const applevisClassic: ThemeColors = {
  background:     '#EEF4FF',
  card:           '#FFFFFF',
  text:           '#0A1A3A',
  textSecondary:  '#3A5080',
  border:         '#C5D4FF',
  accent:         '#0A5FFF',
  accentText:     '#FFFFFF',
  pill:           '#D8E8FF',
  pillText:       '#0A5FFF',
  inputBackground:'#F5F8FF',
  inputBorder:    '#C5D4FF',
  statusBar:      'dark',
  appleVisBlue:   '#0A5FFF',
  secondary:      '#3A5080',
};

const mouseLight: ThemeColors = {
  background:     '#F7F5F0',
  card:           '#FFFEF9',
  text:           '#2D2A25',
  textSecondary:  '#6B6256',
  border:         '#E5DDD0',
  accent:         '#F5A623',
  accentText:     '#FFFFFF',
  pill:           '#FDF3DF',
  pillText:       '#C47E0A',
  inputBackground:'#FFFEF9',
  inputBorder:    '#E5DDD0',
  statusBar:      'dark',
  appleVisBlue:   '#F5A623',
  secondary:      '#6B6256',
};

const mouseDark: ThemeColors = {
  background:     '#1E1C18',
  card:           '#2A2822',
  text:           '#F5F0E8',
  textSecondary:  '#A89880',
  border:         '#3D3A32',
  accent:         '#F5A623',
  accentText:     '#1E1C18',
  pill:           '#3D3218',
  pillText:       '#F5A623',
  inputBackground:'#2A2822',
  inputBorder:    '#3D3A32',
  statusBar:      'light',
  appleVisBlue:   '#F5A623',
  secondary:      '#A89880',
};

const orchard: ThemeColors = {
  background:     '#F2F8F2',
  card:           '#FFFFFF',
  text:           '#1A2E1A',
  textSecondary:  '#4A6741',
  border:         '#C8DEC5',
  accent:         '#CC3333',
  accentText:     '#FFFFFF',
  pill:           '#FFE8E8',
  pillText:       '#CC3333',
  inputBackground:'#FFFFFF',
  inputBorder:    '#C8DEC5',
  statusBar:      'dark',
  appleVisBlue:   '#CC3333',
  secondary:      '#4A6741',
};

const goldenGate: ThemeColors = {
  background:     '#FFF5EE',
  card:           '#FFFFFF',
  text:           '#2D1A0A',
  textSecondary:  '#7A4A28',
  border:         '#FDDBB4',
  accent:         '#FF6B2B',
  accentText:     '#FFFFFF',
  pill:           '#FFE9DA',
  pillText:       '#C84800',
  inputBackground:'#FFFFFF',
  inputBorder:    '#FDDBB4',
  statusBar:      'dark',
  appleVisBlue:   '#FF6B2B',
  secondary:      '#7A4A28',
};

const nebula: ThemeColors = {
  background:     '#12102A',
  card:           '#1E1B3A',
  text:           '#E8E0FF',
  textSecondary:  '#9B8EC4',
  border:         '#2E2A50',
  accent:         '#A78BFA',
  accentText:     '#12102A',
  pill:           '#2E2650',
  pillText:       '#A78BFA',
  inputBackground:'#1E1B3A',
  inputBorder:    '#2E2A50',
  statusBar:      'light',
  appleVisBlue:   '#A78BFA',
  secondary:      '#9B8EC4',
};

const highContrastLight: ThemeColors = {
  background:     '#FFFFFF',
  card:           '#FFFFFF',
  text:           '#000000',
  textSecondary:  '#000000',
  border:         '#000000',
  accent:         '#0040CC',
  accentText:     '#FFFFFF',
  pill:           '#0040CC',
  pillText:       '#FFFFFF',
  inputBackground:'#FFFFFF',
  inputBorder:    '#000000',
  statusBar:      'dark',
  appleVisBlue:   '#0040CC',
  secondary:      '#000000',
};

const highContrastDark: ThemeColors = {
  background:     '#000000',
  card:           '#000000',
  text:           '#FFFFFF',
  textSecondary:  '#FFFFFF',
  border:         '#FFFFFF',
  accent:         '#FFFF00',
  accentText:     '#000000',
  pill:           '#FFFF00',
  pillText:       '#000000',
  inputBackground:'#000000',
  inputBorder:    '#FFFFFF',
  statusBar:      'light',
  appleVisBlue:   '#FFFF00',
  secondary:      '#FFFFFF',
};

// ─── Theme registry ───────────────────────────────────────────────────────────

export const THEMES: Record<ThemeId, ThemeDefinition> = {
  system: {
    id: 'system',
    name: 'System',
    group: 'standard',
    isDark: false, // resolved at runtime
    description: 'Follows your iOS Light or Dark Mode setting automatically — the app always matches the rest of your device.',
    example: 'If your iPhone is in Dark Mode, AppleVis will be dark. Switch iOS to Light Mode and AppleVis switches too.',
    colors: light, // placeholder — resolved dynamically in ThemeContext
  },
  light: {
    id: 'light',
    name: 'Light',
    group: 'standard',
    isDark: false,
    description: 'Clean white and light grey — always light regardless of your iOS setting.',
    example: 'White cards on a pale grey background with the signature AppleVis blue for buttons and links.',
    colors: light,
  },
  dark: {
    id: 'dark',
    name: 'Dark',
    group: 'standard',
    isDark: true,
    description: "Apple's standard dark appearance — always dark, easier on the eyes in low light.",
    example: 'Dark charcoal cards on a near-black background, white text, and blue accents — the same look as Apple apps in Dark Mode.',
    colors: dark,
  },
  midnight: {
    id: 'midnight',
    name: 'Midnight',
    group: 'standard',
    isDark: true,
    description: 'Pure black backgrounds for OLED iPhone screens — saves battery and gives maximum contrast between black and white.',
    example: 'Jet-black backgrounds with bright white text. On an iPhone 12 or later the black pixels are truly off, saving battery.',
    colors: midnight,
  },
  warm: {
    id: 'warm',
    name: 'Warm',
    group: 'standard',
    isDark: false,
    description: 'Soft cream and amber tones that reduce blue light — gentler on the eyes, especially in the evening.',
    example: 'Pale cream backgrounds, warm amber text, and rich amber buttons instead of blue — like reading by warm lamplight.',
    colors: warm,
  },
  sepia: {
    id: 'sepia',
    name: 'Sepia',
    group: 'standard',
    isDark: false,
    description: 'Warm parchment tones inspired by the look of printed paper — ideal for long reading sessions.',
    example: 'Parchment-coloured backgrounds and rich brown text — like reading a well-loved book. Muted gold accent colour.',
    colors: sepia,
  },
  applevisClassic: {
    id: 'applevisClassic',
    name: 'AppleVis Classic',
    group: 'applevis',
    isDark: false,
    description: 'The blue and white colour scheme long-time AppleVis visitors know and love from the website.',
    example: 'Cool blue-tinted backgrounds and deep navy text — familiar to anyone who has visited applevis.com. A deeper blue replaces the standard iOS blue.',
    colors: applevisClassic,
  },
  mouseLight: {
    id: 'mouseLight',
    name: 'Mouse — Light',
    group: 'applevis',
    isDark: false,
    description: "A warm, playful theme inspired by AppleVis's beloved AnonyMouse. Golden cheese-yellow accents on a cream background.",
    example: 'Warm cream cards and backgrounds with a striking golden-yellow accent — the same warm gold that Mouse fans will instantly recognise.',
    colors: mouseLight,
  },
  mouseDark: {
    id: 'mouseDark',
    name: 'Mouse — Dark',
    group: 'applevis',
    isDark: true,
    description: 'The Mouse theme in a warm charcoal dark edition — golden accents glow against deep, warm-toned backgrounds.',
    example: 'Deep warm charcoal backgrounds with golden-yellow buttons and text accents — dark, distinctive, and unmistakably Mouse.',
    colors: mouseDark,
  },
  orchard: {
    id: 'orchard',
    name: 'Orchard',
    group: 'applevis',
    isDark: false,
    description: "Fresh apple greens and deep reds — a nod to the 'Apple' in AppleVis and the changing seasons.",
    example: 'Soft sage-green backgrounds with forest-green text and apple-red buttons and links — like a crisp autumn afternoon in an orchard.',
    colors: orchard,
  },
  goldenGate: {
    id: 'goldenGate',
    name: 'Golden Gate',
    group: 'applevis',
    isDark: false,
    description: "Warm California sunset tones — burnt orange and cream. A nod to Apple's home state.",
    example: 'Warm peach backgrounds and burnt-orange accent colour — the colour of a San Francisco sunset. Perfect for WWDC season.',
    colors: goldenGate,
  },
  nebula: {
    id: 'nebula',
    name: 'Nebula',
    group: 'applevis',
    isDark: true,
    description: 'Deep indigo and soft lavender — a calm, space-inspired dark theme. The "vis" in AppleVis as a window into the night sky.',
    example: 'Deep indigo-black backgrounds with soft lavender-purple accents and pale lavender-white text — like looking at a nebula through a telescope.',
    colors: nebula,
  },
  highContrastLight: {
    id: 'highContrastLight',
    name: 'High Contrast — Light',
    group: 'accessibility',
    isDark: false,
    description: 'Maximum contrast for low vision — pure white background, pure black text, no greys, vivid blue accent. Exceeds WCAG AAA contrast requirements.',
    example: 'Stark white with jet-black text and deep blue buttons. No shading or grey tones anywhere — every element is as legible as possible.',
    colors: highContrastLight,
  },
  highContrastDark: {
    id: 'highContrastDark',
    name: 'High Contrast — Dark',
    group: 'accessibility',
    isDark: true,
    description: 'Maximum contrast in dark environments — pure black background, pure white text, vivid yellow accent. Designed for glare sensitivity and low vision.',
    example: 'Jet-black background with bright white text and vivid yellow buttons. No grey tones — maximum visibility in any dark environment.',
    colors: highContrastDark,
  },
};

export const THEME_GROUPS: { id: ThemeGroup; label: string }[] = [
  { id: 'accessibility', label: 'Accessibility' },
  { id: 'applevis',     label: 'AppleVis' },
  { id: 'standard',     label: 'Standard' },
];

export const ALL_THEME_IDS = Object.keys(THEMES) as ThemeId[];

export const DEFAULT_THEME_ID: ThemeId = 'system';
