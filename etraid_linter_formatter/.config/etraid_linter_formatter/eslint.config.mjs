import js from '@eslint/js';
import globals from 'globals';
import pluginReact from 'eslint-plugin-react';
import stylistic from '@stylistic/eslint-plugin';
import { defineConfig } from 'eslint/config';
import jsdoc from 'eslint-plugin-jsdoc';

export default defineConfig([
  {
    files: ['**/*.{js,mjs,cjs,ts,mts,cts,jsx,tsx}'],
    plugins: { js, '@stylistic': stylistic, pluginReact, jsdoc },
    extends: ['js/recommended'],
    languageOptions: { globals: { ...globals.browser, ...globals.node, ...globals.meteor } },
    settings: {
      'import/resolver': {
        meteor: {},
      },
      react: {
        version: 'detect', // Automatically detect the react version
      },
    },
  },
  pluginReact.configs.flat.recommended,
  {
    rules: {
      // Avoid showing error for unused variables that start with an underscore
      'no-unused-vars': [
        'error',
        {
          varsIgnorePattern: '^_',
          argsIgnorePattern: '^_',
          caughtErrorsIgnorePattern: '^_',
          destructuredArrayIgnorePattern: '^_',
        },
      ],
      // Stylistic: https://eslint.style/rules
      '@stylistic/arrow-parens': ['error', 'always'],
      '@stylistic/quotes': ['error', 'single', { avoidEscape: true }],
      '@stylistic/no-multiple-empty-lines': ['error', { max: 1, maxEOF: 0 }],
      '@stylistic/lines-between-class-members': ['error', 'always'],
      '@stylistic/no-trailing-spaces': 'error',
      '@stylistic/linebreak-style': ['error', 'unix'],
      '@stylistic/max-len': [
        'warn',
        {
          code: 120,
          tabWidth: 2,
          ignoreComments: true,
          ignoreUrls: false,
          ignoreStrings: true,
          ignoreTemplateLiterals: true,
          ignoreRegExpLiterals: false,
        },
      ],

      // ImportPlugin: https://github.com/import-js/eslint-plugin-import
      'import/extensions': ['off', 'never'],
      'import/no-extraneous-dependencies': 'off',
      'import/prefer-default-export': 'off',

      // React: https://github.com/jsx-eslint/eslint-plugin-react?tab=readme-ov-file#list-of-supported-rules
      'react/prop-types': 'off',
      // Turn on for better debugging features
      'react/display-name': 'off',
      'react/jsx-filename-extension': [
        1,
        {
          extensions: ['.js', '.jsx', '.ts', '.tsx'],
        },
      ],
      'react/jsx-props-no-spreading': 'off',
      'react/no-did-mount-set-state': 'off',
      'react/function-component-definition': 'off',
      'react/react-in-jsx-scope': 'off',
      // 'react/react-in-jsx-scope': 'off',
      'react/jsx-uses-react': 'error',

      // JSDoc: https://github.com/gajus/eslint-plugin-jsdoc
      // The recommended rules are shown in the extends on the top of the file
      'jsdoc/check-tag-names': [
        'error',
        {
          definedTags: ['category', 'subcategory', 'api', 'optionalParam'],
        },
      ],
      'jsdoc/require-example': 'off',
      'jsdoc/require-param': 'error',
      'jsdoc/require-returns': 'off',

      // Eslint: https://eslint.org/docs/latest/rules
      'no-underscore-dangle': 'off',
      'no-param-reassign': [
        'error',
        {
          props: false,
        },
      ],
    },
  },
]);
