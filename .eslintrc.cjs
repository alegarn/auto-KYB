module.exports = {
  root: true,
  parser: '@typescript-eslint/parser',
  plugins: ['@typescript-eslint', 'svelte', 'import'],
  extends: [
    'eslint:recommended',
    'plugin:@typescript-eslint/recommended',
    'plugin:import/errors',
    'plugin:import/warnings',
    'plugin:import/typescript',
    'plugin:svelte/recommended',
    'prettier'
  ],
  env: {
    browser: true,
    node: true,
    es2021: true
  },
  settings: {
    'import/resolver': {
      typescript: {
        project: './tsconfig.json'
      }
    }
  },
  overrides: [
    {
      files: ['*.svelte'],
      processor: 'svelte/svelte'
    },
    {
      files: ['**/*.ts', '**/*.js'],
      parserOptions: {
        project: ['./tsconfig.json', './tsconfig.node.json']
      }
    }
  ],
  rules: {
    'no-unused-vars': 'off',
    '@typescript-eslint/no-unused-vars': ['warn', {argsIgnorePattern: '^_' }],
    'import/no-unresolved': 'off'
  }
};
