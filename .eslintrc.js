module.exports = {
  root: true,
  parser: '@typescript-eslint/parser',
  parserOptions: {
    ecmaVersion: 2022,
    sourceType: 'module',
    ecmaFeatures: { jsx: true },
  },
  plugins: [
    '@typescript-eslint',
    'react',
    'react-hooks',
    'react-native',
    'react-native-a11y',
  ],
  extends: [
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended',
    'plugin:react/recommended',
    'plugin:react-hooks/recommended',
  ],
  settings: {
    react: { version: 'detect' },
  },
  env: {
    'react-native/react-native': true,
    es2022: true,
    node: true,
  },
  rules: {
    // ── TypeScript ────────────────────────────────────────────────────────────
    '@typescript-eslint/no-explicit-any': 'warn',
    '@typescript-eslint/no-unused-vars': ['warn', { argsIgnorePattern: '^_', varsIgnorePattern: '^_' }],
    '@typescript-eslint/no-non-null-assertion': 'warn',

    // ── React ─────────────────────────────────────────────────────────────────
    'react/react-in-jsx-scope': 'off',          // not needed in React 17+
    'react/prop-types': 'off',                  // TypeScript handles this
    'react/display-name': 'warn',

    // ── React Hooks ───────────────────────────────────────────────────────────
    'react-hooks/rules-of-hooks': 'error',       // hooks must follow rules
    'react-hooks/exhaustive-deps': 'warn',        // missing deps = stale closures / memory leaks

    // react-hooks v7 experimental rules — disabled because they produce false
    // positives on standard React Native patterns (Animated.Value, async setState
    // in effects, Date.now() in render-time helper functions).
    'react-hooks/purity': 'off',
    'react-hooks/refs': 'off',
    'react-hooks/set-state-in-effect': 'off',

    // ── React Native ──────────────────────────────────────────────────────────
    'react-native/no-unused-styles': 'warn',
    'react-native/no-inline-styles': 'off',      // we use inline styles intentionally
    'react-native/no-color-literals': 'off',     // handled by theme system
    'react-native/no-raw-text': 'off',           // too noisy for this project

    // ── Accessibility (react-native-a11y) ─────────────────────────────────────
    'react-native-a11y/has-accessibility-props': 'warn',
    'react-native-a11y/has-valid-accessibility-role': 'error',
    'react-native-a11y/no-nested-touchables': 'warn',

    // ── General quality ───────────────────────────────────────────────────────
    'no-console': ['warn', { allow: ['warn', 'error'] }],
    'no-debugger': 'error',
    'no-unreachable': 'error',
    'no-unused-expressions': 'warn',
    'prefer-const': 'warn',
    'no-var': 'error',
  },
  ignorePatterns: [
    'node_modules/',
    '.expo/',
    'dist/',
    'build/',
    'plugins/',       // JS config plugins are plain JS
    '*.config.js',
    '*.config.ts',
  ],
};
