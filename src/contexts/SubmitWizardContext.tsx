import { createContext, useContext, useState, type ReactNode } from 'react';
import type { ItunesSearchHit, ItunesMetadata } from '../services/itunesApi';

export type WizardPlatform = 'ios' | 'macos' | 'tvos';

export type WizardState = {
  // Step 1 — declarations
  agreedPersonalUse:   boolean;
  agreedNotDeveloper:  boolean;
  // Step 2 — platform
  platform: WizardPlatform | null;
  // Step 3 — search
  searchHit: ItunesSearchHit | null;
  // Step 4 — confirm
  fullMeta:            ItunesMetadata | null;
  duplicateStatus:     'idle' | 'checking' | 'clear' | 'duplicate' | 'unknown';
  existingEntryId:     string | null;
  existingEntryTitle:  string | null;
  // Step 5 — notes & assessment
  osVersion:             string;
  accessibilityComments: string;  // field_comments — required, ≥20 chars
  voiceOverPerformance:  string;  // field_voiceover — required picker
  buttonLabelling:       string;  // field_labelling — required picker
  usabilityNotes:        string;  // field_usability — required picker
  otherComments:         string;  // field_other_comments — optional
  shortSummary:          string;  // optional headline for the listing
};

const INITIAL: WizardState = {
  agreedPersonalUse:     false,
  agreedNotDeveloper:    false,
  platform:              null,
  searchHit:             null,
  fullMeta:              null,
  duplicateStatus:       'idle',
  existingEntryId:       null,
  existingEntryTitle:    null,
  osVersion:             '',
  accessibilityComments: '',
  voiceOverPerformance:  '',
  buttonLabelling:       '',
  usabilityNotes:        '',
  otherComments:         '',
  shortSummary:          '',
};

type WizardContextValue = {
  state:  WizardState;
  update: (patch: Partial<WizardState>) => void;
  reset:  () => void;
};

const WizardContext = createContext<WizardContextValue>({
  state:  INITIAL,
  update: () => {},
  reset:  () => {},
});

export function WizardProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<WizardState>(INITIAL);
  function update(patch: Partial<WizardState>) {
    setState(prev => ({ ...prev, ...patch }));
  }
  function reset() {
    setState(INITIAL);
  }
  return (
    <WizardContext.Provider value={{ state, update, reset }}>
      {children}
    </WizardContext.Provider>
  );
}

export function useWizard(): WizardContextValue {
  return useContext(WizardContext);
}
