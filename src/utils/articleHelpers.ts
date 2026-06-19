// Shared utilities for long-form article detail pages (resource, blog).

export function stripHtml(html: string): string {
  return html
    .replace(/<a[^>]*href="([^"]*)"[^>]*>(.*?)<\/a>/gis, (_, href, inner) => {
      const t = inner.replace(/<[^>]*>/g, '').trim();
      return t ? `${t} (${href})` : href;
    })
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p>/gi, '\n\n')
    .replace(/<\/li>/gi, '\n')
    .replace(/<\/h[1-6]>/gi, '\n\n')
    .replace(/<[^>]*>/g, '')
    .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"').replace(/&#039;/g, "'").replace(/&apos;/g, "'")
    .replace(/&nbsp;/g, ' ')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

export type BodySegment = { text: string; kind: 'prose' | 'quote' | 'code' };

export function bodySegments(html: string): BodySegment[] {
  const result: BodySegment[] = [];
  const re = /(<pre[^>]*>[\s\S]*?<\/pre>|<blockquote[^>]*>[\s\S]*?<\/blockquote>)/gi;
  let cursor = 0;
  let m: RegExpExecArray | null;

  const pushProse = (raw: string) =>
    stripHtml(raw)
      .split('\n\n')
      .map(p => p.replace(/\n/g, ' ').trim())
      .filter(Boolean)
      .forEach(p => result.push({ text: p, kind: 'prose' }));

  while ((m = re.exec(html)) !== null) {
    pushProse(html.slice(cursor, m.index));
    const block = m[1];
    if (/^<pre/i.test(block)) {
      const code = block
        .replace(/<pre[^>]*>/gi, '').replace(/<\/pre>/gi, '')
        .replace(/<code[^>]*>/gi, '').replace(/<\/code>/gi, '')
        .replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&')
        .replace(/&quot;/g, '"').replace(/&#039;/g, "'").replace(/&apos;/g, "'")
        .replace(/<[^>]*>/g, '').trim();
      if (code) result.push({ text: code, kind: 'code' });
    } else {
      const inner = block.replace(/<\/?blockquote[^>]*>/gi, '');
      const q = stripHtml(inner).replace(/\n+/g, ' ').trim();
      if (q) result.push({ text: q, kind: 'quote' });
    }
    cursor = m.index + m[0].length;
  }
  pushProse(html.slice(cursor));
  return result;
}

export function readingTime(html: string): string {
  const words = stripHtml(html).split(/\s+/).filter(Boolean).length;
  const minutes = Math.max(1, Math.ceil(words / 200));
  return `About a ${minutes} minute read`;
}

export type TocEntry = { id: number; level: 2 | 3; text: string };

export function extractToc(html: string): TocEntry[] {
  const toc: TocEntry[] = [];
  const re = /<h([23])[^>]*>([\s\S]*?)<\/h\1>/gi;
  let m: RegExpExecArray | null;
  let i = 0;
  while ((m = re.exec(html)) !== null) {
    const level = parseInt(m[1], 10) as 2 | 3;
    const text = m[2].replace(/<[^>]*>/g, '').trim();
    if (text) toc.push({ id: i++, level, text });
  }
  return toc;
}

export type ArticleLink = { text: string; href: string };

export function extractLinks(html: string): ArticleLink[] {
  const links: ArticleLink[] = [];
  const seen = new Set<string>();
  const re = /<a[^>]+href="(https?:\/\/[^"]+)"[^>]*>([\s\S]*?)<\/a>/gi;
  let m: RegExpExecArray | null;
  while ((m = re.exec(html)) !== null) {
    const href = m[1];
    const text = m[2].replace(/<[^>]*>/g, '').trim() || href;
    if (!seen.has(href)) {
      seen.add(href);
      links.push({ text, href });
    }
  }
  return links;
}
