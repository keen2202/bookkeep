/** @type {import('jest').Config} */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/tests'],
  testMatch: ['**/*.test.ts'],
  // 审查 R-021：默认 npm test 排除集成用例（需真实 PG / bookkeep_test 独立库）；
  // 集成套件经 test:integration 显式执行（--testPathIgnorePatterns /node_modules/ 覆盖本项）
  testPathIgnorePatterns: ['/tests/.*\\.integration\\.test\\.ts$'],
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
