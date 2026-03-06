export function parseRulepackXml(xml: string): { version: string; rawXml: string } {
  return { version: '0.1', rawXml: xml.trim() };
}
