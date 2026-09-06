// ESLint 10 flat config — backend hiluxOS.
// Rules kept loose: the codebase predates linting; we gate on real bugs
// (unused vars, no-undef in tests) without reformatting existing style.
const js = require('@eslint/js');
const tseslint = require('typescript-eslint');

module.exports = tseslint.config(
  { ignores: ['dist/**', 'node_modules/**', 'coverage/**', 'prisma/seed.js'] },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    files: ['src/**/*.ts'],
    rules: {
      '@typescript-eslint/no-explicit-any': 'off', // Nest DTOs / Prisma results
      '@typescript-eslint/no-unsafe-function-type': 'off',
    },
  },
  {
    files: ['test/**/*.ts', 'src/**/*.spec.ts'],
    rules: {
      '@typescript-eslint/no-unsafe-function-type': 'off',
      '@typescript-eslint/no-explicit-any': 'off',
      '@typescript-eslint/no-unused-vars': 'off', // jest.mock hoisting patterns
      '@typescript-eslint/no-require-imports': 'off', // inline require() in specs (jest.mock hoisting)
    },
  },
);