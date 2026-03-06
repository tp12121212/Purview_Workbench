import { unsupportedConstructs } from './unsupported-constructs';

export function checkBoostRegexCompat(pattern: string): { compatible: boolean; issues: string[] } {
  const issues = unsupportedConstructs.filter((item) => item.test(pattern));
  return { compatible: issues.length === 0, issues: issues.map((item) => item.description) };
}
