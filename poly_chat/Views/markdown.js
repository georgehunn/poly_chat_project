(function () {
  "use strict";

  const root = document.getElementById("markdown-root");
const rawMarkdown = window.__MARKDOWN_CONTENT__ || "";

function normalizeMathDelimiters(text) {
  return text
    .replace(/\\\[(.*?)\\\]/gs, (_, expr) => `$$${expr}$$`)
    .replace(/\\\((.*?)\\\)/gs, (_, expr) => `$${expr}$`);
}

const markdown = normalizeMathDelimiters(rawMarkdown)
  .replace(/\$\\s+/g, '$')
  .replace(/\\s+\$/g, '$');

  function reportHeight() {
    if (!window.webkit?.messageHandlers?.heightChange) return;

    const root = document.getElementById("markdown-root");
    if (!root) return;

    const rect = root.getBoundingClientRect();
    const height = Math.ceil(rect.height);

    window.webkit.messageHandlers.heightChange.postMessage(Math.max(height, 1));
   }

  window.__reportHeight = reportHeight;

  function configureMarked() {
    if (typeof marked === "undefined") {
      throw new Error("marked.js not loaded");
    }

    marked.setOptions({
      gfm: true,
      breaks: true,
      headerIds: false,
      mangle: false
    });
  }

  function renderMarkdown() {
    configureMarked();
    root.innerHTML = marked.parse(markdown);
  }

  function enhanceTables() {
    const tables = Array.from(root.querySelectorAll("table"));
    tables.forEach((table) => {
      if (table.parentElement?.classList.contains("table-scroll")) return;
      const wrapper = document.createElement("div");
      wrapper.className = "table-scroll";
      table.parentNode.insertBefore(wrapper, table);
      wrapper.appendChild(table);
    });
  }

  function enhanceCodeBlocks() {
    const blocks = Array.from(root.querySelectorAll("pre"));

    blocks.forEach((pre) => {
      if (!pre.parentElement?.classList.contains("code-block")) {
        const wrapper = document.createElement("div");
        wrapper.className = "code-block";
        pre.parentNode.insertBefore(wrapper, pre);
        wrapper.appendChild(pre);

        const button = document.createElement("button");
        button.className = "code-copy";
        button.type = "button";
        button.textContent = "Copy";

        button.addEventListener("click", async () => {
          const codeText = pre.innerText;
          try {
            if (navigator.clipboard?.writeText) {
              await navigator.clipboard.writeText(codeText);
            } else {
              const range = document.createRange();
              range.selectNodeContents(pre);
              const selection = window.getSelection();
              selection.removeAllRanges();
              selection.addRange(range);
              document.execCommand("copy");
              selection.removeAllRanges();
            }
            const original = button.textContent;
            button.textContent = "Copied";
            setTimeout(() => {
              button.textContent = original;
            }, 1200);
          } catch (_) {
            button.textContent = "Failed";
            setTimeout(() => {
              button.textContent = "Copy";
            }, 1200);
          }
          reportHeight();
        });

        wrapper.appendChild(button);
      }

      const code = pre.querySelector("code");
      if (code && window.hljs && hljs.highlightElement) {
        try {
          hljs.highlightElement(code);
        } catch (_) {}
      }
    });
  }

  function enhanceLinks() {
    const links = Array.from(root.querySelectorAll("a[href]"));
    links.forEach((link) => {
      link.setAttribute("target", "_blank");
      link.setAttribute("rel", "noopener noreferrer");
    });
  }

  function processMath() {
    if (!window.MathJax || !MathJax.typesetPromise) {
        root.insertAdjacentHTML("beforeend", "<pre style='color:orange'>MATHJAX NOT LOADED</pre>");
        return Promise.resolve();
    }

    try {
        return MathJax.typesetPromise([root]).catch((e) => {
        root.insertAdjacentHTML("beforeend", "<pre style='color:orange'>MATHJAX ERROR: " + e + "</pre>");
        });
    } catch (e) {
        root.insertAdjacentHTML("beforeend", "<pre style='color:orange'>MATHJAX THROW: " + e + "</pre>");
        return Promise.resolve();
    }
 }

  function installObservers() {
    if ("ResizeObserver" in window) {
      const resizeObserver = new ResizeObserver(() => {
        requestAnimationFrame(reportHeight);
      });
      resizeObserver.observe(document.body);
      resizeObserver.observe(root);
    }

    window.addEventListener("load", () => {
      setTimeout(reportHeight, 0);
      setTimeout(reportHeight, 100);
      setTimeout(reportHeight, 300);
    });

    window.addEventListener("resize", () => {
      requestAnimationFrame(reportHeight);
    });
  }

  async function init() {
    if (!root) return;

    try {
      renderMarkdown();
    } catch (e) {
      root.innerHTML = "<pre style='color:red'>RENDER ERROR: " + e + "</pre>";
      reportHeight();
      return;
    }

    try {
      enhanceTables();
    } catch (_) {}

    try {
      enhanceCodeBlocks();
    } catch (_) {}

    try {
      enhanceLinks();
    } catch (_) {}

    try {
      await processMath();
    } catch (_) {}

    requestAnimationFrame(() => {
      reportHeight();
      setTimeout(reportHeight, 60);
      setTimeout(reportHeight, 180);
    });

    installObservers();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();