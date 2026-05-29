import { Audio } from 'expo-av';

export async function configurePodcastAudioMode() {
  await Audio.setAudioModeAsync({
    allowsRecordingIOS: false,
    staysActiveInBackground: true,
    playsInSilentModeIOS: true,
    shouldDuckAndroid: true,
    playThroughEarpieceAndroid: false
  });
}

export const podcastRequirements = {
  playbackSpeed: true,
  adjustableSkipTimes: true,
  chapters: true,
  smartSpeed: 'Requires native DSP or audio processing module for production.',
  voiceEnhancement: 'Requires AVAudioEngine/native implementation for production.',
  equalizer: 'Requires native audio pipeline or supported playback engine.',
  lockScreenControls: 'Use Now Playing / MPRemoteCommandCenter in native iOS layer.',
  liveActivities: 'Requires ActivityKit native module or config plugin.',
  appleWatch: 'Requires watchOS target in native iOS project.'
};
