import { useEffect } from 'react';
import { useLocalSearchParams, useRouter } from 'expo-router';

// This route is kept for backwards-compatibility with the Share Extension deep link
// (applevis://submit-app?url=...). It immediately forwards to the wizard.
export default function SubmitAppRedirect() {
  const router = useRouter();
  const { url } = useLocalSearchParams<{ url?: string }>();

  useEffect(() => {
    // Replace so the back stack doesn't include this stub.
    router.replace((url ? `/submit-wizard?url=${encodeURIComponent(url)}` : '/submit-wizard') as any);
  }, []);

  return null;
}
