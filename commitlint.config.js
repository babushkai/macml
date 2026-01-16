// Commitlint configuration for MacML
// Enforces conventional commit format: type(scope): description
// https://www.conventionalcommits.org/

module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    // Type must be one of these values
    'type-enum': [
      2, // Error level
      'always',
      [
        'feat',     // New feature
        'fix',      // Bug fix
        'docs',     // Documentation only
        'style',    // Code style (formatting, semicolons, etc.)
        'refactor', // Code refactoring (no feature/fix)
        'perf',     // Performance improvement
        'test',     // Adding/updating tests
        'build',    // Build system or dependencies
        'ci',       // CI configuration
        'chore',    // Other changes (maintenance)
        'revert',   // Revert a previous commit
        'breaking', // Breaking change (triggers major version)
      ],
    ],
    // Type must be lowercase
    'type-case': [2, 'always', 'lower-case'],
    // Type cannot be empty
    'type-empty': [2, 'never'],
    // Scope must be lowercase (optional)
    'scope-case': [2, 'always', 'lower-case'],
    // Subject cannot be empty
    'subject-empty': [2, 'never'],
    // Subject case - disabled (conventional commits don't require lowercase)
    'subject-case': [0],
    // No period at end of subject
    'subject-full-stop': [2, 'never', '.'],
    // Header max length (type + scope + subject)
    'header-max-length': [2, 'always', 100],
    // Body max line length
    'body-max-line-length': [1, 'always', 200], // Warning only
  },
  // Help message shown on failure
  helpUrl: 'https://www.conventionalcommits.org/',
};
