import { Linking } from 'react-native';
import NativeAnglerAnalytics, { type Spec } from './NativeAnglerAnalytics';

export type AnglerConfig = {
  workspaceId: string;
  /** Workspace JWT. */
  token: string;
  /** `data.getangler.ai` (default) or `dev-data.getangler.ai`. */
  domain?: string;
  /** Overrides `client_id`. Defaults to the install ID. */
  clientId?: string;
  trackLifecycleEvents?: boolean;
  flushAt?: number;
  flushIntervalSeconds?: number;
  maxQueueSize?: number;
  debugLogging?: boolean;
  /** Subscribe to `Linking` and forward deep links automatically. Default `true`. */
  autoHandleDeepLinks?: boolean;
};

export type TrackOptions = {
  data?: Record<string, unknown>;
  properties?: Record<string, string>;
  eventId?: string;
};

declare const __DEV__: boolean;

function warn(message: string, error?: unknown): void {
  if (typeof __DEV__ !== 'undefined' && __DEV__) {
    // eslint-disable-next-line no-console
    console.warn(`[Angler] ${message}`, error ?? '');
  }
}

/** Runs a native call. Analytics must never crash the host app, so nothing escapes. */
function call(fn: (native: Spec) => void): void {
  const native = NativeAnglerAnalytics;
  if (!native) {
    warn('native module AnglerAnalytics is not linked; is the app rebuilt with the New Architecture?');
    return;
  }
  try {
    fn(native);
  } catch (e) {
    warn('native call failed', e);
  }
}

function toJson(value: unknown, what: string): string | null {
  try {
    const json = JSON.stringify(value);
    return json === undefined ? null : json;
  } catch (e) {
    warn(`${what} is not serializable to JSON; sending the event without it`, e);
    return null;
  }
}

let linkingSubscribed = false;

function subscribeToDeepLinks(): void {
  if (linkingSubscribed) return;
  linkingSubscribed = true;
  try {
    Linking.getInitialURL()
      .then((url) => {
        if (url) call((n) => n.handleDeepLink(url));
      })
      .catch((e) => warn('Linking.getInitialURL failed', e));
    Linking.addEventListener('url', ({ url }) => {
      if (url) call((n) => n.handleDeepLink(url));
    });
  } catch (e) {
    warn('could not subscribe to Linking', e);
  }
}

export const Angler = {
  /** Starts the SDK. Safe to call again (e.g. on Fast Refresh): repeats are ignored. */
  configure(config: AnglerConfig): void {
    try {
      const { autoHandleDeepLinks = true, ...rest } = config ?? ({} as AnglerConfig);
      const fields: Record<string, unknown> = {};
      for (const [k, v] of Object.entries(rest)) if (v !== undefined && v !== null) fields[k] = v;
      fields.wrapper = 'react-native';
      const json = toJson(fields, 'config');
      if (json) call((n) => n.configure(json));
      // After configure, so the native side is set up before the initial URL arrives.
      if (autoHandleDeepLinks) subscribeToDeepLinks();
    } catch (e) {
      warn('configure failed', e);
    }
  },

  /** Queues an event. Unknown names are sent as `custom_event`. */
  track(name: string, options?: TrackOptions): void {
    try {
      const { data, properties, eventId } = options ?? {};
      const dataJson = data && Object.keys(data).length > 0 ? toJson(data, 'data') : null;
      let propertiesJson: string | null = null;
      if (properties) {
        const strings: Record<string, string> = {};
        for (const [k, v] of Object.entries(properties)) {
          if (typeof v === 'string') strings[k] = v;
          else warn(`property '${k}' is not a string; dropped`);
        }
        if (Object.keys(strings).length > 0) propertiesJson = toJson(strings, 'properties');
      }
      call((n) => n.track(String(name), dataJson, propertiesJson, eventId ?? null));
    } catch (e) {
      warn('track failed', e);
    }
  },

  /** Captures click IDs from a URL. Called automatically unless `autoHandleDeepLinks` is false. */
  handleDeepLink(url: string): void {
    call((n) => n.handleDeepLink(String(url)));
  },

  setUserId(userId: string | null): void {
    call((n) => n.setUserId(userId ?? null));
  },

  setIdentifier(name: string, value: string | null): void {
    call((n) => n.setIdentifier(String(name), value ?? null));
  },

  setApplicationTrackingEnabled(enabled: boolean): void {
    call((n) => n.setApplicationTrackingEnabled(Boolean(enabled)));
  },

  /** `false` stops all collection and deletes queued events. */
  setEnabled(enabled: boolean): void {
    call((n) => n.setEnabled(Boolean(enabled)));
  },

  flush(): void {
    call((n) => n.flush());
  },

  reset(): void {
    call((n) => n.reset());
  },
};

export default Angler;
