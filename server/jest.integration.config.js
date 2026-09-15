/** @type {import('jest').Config} */
const base = require('./jest.config');

// Spec 验收门禁：集成套件需真实 PG，与单测默认排除策略相反。
// 独立配置避免 CLI 覆盖 testMatch/testPathIgnorePatterns 在 Windows 上的解析问题。
module.exports = {
  ...base,
  testMatch: ['**/*.integration.test.ts'],
  testPathIgnorePatterns: ['/node_modules/'],
};
