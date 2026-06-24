import React, { createContext, useContext, useState } from 'react';

export type ContactType = 'bug' | 'feedback' | 'suggestion' | 'recommendation';

const SUBJECT_MAP: Record<ContactType, string> = {
  bug:            'App Bug Report',
  feedback:       'App Feedback',
  suggestion:     'App Suggestion',
  recommendation: 'App Recommendation',
};

type ContactState = {
  contactType:    ContactType | null;
  subject:        string;
  message:        string;
  includeSysInfo: boolean;
  name:           string;
  email:          string;
  declaration:    boolean;
};

type ContactWizardContextValue = {
  state: ContactState;
  set:   (patch: Partial<ContactState>) => void;
  pickType: (t: ContactType) => void;
  reset: () => void;
};

const initial: ContactState = {
  contactType:    null,
  subject:        '',
  message:        '',
  includeSysInfo: false,
  name:           '',
  email:          '',
  declaration:    false,
};

const ContactWizardContext = createContext<ContactWizardContextValue | null>(null);

export function ContactWizardProvider({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState<ContactState>(initial);

  function set(patch: Partial<ContactState>) {
    setState(s => ({ ...s, ...patch }));
  }

  function pickType(t: ContactType) {
    setState(s => ({ ...s, contactType: t, subject: SUBJECT_MAP[t] }));
  }

  function reset() { setState(initial); }

  return (
    <ContactWizardContext.Provider value={{ state, set, pickType, reset }}>
      {children}
    </ContactWizardContext.Provider>
  );
}

export function useContactWizard() {
  const ctx = useContext(ContactWizardContext);
  if (!ctx) throw new Error('useContactWizard must be used within ContactWizardProvider');
  return ctx;
}
