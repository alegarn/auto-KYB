module.exports = [
  {
    ignores: [
      'node_modules',
      'public',
      'log',
      'tmp',
      'vendor',
      'db/schema.rb',
      'app/assets',
      'dist',
      '.git'
    ]
  },
  {
    files: ['**/*.{js,ts}'],
    languageOptions: {
      parser: require('@typescript-eslint/parser'),
      parserOptions: {
        ecmaVersion: 2021,
        sourceType: 'module',
        project: ['./tsconfig.json', './tsconfig.node.json']
      }
    },
    plugins: {
      '@typescript-eslint': require('@typescript-eslint/eslint-plugin'),
      import: require('eslint-plugin-import')
    },
    settings: {
      'import/resolver': {
        typescript: {
          project: './tsconfig.json'
        }
      }
    },
    rules: {
      'no-unused-vars': 'off',
      '@typescript-eslint/no-unused-vars': ['warn', { argsIgnorePattern: '^_' }],
      'import/no-unresolved': 'off'
    }
  },
  {
    files: ['**/*.svelte'],
    plugins: {
      svelte: require('eslint-plugin-svelte')
    },
    processor: 'svelte/svelte'
  }
];
