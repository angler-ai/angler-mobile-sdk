/* eslint-disable @typescript-eslint/no-explicit-any */
type NativeMock = Record<
  'configure' | 'track' | 'handleDeepLink' | 'setUserId' | 'setIdentifier' |
  'setApplicationTrackingEnabled' | 'setEnabled' | 'flush' | 'reset' | 'getClientId',
  jest.Mock
>;

let native: NativeMock;
let Linking: { getInitialURL: jest.Mock; addEventListener: jest.Mock };
let urlHandler: ((e: { url: string }) => void) | undefined;
let Angler: typeof import('../index').Angler;

const flushPromises = () => new Promise<void>((r) => setImmediate(r));
const emitUrl = (url: string) => urlHandler?.({ url });

beforeEach(() => {
  jest.resetModules();
  urlHandler = undefined;
  native = {
    configure: jest.fn(), track: jest.fn(), handleDeepLink: jest.fn(), setUserId: jest.fn(),
    setIdentifier: jest.fn(), setApplicationTrackingEnabled: jest.fn(), setEnabled: jest.fn(),
    flush: jest.fn(), reset: jest.fn(), getClientId: jest.fn(() => Promise.resolve('aid-1')),
  };
  Linking = {
    getInitialURL: jest.fn(() => Promise.resolve(null)),
    addEventListener: jest.fn((_type: string, cb: (e: { url: string }) => void) => {
      urlHandler = cb;
      return { remove: jest.fn() };
    }),
  };
  jest.doMock('../NativeAnglerAnalytics', () => ({ __esModule: true, default: native }));
  jest.doMock('react-native', () => ({ Linking }));
  jest.spyOn(console, 'warn').mockImplementation(() => {});
  Angler = require('../index').Angler;
});

afterEach(() => jest.restoreAllMocks());

test('configure sends JSON with wrapper and without autoHandleDeepLinks', () => {
  Angler.configure({ workspaceId: 'ws', token: 't', autoHandleDeepLinks: false });
  expect(JSON.parse(native.configure.mock.calls[0][0])).toEqual({ workspaceId: 'ws', token: 't', wrapper: 'react-native' });
});

test('configure passes optional fields through and leaves missing ones out', () => {
  Angler.configure({ workspaceId: 'ws', token: 't', domain: 'dev-data.getangler.ai', flushAt: 5, clientId: undefined, autoHandleDeepLinks: false });
  expect(JSON.parse(native.configure.mock.calls[0][0])).toEqual({
    workspaceId: 'ws', token: 't', domain: 'dev-data.getangler.ai', flushAt: 5, wrapper: 'react-native',
  });
});

test('track serializes data and properties', () => {
  Angler.track('product_viewed', { data: { productVariant: { id: 'v1' } }, properties: { a: '1' } });
  expect(native.track).toHaveBeenCalledWith('product_viewed', '{"productVariant":{"id":"v1"}}', '{"a":"1"}', null);
});

test('track passes eventId and sends nulls when there is nothing', () => {
  Angler.track('purchase', { eventId: 'order-1' });
  Angler.track('x');
  expect(native.track.mock.calls).toEqual([['purchase', null, null, 'order-1'], ['x', null, null, null]]);
});

test('unserializable data is dropped, event still sent', () => {
  const d: any = {};
  d.self = d;
  expect(() => Angler.track('x', { data: d })).not.toThrow();
  expect(native.track).toHaveBeenCalledWith('x', null, null, null);
  expect(() => Angler.track('y', { data: { n: BigInt(1) } as any })).not.toThrow();
  expect(native.track).toHaveBeenLastCalledWith('y', null, null, null);
});

test('non-string property values are dropped', () => {
  Angler.track('x', { properties: { a: '1', b: 2 as any } });
  expect(native.track).toHaveBeenCalledWith('x', null, '{"a":"1"}', null);
});

test('initial URL and url events are forwarded once across repeated configure', async () => {
  Linking.getInitialURL.mockResolvedValue('myapp://p?gclid=g');
  Angler.configure({ workspaceId: 'ws', token: 't' });
  Angler.configure({ workspaceId: 'ws', token: 't' });
  await flushPromises();
  emitUrl('myapp://q?fbclid=f');
  expect(native.handleDeepLink.mock.calls).toEqual([['myapp://p?gclid=g'], ['myapp://q?fbclid=f']]);
  expect(Linking.addEventListener).toHaveBeenCalledTimes(1);
});

test('autoHandleDeepLinks false does not subscribe', async () => {
  Linking.getInitialURL.mockResolvedValue('myapp://p?gclid=g');
  Angler.configure({ workspaceId: 'ws', token: 't', autoHandleDeepLinks: false });
  await flushPromises();
  expect(Linking.getInitialURL).not.toHaveBeenCalled();
  expect(Linking.addEventListener).not.toHaveBeenCalled();
  expect(native.handleDeepLink).not.toHaveBeenCalled();
});

test('getInitialURL rejecting does not surface', async () => {
  Linking.getInitialURL.mockRejectedValue(new Error('no'));
  expect(() => Angler.configure({ workspaceId: 'ws', token: 't' })).not.toThrow();
  await flushPromises();
  expect(native.handleDeepLink).not.toHaveBeenCalled();
});

test('native exceptions are swallowed', () => {
  native.flush.mockImplementation(() => {
    throw new Error('x');
  });
  expect(() => Angler.flush()).not.toThrow();
});

test('other methods forward to native', () => {
  Angler.handleDeepLink('myapp://x');
  Angler.setUserId(null);
  Angler.setIdentifier('appsflyer_id', 'af');
  Angler.setApplicationTrackingEnabled(false);
  Angler.setEnabled(true);
  Angler.flush();
  Angler.reset();
  expect(native.handleDeepLink).toHaveBeenCalledWith('myapp://x');
  expect(native.setUserId).toHaveBeenCalledWith(null);
  expect(native.setIdentifier).toHaveBeenCalledWith('appsflyer_id', 'af');
  expect(native.setApplicationTrackingEnabled).toHaveBeenCalledWith(false);
  expect(native.setEnabled).toHaveBeenCalledWith(true);
  expect(native.flush).toHaveBeenCalled();
  expect(native.reset).toHaveBeenCalled();
});

test('missing native module never throws', () => {
  jest.resetModules();
  jest.doMock('../NativeAnglerAnalytics', () => ({ __esModule: true, default: null }));
  jest.doMock('react-native', () => ({ Linking }));
  const { Angler: A } = require('../index');
  expect(() => {
    A.configure({ workspaceId: 'ws', token: 't' });
    A.track('x');
    A.flush();
  }).not.toThrow();
});

test('getClientId resolves the native client ID', async () => {
  await expect(Angler.getClientId()).resolves.toBe('aid-1');
});

test('getClientId resolves null when native has none or fails', async () => {
  native.getClientId.mockReturnValueOnce(Promise.resolve(undefined));
  await expect(Angler.getClientId()).resolves.toBeNull();
  native.getClientId.mockReturnValueOnce(Promise.reject(new Error('boom')));
  await expect(Angler.getClientId()).resolves.toBeNull();
  native.getClientId.mockImplementationOnce(() => {
    throw new Error('sync boom');
  });
  await expect(Angler.getClientId()).resolves.toBeNull();
});

test('getClientId resolves null when the native module is not linked', async () => {
  jest.resetModules();
  jest.doMock('../NativeAnglerAnalytics', () => ({ __esModule: true, default: null }));
  jest.doMock('react-native', () => ({ Linking }));
  const unlinked = require('../index').Angler as typeof Angler;
  await expect(unlinked.getClientId()).resolves.toBeNull();
});
