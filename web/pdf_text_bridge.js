/**
 * Извлечение текста PDF через classic PDF.js.
 * Не используем ES modules/.mjs: на некоторых хостингах .mjs отдаётся с MIME,
 * который браузер блокирует для module scripts.
 */
(function () {
  const pdfjsLib = globalThis.pdfjsLib;
  if (!pdfjsLib) {
    console.error('PDF.js is not loaded: pdfjsLib is missing');
    return;
  }

  const scriptUrl = document.currentScript
    ? document.currentScript.src
    : document.baseURI;
  pdfjsLib.GlobalWorkerOptions.workerSrc = new URL(
    './pdfjs/pdf.worker.min.js',
    scriptUrl,
  ).href;

  globalThis.__speedreederExtractPdfJson = async function (b64) {
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
      for (let p = 1; p <= pdf.numPages; p++) {
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
        // ignore
      }
      try {
        loadingTask.destroy();
      } catch (_) {
        // ignore
      }
    }
  };
})();
