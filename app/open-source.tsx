import { useState, useMemo, useRef } from 'react';
import {
  Animated, Clipboard, Easing, Linking, Platform,
  Pressable, ScrollView, StyleSheet, Text, TextInput, View,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { Screen } from '../src/components/Screen';
import { useTheme } from '../src/contexts/ThemeContext';
import { useToast } from '../src/contexts/ToastContext';

// ─── Types ────────────────────────────────────────────────────────────────────

type LicenseType = 'MIT' | 'Apache-2.0' | 'BSD-3-Clause';

type Library = {
  name: string;
  version: string;
  license: LicenseType;
  author: string;
  description: string;
  repo: string;
  category: Category;
};

type Category =
  | 'Core Framework'
  | 'Navigation & UI'
  | 'Audio & Media'
  | 'Storage & Security'
  | 'Network & Notifications'
  | 'Localisation & Utilities';

// ─── License colours & text ───────────────────────────────────────────────────

const LICENSE_COLOR: Record<LicenseType, string> = {
  'MIT':            '#16a34a',
  'Apache-2.0':     '#2563eb',
  'BSD-3-Clause':   '#7c3aed',
};

const LICENSE_BG: Record<LicenseType, string> = {
  'MIT':            '#dcfce7',
  'Apache-2.0':     '#dbeafe',
  'BSD-3-Clause':   '#ede9fe',
};

const MIT_TEXT =
  'Permission is hereby granted, free of charge, to any person obtaining a copy ' +
  'of this software and associated documentation files (the "Software"), to deal ' +
  'in the Software without restriction, including without limitation the rights ' +
  'to use, copy, modify, merge, publish, distribute, sublicense, and/or sell ' +
  'copies of the Software, and to permit persons to whom the Software is ' +
  'furnished to do so, subject to the following conditions:\n\n' +
  'The above copyright notice and this permission notice shall be included in all ' +
  'copies or substantial portions of the Software.\n\n' +
  'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR ' +
  'IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, ' +
  'FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE ' +
  'AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER ' +
  'LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, ' +
  'OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE ' +
  'SOFTWARE.';

const APACHE_TEXT =
  'Licensed under the Apache License, Version 2.0 (the "License"); ' +
  'you may not use this file except in compliance with the License. ' +
  'You may obtain a copy of the License at:\n\n' +
  '    https://www.apache.org/licenses/LICENSE-2.0\n\n' +
  'Unless required by applicable law or agreed to in writing, software ' +
  'distributed under the License is distributed on an "AS IS" BASIS, ' +
  'WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. ' +
  'See the License for the specific language governing permissions and ' +
  'limitations under the License.';

const BSD_TEXT =
  'Redistribution and use in source and binary forms, with or without ' +
  'modification, are permitted provided that the following conditions are met:\n\n' +
  '1. Redistributions of source code must retain the above copyright notice, ' +
  'this list of conditions and the following disclaimer.\n\n' +
  '2. Redistributions in binary form must reproduce the above copyright notice, ' +
  'this list of conditions and the following disclaimer in the documentation ' +
  'and/or other materials provided with the distribution.\n\n' +
  '3. Neither the name of the copyright holder nor the names of its contributors ' +
  'may be used to endorse or promote products derived from this software without ' +
  'specific prior written permission.\n\n' +
  'THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" ' +
  'AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE ' +
  'IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE ' +
  'DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE ' +
  'FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL ' +
  'DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR ' +
  'SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER ' +
  'CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, ' +
  'OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE ' +
  'OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.';

const LICENSE_TEXT: Record<LicenseType, string> = {
  'MIT':          MIT_TEXT,
  'Apache-2.0':   APACHE_TEXT,
  'BSD-3-Clause': BSD_TEXT,
};

// ─── Category metadata ────────────────────────────────────────────────────────

const CATEGORY_META: Record<Category, { icon: string; color: string }> = {
  'Core Framework':           { icon: 'layers-outline',        color: '#f97316' },
  'Navigation & UI':          { icon: 'phone-portrait-outline', color: '#8b5cf6' },
  'Audio & Media':            { icon: 'musical-notes-outline',  color: '#ec4899' },
  'Storage & Security':       { icon: 'server-outline',         color: '#14b8a6' },
  'Network & Notifications':  { icon: 'wifi-outline',           color: '#3b82f6' },
  'Localisation & Utilities': { icon: 'globe-outline',          color: '#f59e0b' },
};

// ─── Library data ─────────────────────────────────────────────────────────────

const LIBRARIES: Library[] = [
  // Core Framework
  {
    name: 'React', version: '19.1.0', license: 'MIT', author: 'Meta Platforms, Inc.',
    description: "The JavaScript library that powers AppleVis's entire user interface.",
    repo: 'https://github.com/facebook/react',
    category: 'Core Framework',
  },
  {
    name: 'React Native', version: '0.81.5', license: 'MIT', author: 'Meta Platforms, Inc.',
    description: 'Cross-platform native app framework. Renders real iOS views, not web views.',
    repo: 'https://github.com/facebook/react-native',
    category: 'Core Framework',
  },
  {
    name: 'Expo', version: '54.0.0', license: 'MIT', author: 'Expo Inc.',
    description: 'Universal app platform providing build tooling, APIs, and native module access.',
    repo: 'https://github.com/expo/expo',
    category: 'Core Framework',
  },
  {
    name: 'Expo Router', version: '6.0.24', license: 'MIT', author: 'Expo Inc.',
    description: 'File-based routing for Expo apps, enabling deep linking and tab navigation.',
    repo: 'https://github.com/expo/expo/tree/main/packages/expo-router',
    category: 'Core Framework',
  },

  // Navigation & UI
  {
    name: '@react-navigation/native', version: '7.0.0', license: 'MIT', author: 'Callstack',
    description: "Routing and navigation primitives underlying Expo Router's stack and tab navigation.",
    repo: 'https://github.com/react-navigation/react-navigation',
    category: 'Navigation & UI',
  },
  {
    name: '@expo/vector-icons', version: '15.0.3', license: 'MIT', author: 'Expo Inc.',
    description: 'Icon set library (Ionicons, Material, FontAwesome) used throughout the app.',
    repo: 'https://github.com/expo/vector-icons',
    category: 'Navigation & UI',
  },
  {
    name: 'React Native Gesture Handler', version: '2.28.0', license: 'MIT', author: 'Software Mansion',
    description: 'Native gesture recognition: swipe-to-queue/download on podcast cards.',
    repo: 'https://github.com/software-mansion/react-native-gesture-handler',
    category: 'Navigation & UI',
  },
  {
    name: 'React Native Reanimated', version: '4.1.1', license: 'MIT', author: 'Software Mansion',
    description: 'High-performance animations running on the native thread for smooth transitions.',
    repo: 'https://github.com/software-mansion/react-native-reanimated',
    category: 'Navigation & UI',
  },
  {
    name: 'React Native Screens', version: '4.16.0', license: 'MIT', author: 'Software Mansion',
    description: 'Native screen container components that reduce memory and improve navigation performance.',
    repo: 'https://github.com/software-mansion/react-native-screens',
    category: 'Navigation & UI',
  },
  {
    name: 'React Native Safe Area Context', version: '5.6.0', license: 'MIT', author: 'Th3rdwave',
    description: 'Safe area insets for notch, Dynamic Island, and home indicator avoidance.',
    repo: 'https://github.com/th3rdwave/react-native-safe-area-context',
    category: 'Navigation & UI',
  },
  {
    name: 'Lottie React Native', version: '7.1.0', license: 'Apache-2.0', author: 'Airbnb / Expo Inc.',
    description: 'Vector animation renderer used for the welcome screen and loading states.',
    repo: 'https://github.com/lottie-animation-community/lottie-react-native',
    category: 'Navigation & UI',
  },
  {
    name: 'Expo Blur', version: '15.0.8', license: 'MIT', author: 'Expo Inc.',
    description: 'Frosted-glass blur effect used in navigation bars and overlays.',
    repo: 'https://github.com/expo/expo/tree/main/packages/expo-blur',
    category: 'Navigation & UI',
  },
  {
    name: 'Expo Haptics', version: '15.0.8', license: 'MIT', author: 'Expo Inc.',
    description: 'Tactile feedback — used on long-press, confirmations, and navigation actions.',
    repo: 'https://github.com/expo/expo/tree/main/packages/expo-haptics',
    category: 'Navigation & UI',
  },
  {
    name: 'Expo Splash Screen', version: '31.0.13', license: 'MIT', author: 'Expo Inc.',
    description: 'Controls the launch screen while AppleVis loads its initial content.',
    repo: 'https://github.com/expo/expo/tree/main/packages/expo-splash-screen',
    category: 'Navigation & UI',
  },
  {
    name: 'Expo Status Bar', version: '3.0.9', license: 'MIT', author: 'Expo Inc.',
    description: 'Controls the iOS status bar style — light/dark text to suit each screen.',
    repo: 'https://github.com/expo/expo/tree/main/packages/expo-status-bar',
    category: 'Navigation & UI',
  },
  {
    name: 'Expo System UI', version: '6.0.9', license: 'MIT', author: 'Expo Inc.',
    description: 'Sets the root background colour, preventing flashes between screens.',
    repo: 'https://github.com/expo/expo/tree/main/packages/expo-system-ui',
    category: 'Navigation & UI',
  },
  {
    name: 'React Native Worklets', version: '0.5.1', license: 'MIT', author: 'Margelo GmbH',
    description: 'Runs JavaScript worklets on a background thread for smooth audio processing.',
    repo: 'https://github.com/margelo/react-native-worklets-core',
    category: 'Navigation & UI',
  },

  // Audio & Media
  {
    name: 'Expo AV', version: '16.0.8', license: 'MIT', author: 'Expo Inc.',
    description: 'Audio and video playback — powers the podcast player, episode streaming, and downloads.',
    repo: 'https://github.com/expo/expo/tree/main/packages/expo-av',
    category: 'Audio & Media',
  },
  {
    name: 'Expo Speech', version: '14.0.8', license: 'MIT', author: 'Expo Inc.',
    description: 'Text-to-speech synthesis for the Read Aloud feature on feed cards.',
    repo: 'https://github.com/expo/expo/tree/main/packages/expo-speech',
    category: 'Audio & Media',
  },
  {
    name: 'Expo Sharing', version: '14.0.8', license: 'MIT', author: 'Expo Inc.',
    description: 'Native share sheet for sharing episode links, app entries, and content.',
    repo: 'https://github.com/expo/expo/tree/main/packages/expo-sharing',
    category: 'Audio & Media',
  },
  {
    name: 'Expo Document Picker', version: '14.0.8', license: 'MIT', author: 'Expo Inc.',
    description: 'File picker used for the screenshot upload flow in bug and app reports.',
    repo: 'https://github.com/expo/expo/tree/main/packages/expo-document-picker',
    category: 'Audio & Media',
  },

  // Storage & Security
  {
    name: 'Async Storage', version: '2.2.0', license: 'MIT', author: 'React Native Community',
    description: 'Persistent key-value storage for settings, feed cache, and read history.',
    repo: 'https://github.com/react-native-async-storage/async-storage',
    category: 'Storage & Security',
  },
  {
    name: 'Expo Secure Store', version: '15.0.8', license: 'MIT', author: 'Expo Inc.',
    description: 'Encrypted keychain-backed storage for the signed-in session and auth tokens.',
    repo: 'https://github.com/expo/expo/tree/main/packages/expo-secure-store',
    category: 'Storage & Security',
  },
  {
    name: 'Expo File System', version: '19.0.23', license: 'MIT', author: 'Expo Inc.',
    description: 'Local file access — used to store downloaded podcast episodes for offline playback.',
    repo: 'https://github.com/expo/expo/tree/main/packages/expo-file-system',
    category: 'Storage & Security',
  },

  // Network & Notifications
  {
    name: 'NetInfo', version: '11.4.1', license: 'MIT', author: 'React Native Community',
    description: 'Network connectivity detection — used to defer background syncs when offline.',
    repo: 'https://github.com/react-native-netinfo/react-native-netinfo',
    category: 'Network & Notifications',
  },
  {
    name: 'Expo Notifications', version: '0.32.17', license: 'MIT', author: 'Expo Inc.',
    description: 'Push and local notifications for new content alerts and episode reminders.',
    repo: 'https://github.com/expo/expo/tree/main/packages/expo-notifications',
    category: 'Network & Notifications',
  },
  {
    name: 'Expo Background Fetch', version: '14.0.9', license: 'MIT', author: 'Expo Inc.',
    description: 'Periodic background tasks — refreshes the feed and downloads queued episodes.',
    repo: 'https://github.com/expo/expo/tree/main/packages/expo-background-fetch',
    category: 'Network & Notifications',
  },
  {
    name: 'Expo Task Manager', version: '14.0.9', license: 'MIT', author: 'Expo Inc.',
    description: 'Defines and manages background tasks used by Expo Background Fetch.',
    repo: 'https://github.com/expo/expo/tree/main/packages/expo-task-manager',
    category: 'Network & Notifications',
  },

  // Localisation & Utilities
  {
    name: 'Expo Constants', version: '18.0.13', license: 'MIT', author: 'Expo Inc.',
    description: 'App configuration, version, and build number constants.',
    repo: 'https://github.com/expo/expo/tree/main/packages/expo-constants',
    category: 'Localisation & Utilities',
  },
  {
    name: 'Expo Device', version: '8.0.10', license: 'MIT', author: 'Expo Inc.',
    description: 'Device model, OS version, and memory info shown in the support info panel.',
    repo: 'https://github.com/expo/expo/tree/main/packages/expo-device',
    category: 'Localisation & Utilities',
  },
  {
    name: 'Expo Linking', version: '8.0.12', license: 'MIT', author: 'Expo Inc.',
    description: 'Deep link parsing and URL handling for applevis:// scheme navigation.',
    repo: 'https://github.com/expo/expo/tree/main/packages/expo-linking',
    category: 'Localisation & Utilities',
  },
  {
    name: 'Expo Localization', version: '17.0.9', license: 'MIT', author: 'Expo Inc.',
    description: 'Reads the device locale and timezone for date/time formatting.',
    repo: 'https://github.com/expo/expo/tree/main/packages/expo-localization',
    category: 'Localisation & Utilities',
  },
  {
    name: 'Expo Store Review', version: '9.0.9', license: 'MIT', author: 'Expo Inc.',
    description: 'Native App Store review prompt — shown after meaningful in-app activity.',
    repo: 'https://github.com/expo/expo/tree/main/packages/expo-store-review',
    category: 'Localisation & Utilities',
  },
  {
    name: 'Expo Build Properties', version: '1.0.10', license: 'MIT', author: 'Expo Inc.',
    description: 'Build-time configuration for iOS and Android native project settings.',
    repo: 'https://github.com/expo/expo/tree/main/packages/expo-build-properties',
    category: 'Localisation & Utilities',
  },
  {
    name: 'i18next', version: '26.3.0', license: 'MIT', author: 'i18next',
    description: 'Internationalisation framework used for translating UI strings.',
    repo: 'https://github.com/i18next/i18next',
    category: 'Localisation & Utilities',
  },
  {
    name: 'react-i18next', version: '17.0.8', license: 'MIT', author: 'i18next',
    description: 'React bindings for i18next — provides the useTranslation hook.',
    repo: 'https://github.com/i18next/react-i18next',
    category: 'Localisation & Utilities',
  },
];

const CATEGORY_ORDER: Category[] = [
  'Core Framework',
  'Navigation & UI',
  'Audio & Media',
  'Storage & Security',
  'Network & Notifications',
  'Localisation & Utilities',
];

// ─── Library card ─────────────────────────────────────────────────────────────

function LibraryCard({ lib, colors, textScale }: {
  lib: Library;
  colors: ReturnType<typeof useTheme>['colors'];
  textScale: number;
}) {
  const { showToast } = useToast();
  const [expanded, setExpanded] = useState(false);
  const anim = useRef(new Animated.Value(0)).current;
  const licenseColor = LICENSE_COLOR[lib.license];
  const licenseBg    = LICENSE_BG[lib.license];
  const licenseText  = LICENSE_TEXT[lib.license];

  function toggleExpand() {
    setExpanded(prev => {
      const next = !prev;
      Animated.timing(anim, {
        toValue: next ? 1 : 0,
        duration: 220,
        easing: Easing.out(Easing.quad),
        useNativeDriver: false,
      }).start();
      return next;
    });
  }

  function copyLicense() {
    Clipboard.setString(`${lib.name} — ${lib.license}\n\nCopyright © ${lib.author}\n\n${licenseText}`);
    showToast('License text copied.', 'success');
  }

  function openRepo() {
    Linking.openURL(lib.repo).catch(() => showToast('Could not open repository.', 'error'));
  }

  const expandedHeight = anim.interpolate({
    inputRange: [0, 1],
    outputRange: [0, 1],
  });

  const a11yLabel = [
    lib.name,
    `version ${lib.version}`,
    `${lib.license} licence`,
    `by ${lib.author}`,
    lib.description,
    expanded ? 'Licence text expanded.' : 'Double-tap to expand licence text.',
  ].join('. ');

  return (
    <View
      style={[
        ss.card,
        {
          backgroundColor: colors.card,
          borderColor: colors.border,
          borderLeftColor: licenseColor,
          borderLeftWidth: 4,
        },
      ]}
    >
      {/* ── Main row ──────────────────────────────────────────────────────── */}
      <Pressable
        onPress={toggleExpand}
        accessible
        accessibilityRole="button"
        accessibilityLabel={a11yLabel}
        accessibilityHint={expanded ? 'Collapses the licence text.' : 'Expands the full licence text.'}
        accessibilityState={{ expanded }}
        accessibilityActions={[
          { name: 'expand',   label: expanded ? 'Collapse licence text' : 'Expand licence text' },
          { name: 'copy',     label: 'Copy licence text' },
          { name: 'visit',    label: 'Visit repository' },
        ]}
        onAccessibilityAction={({ nativeEvent }) => {
          if (nativeEvent.actionName === 'expand') toggleExpand();
          if (nativeEvent.actionName === 'copy')   copyLicense();
          if (nativeEvent.actionName === 'visit')  openRepo();
        }}
        style={({ pressed }) => [ss.cardPressable, pressed && { opacity: 0.8 }]}
      >
        {/* Name + version row */}
        <View style={ss.nameRow}>
          <Text
            style={[ss.libName, { color: colors.text, fontSize: 16 * textScale }]}
            numberOfLines={1}
          >
            {lib.name}
          </Text>
          <Text
            style={[ss.version, { color: colors.textSecondary, fontSize: 12 * textScale }]}
            accessibilityElementsHidden
          >
            v{lib.version}
          </Text>
        </View>

        {/* License badge + author row */}
        <View style={ss.badgeRow} accessibilityElementsHidden>
          <View style={[ss.badge, { backgroundColor: licenseBg, borderColor: licenseColor + '55' }]}>
            <Text style={[ss.badgeText, { color: licenseColor }]}>{lib.license}</Text>
          </View>
          <Text style={[ss.author, { color: colors.textSecondary, fontSize: 12 * textScale }]}>
            {lib.author}
          </Text>
        </View>

        {/* Description */}
        <Text style={[ss.description, { color: colors.textSecondary, fontSize: 13 * textScale }]}>
          {lib.description}
        </Text>

        {/* Expand chevron */}
        <View style={ss.expandRow} accessibilityElementsHidden>
          <Text style={[ss.expandLabel, { color: licenseColor, fontSize: 12 * textScale }]}>
            {expanded ? 'Hide licence' : 'Show licence'}
          </Text>
          <Ionicons
            name={expanded ? 'chevron-up' : 'chevron-down'}
            size={14}
            color={licenseColor}
          />
        </View>
      </Pressable>

      {/* ── Expanded licence text ─────────────────────────────────────────── */}
      {expanded && (
        <View style={[ss.licenseBox, { backgroundColor: colors.pill, borderTopColor: colors.border }]}>
          {/* Licence heading — announced as header by braille/VO */}
          <Text
            style={[ss.licenseHeading, { color: colors.text, fontSize: 13 * textScale }]}
            accessibilityRole="header"
          >
            {lib.license} Licence — {lib.author}
          </Text>
          <Text
            style={[ss.licenseBody, { color: colors.textSecondary, fontSize: 13 * textScale }]}
            selectable
          >
            {licenseText}
          </Text>

          {/* Action buttons */}
          <View style={ss.licenseActions}>
            <Pressable
              onPress={copyLicense}
              accessible
              accessibilityRole="button"
              accessibilityLabel={`Copy ${lib.name} licence text`}
              style={({ pressed }) => [
                ss.licenseBtn,
                { backgroundColor: licenseColor, opacity: pressed ? 0.75 : 1 },
              ]}
            >
              <Ionicons name="copy-outline" size={14} color="#fff" accessibilityElementsHidden />
              <Text style={[ss.licenseBtnText, { fontSize: 13 * textScale }]}>Copy</Text>
            </Pressable>
            <Pressable
              onPress={openRepo}
              accessible
              accessibilityRole="link"
              accessibilityLabel={`Visit ${lib.name} repository on GitHub`}
              accessibilityHint="Opens in Safari."
              style={({ pressed }) => [
                ss.licenseBtn,
                { backgroundColor: colors.card, borderWidth: 1,
                  borderColor: licenseColor, opacity: pressed ? 0.75 : 1 },
              ]}
            >
              <Ionicons name="logo-github" size={14} color={licenseColor} accessibilityElementsHidden />
              <Text style={[ss.licenseBtnText, { color: licenseColor, fontSize: 13 * textScale }]}>
                Repository
              </Text>
            </Pressable>
          </View>
        </View>
      )}
    </View>
  );
}

// ─── Section header ───────────────────────────────────────────────────────────

function CategoryHeader({ category, count, colors, textScale }: {
  category: Category;
  count: number;
  colors: ReturnType<typeof useTheme>['colors'];
  textScale: number;
}) {
  const meta = CATEGORY_META[category];
  return (
    <View style={ss.sectionHeader} accessible accessibilityRole="header"
      accessibilityLabel={`${category}. ${count} ${count === 1 ? 'library' : 'libraries'}.`}>
      <View style={[ss.sectionIcon, { backgroundColor: meta.color + '22' }]} accessibilityElementsHidden>
        <Ionicons name={meta.icon as any} size={16} color={meta.color} />
      </View>
      <Text style={[ss.sectionTitle, { color: colors.text, fontSize: 14 * textScale }]}>
        {category}
      </Text>
      <View style={[ss.sectionBadge, { backgroundColor: meta.color + '22' }]} accessibilityElementsHidden>
        <Text style={[ss.sectionCount, { color: meta.color }]}>{count}</Text>
      </View>
    </View>
  );
}

// ─── Main screen ──────────────────────────────────────────────────────────────

export default function OpenSourceScreen() {
  const { colors, styles }  = useTheme();
  const router               = useRouter();
  const [query, setQuery]   = useState('');
  const [licFilter, setLicFilter] = useState<LicenseType | 'All'>('All');
  const searchRef            = useRef<TextInput>(null);

  const textScale = 1;

  // Filtered + grouped libraries
  const grouped = useMemo(() => {
    const q = query.trim().toLowerCase();
    const filtered = LIBRARIES.filter(lib => {
      const matchesSearch = !q
        || lib.name.toLowerCase().includes(q)
        || lib.author.toLowerCase().includes(q)
        || lib.description.toLowerCase().includes(q)
        || lib.license.toLowerCase().includes(q);
      const matchesLic = licFilter === 'All' || lib.license === licFilter;
      return matchesSearch && matchesLic;
    });

    const map = new Map<Category, Library[]>();
    for (const cat of CATEGORY_ORDER) map.set(cat, []);
    for (const lib of filtered) {
      map.get(lib.category)!.push(lib);
    }
    return map;
  }, [query, licFilter]);

  const totalVisible  = useMemo(() => [...grouped.values()].reduce((s, a) => s + a.length, 0), [grouped]);
  const mitCount      = LIBRARIES.filter(l => l.license === 'MIT').length;
  const apacheCount   = LIBRARIES.filter(l => l.license === 'Apache-2.0').length;
  const bsdCount      = LIBRARIES.filter(l => l.license === 'BSD-3-Clause').length;

  const LICENSE_FILTERS: (LicenseType | 'All')[] = ['All', 'MIT', 'Apache-2.0', 'BSD-3-Clause'];

  return (
    <Screen title="Open Source Licences" showBack>
      <ScrollView
        style={{ flex: 1 }}
        contentContainerStyle={{ paddingHorizontal: 16, paddingBottom: 48 }}
        keyboardShouldPersistTaps="handled"
      >

        {/* ── Hero card ────────────────────────────────────────────────────── */}
        <View
          style={[ss.hero, { backgroundColor: colors.card, borderColor: colors.border }]}
          accessible
          accessibilityLabel={
            `AppleVis is built on the shoulders of ${LIBRARIES.length} open source ` +
            `libraries. ${mitCount} MIT, ${apacheCount} Apache 2.0, ${bsdCount} BSD. ` +
            `We gratefully acknowledge all contributors.`
          }
        >
          <View style={ss.heroIconRow} accessibilityElementsHidden>
            {(['code-slash-outline', 'heart-outline', 'people-outline'] as const).map((icon, i) => (
              <View key={i} style={[ss.heroIcon, { backgroundColor: ['#f97316', '#ec4899', '#8b5cf6'][i] + '22' }]}>
                <Ionicons name={icon} size={22} color={['#f97316', '#ec4899', '#8b5cf6'][i]} />
              </View>
            ))}
          </View>
          <Text style={[ss.heroTitle, { color: colors.text, fontSize: 17 * textScale }]}>
            Built on Open Source
          </Text>
          <Text style={[ss.heroSub, { color: colors.textSecondary, fontSize: 14 * textScale }]}>
            AppleVis is made possible by {LIBRARIES.length} open source libraries.
            We are grateful to every contributor whose work helps us serve the blind
            and low-vision community.
          </Text>
          {/* Stat chips */}
          <View style={ss.statRow} accessibilityElementsHidden>
            {([
              { label: `${mitCount} MIT`,            color: LICENSE_COLOR['MIT'] },
              { label: `${apacheCount} Apache 2.0`,  color: LICENSE_COLOR['Apache-2.0'] },
              { label: `${bsdCount} BSD`,            color: LICENSE_COLOR['BSD-3-Clause'] },
            ] as const).map(({ label, color }) => (
              <View key={label} style={[ss.statChip, { backgroundColor: color + '1a', borderColor: color + '44' }]}>
                <Text style={[ss.statChipText, { color }]}>{label}</Text>
              </View>
            ))}
          </View>
        </View>

        {/* ── Search bar ───────────────────────────────────────────────────── */}
        <View
          style={[ss.searchBar, { backgroundColor: colors.card, borderColor: colors.border }]}
          accessible={false}
        >
          <Ionicons name="search-outline" size={16} color={colors.textSecondary}
            accessibilityElementsHidden />
          <TextInput
            ref={searchRef}
            value={query}
            onChangeText={setQuery}
            placeholder="Search libraries…"
            placeholderTextColor={colors.textSecondary}
            style={[ss.searchInput, { color: colors.text, fontSize: 15 * textScale }]}
            returnKeyType="search"
            clearButtonMode="while-editing"
            accessibilityLabel="Search libraries"
            accessibilityHint="Filter by library name, author, or description."
          />
          {!!query && (
            <Pressable
              onPress={() => setQuery('')}
              accessible
              accessibilityRole="button"
              accessibilityLabel="Clear search"
              style={{ padding: 4 }}
            >
              <Ionicons name="close-circle" size={16} color={colors.textSecondary} />
            </Pressable>
          )}
        </View>

        {/* ── Licence filter pills ─────────────────────────────────────────── */}
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          style={{ marginBottom: 16 }}
          contentContainerStyle={{ gap: 8, paddingVertical: 2 }}
          accessible={false}
        >
          {LICENSE_FILTERS.map(f => {
            const active = licFilter === f;
            const color  = f === 'All' ? colors.accent : LICENSE_COLOR[f as LicenseType];
            return (
              <Pressable
                key={f}
                onPress={() => setLicFilter(f)}
                accessible
                accessibilityRole="button"
                accessibilityLabel={f === 'All' ? 'Show all licences' : `Filter by ${f} licence`}
                accessibilityState={{ selected: active }}
                style={[
                  ss.filterPill,
                  {
                    backgroundColor: active ? color : colors.pill,
                    borderColor: active ? color : colors.border,
                  },
                ]}
              >
                <Text style={[ss.filterPillText, {
                  color: active ? '#fff' : colors.textSecondary,
                  fontSize: 13 * textScale,
                }]}>
                  {f}
                </Text>
              </Pressable>
            );
          })}
        </ScrollView>

        {/* ── Result count ─────────────────────────────────────────────────── */}
        {(query || licFilter !== 'All') && (
          <Text
            style={[ss.resultCount, { color: colors.textSecondary, fontSize: 13 * textScale }]}
            accessibilityLiveRegion="polite"
            accessibilityLabel={`${totalVisible} ${totalVisible === 1 ? 'library' : 'libraries'} found.`}
          >
            {totalVisible} {totalVisible === 1 ? 'library' : 'libraries'} found
          </Text>
        )}

        {/* ── No results ───────────────────────────────────────────────────── */}
        {totalVisible === 0 && (
          <View style={[ss.empty, { backgroundColor: colors.card, borderColor: colors.border }]}
            accessible accessibilityLabel="No libraries match your search. Try a different term.">
            <Ionicons name="search-outline" size={32} color={colors.textSecondary}
              accessibilityElementsHidden />
            <Text style={[ss.emptyText, { color: colors.textSecondary }]}>
              No libraries match your search.
            </Text>
          </View>
        )}

        {/* ── Categorised library list ──────────────────────────────────────── */}
        {CATEGORY_ORDER.map(cat => {
          const libs = grouped.get(cat) ?? [];
          if (libs.length === 0) return null;
          return (
            <View key={cat}>
              <CategoryHeader
                category={cat}
                count={libs.length}
                colors={colors}
                textScale={textScale}
              />
              {libs.map(lib => (
                <LibraryCard key={lib.name} lib={lib} colors={colors} textScale={textScale} />
              ))}
            </View>
          );
        })}

        {/* ── Footer ───────────────────────────────────────────────────────── */}
        <View
          style={[ss.footer, { borderTopColor: colors.border }]}
          accessible
          accessibilityLabel={
            `This screen lists ${LIBRARIES.length} open source packages used in AppleVis. ` +
            'Each library is used under the terms of its respective licence.'
          }
        >
          <Ionicons name="heart" size={16} color="#ec4899" accessibilityElementsHidden />
          <Text style={[ss.footerText, { color: colors.textSecondary, fontSize: 13 * textScale }]}>
            Thank you to every open source contributor whose work
            {'\n'}helps us make technology more accessible.
          </Text>
        </View>

      </ScrollView>
    </Screen>
  );
}

// ─── Styles ───────────────────────────────────────────────────────────────────

const ss = StyleSheet.create({
  // Hero
  hero: {
    borderRadius: 14, borderWidth: 1, padding: 20,
    marginBottom: 16, alignItems: 'center',
  },
  heroIconRow:  { flexDirection: 'row', gap: 12, marginBottom: 14 },
  heroIcon:     { width: 48, height: 48, borderRadius: 12, alignItems: 'center', justifyContent: 'center' },
  heroTitle:    { fontWeight: '800', textAlign: 'center', marginBottom: 8 },
  heroSub:      { textAlign: 'center', lineHeight: 20, marginBottom: 14 },
  statRow:      { flexDirection: 'row', gap: 8, flexWrap: 'wrap', justifyContent: 'center' },
  statChip:     { borderRadius: 20, borderWidth: 1, paddingHorizontal: 10, paddingVertical: 4 },
  statChipText: { fontSize: 12, fontWeight: '700' },

  // Search
  searchBar: {
    flexDirection: 'row', alignItems: 'center', gap: 8,
    borderRadius: 12, borderWidth: 1, paddingHorizontal: 12, paddingVertical: 10,
    marginBottom: 12,
  },
  searchInput:  { flex: 1, paddingVertical: 0 },

  // Filters
  filterPill:     { borderRadius: 20, borderWidth: 1, paddingHorizontal: 14, paddingVertical: 7, minHeight: 36, justifyContent: 'center' },
  filterPillText: { fontWeight: '600' },

  resultCount: { marginBottom: 8, marginLeft: 2 },

  // Empty
  empty: {
    borderRadius: 12, borderWidth: 1, padding: 32,
    alignItems: 'center', gap: 12, marginBottom: 16,
  },
  emptyText: { fontSize: 15, textAlign: 'center' },

  // Category section
  sectionHeader: {
    flexDirection: 'row', alignItems: 'center', gap: 10,
    marginTop: 20, marginBottom: 10,
  },
  sectionIcon:   { width: 30, height: 30, borderRadius: 8, alignItems: 'center', justifyContent: 'center' },
  sectionTitle:  { flex: 1, fontWeight: '700' },
  sectionBadge:  { borderRadius: 10, paddingHorizontal: 8, paddingVertical: 2 },
  sectionCount:  { fontSize: 12, fontWeight: '700' },

  // Library card
  card: {
    borderRadius: 12, borderWidth: 1,
    marginBottom: 10, overflow: 'hidden',
  },
  cardPressable: { padding: 14 },
  nameRow:       { flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 6 },
  libName:       { fontWeight: '700', flex: 1 },
  version:       { fontWeight: '500' },
  badgeRow:      { flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 6 },
  badge:         { borderRadius: 6, borderWidth: 1, paddingHorizontal: 7, paddingVertical: 2 },
  badgeText:     { fontSize: 11, fontWeight: '700', letterSpacing: 0.3 },
  author:        { flex: 1 },
  description:   { lineHeight: 19, marginBottom: 10 },
  expandRow:     { flexDirection: 'row', alignItems: 'center', gap: 4 },
  expandLabel:   { fontWeight: '600' },

  // Expanded licence
  licenseBox:    { borderTopWidth: StyleSheet.hairlineWidth, padding: 14, gap: 10 },
  licenseHeading:{ fontWeight: '700', marginBottom: 4 },
  licenseBody:   { lineHeight: 20 },
  licenseActions:{ flexDirection: 'row', gap: 8, marginTop: 4 },
  licenseBtn: {
    flexDirection: 'row', alignItems: 'center', gap: 6,
    borderRadius: 8, paddingHorizontal: 14, paddingVertical: 9,
    minHeight: 44,
  },
  licenseBtnText:{ color: '#fff', fontWeight: '700' },

  // Footer
  footer: {
    borderTopWidth: StyleSheet.hairlineWidth,
    marginTop: 24, paddingTop: 20,
    alignItems: 'center', gap: 8,
  },
  footerText: { textAlign: 'center', lineHeight: 20 },
});
