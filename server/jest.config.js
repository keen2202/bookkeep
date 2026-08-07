/** @type {import('jest').Config} */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/tests'],
  testMatch: ['**/*.test.ts'],
  // 审查 R-021：config 为全量套件（单元+集成）；单元运行（npm test）经脚本
  // --testPathIgnorePatterns 排除集成（无 DB 可跑）；test:coverage/test:integration 含集成
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
