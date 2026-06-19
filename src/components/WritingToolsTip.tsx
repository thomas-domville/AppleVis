import { useTranslation } from 'react-i18next';
import { HelpfulTip } from './HelpfulTip';

export function WritingToolsTip() {
  const { t } = useTranslation();

  return (
    <HelpfulTip
      id="compose-writing-tools"
      syncDismissal
      message={t('writingTools.tip')}
      accessibilityLabel={t('writingTools.a11yLabel')}
    />
  );
}
