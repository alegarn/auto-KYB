// For more info, see https://github.com/storybookjs/eslint-plugin-storybook#configuration-flat-config-format

module.exports = [
  {
    ignores: [
      'node_modules',
      'node_modules/',
      'public',
      'public/assets',
      'log',
      '*.log',
      'tmp',
      'vendor',
      'db/schema.rb',
      'app/assets',
      'app/frontend/routes/index.js',
      'app/frontend/routes/index.d.ts',
      'dist',
      'build',
      'coverage',
      '*.min.js',
      '.env*',
      '.vscode/',
      '.idea/',
      '.DS_Store',
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
    languageOptions: {
      parser: require('svelte-eslint-parser'),
      parserOptions: {
        extraFileExtensions: ['.svelte'],
        parser: require('@typescript-eslint/parser'),
        ecmaVersion: 2021,
        sourceType: 'module',
        project: ['./tsconfig.json', './tsconfig.node.json']
      }
    },
    plugins: {
      svelte: require('eslint-plugin-svelte')
    },
    rules: {
      'svelte/no-at-html-tags': 'off'
    }
  }
];
