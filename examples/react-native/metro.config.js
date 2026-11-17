const path = require('path');
const {getDefaultConfig, mergeConfig} = require('@react-native/metro-config');

// The SDK is a local package (file:../../react-native). Watch its sources, and resolve its
// imports (react-native, react) from this app so there is only one copy of React Native.
const sdk = path.resolve(__dirname, '../../react-native');
const escape = s => s.replace(/[/\\^$*+?.()|[\]{}]/g, '\\$&');

/**
 * Metro configuration
 * https://reactnative.dev/docs/metro
 *
 * @type {import('metro-config').MetroConfig}
 */
const config = {
  watchFolders: [sdk],
  resolver: {
    nodeModulesPaths: [path.resolve(__dirname, 'node_modules')],
    blockList: [new RegExp(`^${escape(path.join(sdk, 'node_modules'))}\\/.*$`)],
  },
};

module.exports = mergeConfig(getDefaultConfig(__dirname), config);
