export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [2, 'always', [
      'feat', 'fix', 'docs', 'style', 'refactor',
      'perf', 'test', 'chore', 'ci', 'build', 'revert',
    ]],
    'subject-case': [0],
    'header-max-length': [2, 'always', 80],
    'trailer-exists': [2, 'never', 'Co-authored-by'],
  },
};
