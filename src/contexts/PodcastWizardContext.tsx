import { createContext, useContext, useState, type ReactNode } from 'react';

export type AudioFileInfo = {
  uri:  string;
  name: string;
  type: string;   // MIME type
  size: number;   // bytes
};

export type PodcastWizardState = {
  description: string;
  audioFile:   AudioFileInfo | null;
};

const INITIAL: PodcastWizardState = {
  description: '',
  audioFile:   null,
};

type PodcastWizardContextValue = {
  state:  PodcastWizardState;
  update: (patch: Partial<PodcastWizardState>) => void;
  reset:  () => void;
};

const PodcastWizardContext = createContext<PodcastWizardContextValue>({
  state:  INITIAL,
  update: () => {},
  reset:  () => {},
});

export function PodcastWizardProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<PodcastWizardState>(INITIAL);
  return (
    <PodcastWizardContext.Provider value={{
      state,
      update: patch => setState(prev => ({ ...prev, ...patch })),
      reset:  () => setState(INITIAL),
    }}>
      {children}
    </PodcastWizardContext.Provider>
  );
}

export function usePodcastWizard(): PodcastWizardContextValue {
  return useContext(PodcastWizardContext);
}

export const AUDIO_MIME_TYPES = ['audio/mpeg', 'audio/mp4', 'audio/x-m4a', 'audio/wav', 'audio/x-wav', 'audio/aiff', 'audio/x-aiff'];
