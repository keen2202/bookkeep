/** @type {import('jest').Config} */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/tests'],
  testMatch: ['**/*.test.ts'],
  collectCoverageFrom: ['src/**/*.ts'],
  coverageThreshold: {
    global: {
      lines: 80,
      statements: 80,
      functions: 80,
      branches: 80,
    },
  },
  verbose: true,
};
