import type { MetadataRoute } from 'next';

// Search engines may index galleries; AI training crawlers may not.
const aiCrawlers = [
  'GPTBot',
  'ChatGPT-User',
  'CCBot',
  'Google-Extended',
  'anthropic-ai',
  'ClaudeBot',
  'Claude-Web',
  'PerplexityBot',
  'Bytespider',
  'Applebot-Extended',
  'meta-externalagent',
];

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [{ userAgent: '*', allow: '/' }, ...aiCrawlers.map((userAgent) => ({ userAgent, disallow: '/' }))],
  };
}
