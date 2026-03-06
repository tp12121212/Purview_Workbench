export const unsupportedConstructs = [
  { test: (pattern: string) => pattern.includes('(?<='), description: 'Lookbehind is not allowed.' },
  { test: (pattern: string) => pattern.includes('\\K'), description: '\\K token is not allowed.' },
] as const;
