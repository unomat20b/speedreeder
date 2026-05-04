/**
 * Извлечение текста PDF через PDF.js (аналогично офлайн-конвертерам в браузере).
 * Вход: base64 строка (надёжная передача из Dart web). Выход: JSON { "pages": [...] }.
 */
import * as pdfjsLib from './pdfjs/pdf.min.mjs';

pdfjsLib.GlobalWorkerOptions.workerSrc = new URL(
  './pdfjs/pdf.worker.min.mjs',
  import.meta.url,
).href;

globalThis.__speedreederExtractPdfJson = async (b64) => {
  const binary = atob(b64);
  const len = binary.length;
  const data = new Uint8Array(len);
  for (let i = 0; i < len; i++) {
    data[i] = binary.charCodeAt(i);
  }
  const loadingTask = pdfjsLib.getDocument({ data, useSystemFonts: true });
  const pdf = await loadingTask.promise;
  try {
    const pages = [];
    const n = pdf.numPages;
    for (let p = 1; p <= n; p++) {
      const page = await pdf.getPage(p);
      const tc = await page.getTextContent();
      const line = tc.items
        .map((item) => (item && typeof item.str === 'string' ? item.str : ''))
        .join(' ')
        .replace(/\s+/g, ' ')
        .trim();
      pages.push(line);
    }
    return JSON.stringify({ pages });
  } finally {
    try {
      await pdf.cleanup();
    } catch (_) {
      /* ignore */
    }
    try {
      loadingTask.destroy();
    } catch (_) {
      /* ignore */
    }
  }
};
