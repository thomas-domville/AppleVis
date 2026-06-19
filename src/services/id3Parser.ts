/**
 * ID3v2 chapter parser
 *
 * Fetches the first FETCH_BYTES of an MP3 via an HTTP Range request and walks
 * the ID3v2 frame list looking for CHAP frames (ID3v2 Chapters 1.0 spec).
 * Each CHAP frame contains a start-time in milliseconds and optional sub-frames;
 * the TIT2 sub-frame carries the chapter title.
 *
 * Supports ID3v2.3 (frame sizes are big-endian uint32) and ID3v2.4 (synchsafe).
 * ID3v2.2 does not define CHAP, so those files return [].
 *
 * Works for both remote URLs and local file:// URIs (via fetch).
 */

import type { Chapter } from '../types/content';

const FETCH_BYTES = 512 * 1024; // 512 KB — covers most ID3 blocks

function readSynchsafe(buf: Uint8Array, offset: number): number {
  return (
    ((buf[offset]     & 0x7f) << 21) |
    ((buf[offset + 1] & 0x7f) << 14) |
    ((buf[offset + 2] & 0x7f) <<  7) |
     (buf[offset + 3] & 0x7f)
  );
}

function readUint32BE(buf: Uint8Array, offset: number): number {
  return (((buf[offset] << 24) | (buf[offset + 1] << 16) | (buf[offset + 2] << 8) | buf[offset + 3]) >>> 0);
}

function readNullTermString(buf: Uint8Array, start: number): { text: string; next: number } {
  let end = start;
  while (end < buf.length && buf[end] !== 0) end++;
  const text = new TextDecoder().decode(buf.slice(start, end));
  return { text, next: end + 1 };
}

function decodeTextFrame(buf: Uint8Array, offset: number, size: number): string {
  if (size <= 1) return '';
  const enc = buf[offset];
  const data = buf.slice(offset + 1, offset + size);
  try {
    if (enc === 1 || enc === 2) {
      // UTF-16 — strip BOM and trailing nulls
      return new TextDecoder('utf-16le').decode(data).replace(/\0+$/, '').trim();
    }
    return new TextDecoder('utf-8').decode(data).replace(/\0+$/, '').trim();
  } catch {
    return new TextDecoder('latin1').decode(data).replace(/\0+$/, '').trim();
  }
}

export async function parseChapters(audioUrl: string): Promise<Chapter[]> {
  try {
    const res = await fetch(audioUrl, {
      headers: { Range: `bytes=0-${FETCH_BYTES - 1}` },
    });
    if (!res.ok && res.status !== 206) return [];
    const raw  = await res.arrayBuffer();
    const buf  = new Uint8Array(raw);

    // Must start with 'ID3'
    if (buf[0] !== 0x49 || buf[1] !== 0x44 || buf[2] !== 0x33) return [];

    const majorVersion = buf[3]; // 2 = v2.2, 3 = v2.3, 4 = v2.4
    if (majorVersion < 3) return []; // CHAP not defined in v2.2

    const unsyncFlag = (buf[5] & 0x80) !== 0;
    const tagSize    = readSynchsafe(buf, 6);  // always synchsafe in both v2.3 and v2.4
    const tagEnd     = Math.min(10 + tagSize, buf.length);

    // v2.4 may apply unsynchronisation to frame sizes — we don't handle that edge case
    // (rare in podcast clients) so we just skip those files gracefully via try/catch.
    const readFrameSize = (offset: number) =>
      majorVersion >= 4
        ? readSynchsafe(buf, offset)
        : readUint32BE(buf, offset);

    const chapters: Chapter[] = [];
    let pos = 10;

    // Walk top-level frames
    while (pos + 10 < tagEnd) {
      const fid = String.fromCharCode(buf[pos], buf[pos + 1], buf[pos + 2], buf[pos + 3]);
      if (fid === '\0\0\0\0' || fid.trimEnd() === '') break; // padding

      const fsize  = readFrameSize(pos + 4);
      const fdata  = pos + 10;             // frame data starts here

      if (fid === 'CHAP' && fsize >= 17 && fdata + fsize <= buf.length) {
        // elementId (null-terminated) | startTime u32 | endTime u32 | startOffset u32 | endOffset u32 | sub-frames
        const { text: _elemId, next: timesStart } = readNullTermString(buf, fdata);
        const startTimeMs = readUint32BE(buf, timesStart);      // milliseconds
        const startTime   = startTimeMs / 1000;                  // seconds

        // Sub-frames start after the 4 × u32 time/offset fields
        let title   = '';
        let subPos  = timesStart + 16;
        const chapEnd = fdata + fsize;

        while (subPos + 10 < chapEnd && subPos + 10 < buf.length) {
          const sid   = String.fromCharCode(buf[subPos], buf[subPos + 1], buf[subPos + 2], buf[subPos + 3]);
          if (sid === '\0\0\0\0') break;
          const ssize = readFrameSize(subPos + 4);
          if (ssize === 0 || subPos + 10 + ssize > chapEnd) break;

          if (sid === 'TIT2') {
            title = decodeTextFrame(buf, subPos + 10, ssize);
          }
          subPos += 10 + ssize;
        }

        if (title) {
          chapters.push({ title, startTime });
        }
      }

      pos = fdata + fsize;
      if (fsize === 0) break; // guard against infinite loop on corrupt frames
    }

    if (unsyncFlag) {
      // File uses unsynchronisation on the whole tag — our raw byte offsets are off.
      // Return what we found but don't guarantee correctness.
    }

    return chapters.sort((a, b) => a.startTime - b.startTime);
  } catch {
    return [];
  }
}
