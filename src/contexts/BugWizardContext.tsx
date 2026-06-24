import { createContext, useContext, useState, type ReactNode } from 'react';

export type BugPlatform    = 'iOS' | 'iPadOS' | 'macOS';
export type BugReproducible = 'Yes, always' | 'Yes, sometimes' | 'No';
export type BugRecognition  =
  | 'Yes - please use my name.'
  | 'Yes - please use my AppleVis username'
  | 'No - please thank/recognize me anonymously';

export type BugWizardState = {
  platform:        BugPlatform | '';
  softwareVersion: string;
  title:           string;
  appleFeedback:   string;
  canReproduce:    BugReproducible | '';
  description:     string;
  recognition:     BugRecognition | '';
};

const INITIAL: BugWizardState = {
  platform:        '',
  softwareVersion: '',
  title:           '',
  appleFeedback:   '',
  canReproduce:    '',
  description:     '',
  recognition:     '',
};

type BugWizardContextValue = {
  state:  BugWizardState;
  update: (patch: Partial<BugWizardState>) => void;
  reset:  () => void;
};

const BugWizardContext = createContext<BugWizardContextValue>({
  state:  INITIAL,
  update: () => {},
  reset:  () => {},
});

export function BugWizardProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<BugWizardState>(INITIAL);
  return (
    <BugWizardContext.Provider value={{
      state,
      update: patch => setState(prev => ({ ...prev, ...patch })),
      reset:  () => setState(INITIAL),
    }}>
      {children}
    </BugWizardContext.Provider>
  );
}

export function useBugWizard(): BugWizardContextValue {
  return useContext(BugWizardContext);
}

export const PLATFORM_OPTIONS: BugPlatform[]      = ['iOS', 'iPadOS', 'macOS'];
export const REPRODUCIBLE_OPTIONS: BugReproducible[] = ['Yes, always', 'Yes, sometimes', 'No'];
export const RECOGNITION_OPTIONS: BugRecognition[] = [
  'Yes - please use my name.',
  'Yes - please use my AppleVis username',
  'No - please thank/recognize me anonymously',
];
