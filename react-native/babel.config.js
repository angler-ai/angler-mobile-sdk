// Used by Jest only; apps compile this package with Metro's own React Native preset.
module.exports = {
  presets: [['@babel/preset-env', { targets: { node: 'current' } }], '@babel/preset-typescript'],
};
