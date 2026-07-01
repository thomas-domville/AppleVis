import { Stack } from 'expo-router';
import { ContactWizardProvider } from '../../src/contexts/ContactWizardContext';

export default function ContactLayout() {
  return (
    <ContactWizardProvider>
      <Stack screenOptions={{ headerShown: false, animation: 'slide_from_right' }} />
    </ContactWizardProvider>
  );
}
