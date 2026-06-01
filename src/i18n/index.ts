/**
 * Internationalisation setup
 *
 * Supports 13 languages. RTL is detected automatically for Arabic and Persian.
 * Dynamic strings (dates, relative times) are handled by Intl built-ins —
 * they respect the device locale without any extra configuration here.
 *
 * Usage:
 *   import { t, isRTL } from '../../src/i18n';
 *   // or inside a React component:
 *   import { useTranslation } from 'react-i18next';
 *   const { t } = useTranslation();
 */

import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import * as Localization from 'expo-localization';

import en from './locales/en.json';
import es from './locales/es.json';
import fr from './locales/fr.json';
import de from './locales/de.json';
import pt from './locales/pt.json';
import it from './locales/it.json';
import ja from './locales/ja.json';
import ko from './locales/ko.json';
import nl from './locales/nl.json';
import zh from './locales/zh.json';
import ar from './locales/ar.json';
import hi from './locales/hi.json';
import fa from './locales/fa.json';

// ─── Language detection ───────────────────────────────────────────────────────

const SUPPORTED = new Set(['en','es','fr','de','pt','it','ja','ko','nl','zh','ar','hi','fa']);
const RTL_LANGS  = new Set(['ar', 'fa', 'he', 'ur']);

const deviceLocales = Localization.getLocales();
const deviceCode    = deviceLocales[0]?.languageCode ?? 'en';
// zh-Hant → zh, pt-BR → pt, etc.
const baseCode      = deviceCode.split('-')[0].toLowerCase();
const resolvedLang  = SUPPORTED.has(baseCode) ? baseCode : 'en';

/** True when the active language reads right-to-left. */
export const isRTL: boolean = RTL_LANGS.has(resolvedLang);

/** The resolved BCP-47 language code in use. */
export const currentLanguage: string = resolvedLang;

// ─── i18next init ─────────────────────────────────────────────────────────────

i18n.use(initReactI18next).init({
  resources: {
    en: { translation: en },
    es: { translation: es },
    fr: { translation: fr },
    de: { translation: de },
    pt: { translation: pt },
    it: { translation: it },
    ja: { translation: ja },
    ko: { translation: ko },
    nl: { translation: nl },
    zh: { translation: zh },
    ar: { translation: ar },
    hi: { translation: hi },
    fa: { translation: fa },
  },
  lng:          resolvedLang,
  fallbackLng:  'en',
  interpolation: { escapeValue: false },
  // Pluralisation is handled per-language by i18next.
  // Arabic has 6 plural forms; we fall back to English rules for now.
  // A future update can add full CLDR plural rules if needed.
});

export { i18n };
export default i18n;
