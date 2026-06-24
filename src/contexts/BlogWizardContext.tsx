import { createContext, useContext, useState, type ReactNode } from 'react';

export type BlogWizardState = {
  title:       string;
  category:    string;
  coverNote:   string;   // → message field (title + category + note formatted together)
  blogContent: string;   // → blog_draft field
};

const INITIAL: BlogWizardState = {
  title:       '',
  category:    '',
  coverNote:   '',
  blogContent: '',
};

type BlogWizardContextValue = {
  state:  BlogWizardState;
  update: (patch: Partial<BlogWizardState>) => void;
  reset:  () => void;
};

const BlogWizardContext = createContext<BlogWizardContextValue>({
  state:  INITIAL,
  update: () => {},
  reset:  () => {},
});

export function BlogWizardProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<BlogWizardState>(INITIAL);
  return (
    <BlogWizardContext.Provider value={{
      state,
      update: patch => setState(prev => ({ ...prev, ...patch })),
      reset:  () => setState(INITIAL),
    }}>
      {children}
    </BlogWizardContext.Provider>
  );
}

export function useBlogWizard(): BlogWizardContextValue {
  return useContext(BlogWizardContext);
}

// Blog categories (vocabulary_13 from AppleVis)
export const BLOG_CATEGORIES = [
  'Accessories', 'Advocacy', 'Apple', 'Apple TV', 'Apple Vision Pro',
  'Apple Watch', 'AppleVis', 'Assistive Technology', 'Braille', 'Gaming',
  'iOS', 'iOS and iPadOS Apps', 'iPad', 'iPadOS', 'iPhone',
  'Mac Apps', 'macOS', 'News', 'Opinion', 'Reviews', 'Rumors',
] as const;

export type BlogCategory = typeof BLOG_CATEGORIES[number];
