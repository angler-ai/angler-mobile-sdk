import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

/**
 * Codegen spec for the `AnglerAnalytics` TurboModule. Structured arguments cross the bridge
 * as JSON strings so both platforms parse them the same way.
 */
export interface Spec extends TurboModule {
  configure(configJson: string): void;
  track(name: string, dataJson: string | null, propertiesJson: string | null, eventId: string | null): void;
  handleDeepLink(url: string): void;
  setUserId(userId: string | null): void;
  setIdentifier(name: string, value: string | null): void;
  setApplicationTrackingEnabled(enabled: boolean): void;
  setEnabled(enabled: boolean): void;
  flush(): void;
  reset(): void;
  getClientId(): Promise<string | null>;
}

// `get`, not `getEnforcing`: a missing native module must not throw at import time.
export default TurboModuleRegistry.get<Spec>('AnglerAnalytics');
