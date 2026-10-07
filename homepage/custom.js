// Light/dark toggle, top right of the stats row. Icons are Phosphor sun/moon,
// as in clear-rag, showing the theme you switch TO. See docs/dashboard.md.
// Clicks Homepage's own footer toggle (hidden in custom.css) so its React state
// and the persisted theme-mode key stay in sync; flips the class directly only
// if that toggle is missing.
(() => {
  const svg = (d) =>
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="16" height="16" fill="currentColor" aria-hidden="true"><path d="${d}"/></svg>`;
  const SUN = svg("M120,40V16a8,8,0,0,1,16,0V40a8,8,0,0,1-16,0Zm72,88a64,64,0,1,1-64-64A64.07,64.07,0,0,1,192,128Zm-16,0a48,48,0,1,0-48,48A48.05,48.05,0,0,0,176,128ZM58.34,69.66A8,8,0,0,0,69.66,58.34l-16-16A8,8,0,0,0,42.34,53.66Zm0,116.68-16,16a8,8,0,0,0,11.32,11.32l16-16a8,8,0,0,0-11.32-11.32ZM192,72a8,8,0,0,0,5.66-2.34l16-16a8,8,0,0,0-11.32-11.32l-16,16A8,8,0,0,0,192,72Zm5.66,114.34a8,8,0,0,0-11.32,11.32l16,16a8,8,0,0,0,11.32-11.32ZM48,128a8,8,0,0,0-8-8H16a8,8,0,0,0,0,16H40A8,8,0,0,0,48,128Zm80,80a8,8,0,0,0-8,8v24a8,8,0,0,0,16,0V216A8,8,0,0,0,128,208Zm112-88H216a8,8,0,0,0,0,16h24a8,8,0,0,0,0-16Z");
  const MOON = svg("M233.54,142.23a8,8,0,0,0-8-2,88.08,88.08,0,0,1-109.8-109.8,8,8,0,0,0-10-10,104.84,104.84,0,0,0-52.91,37A104,104,0,0,0,136,224a103.09,103.09,0,0,0,62.52-20.88,104.84,104.84,0,0,0,37-52.91A8,8,0,0,0,233.54,142.23ZM188.9,190.34A88,88,0,0,1,65.66,67.11a89,89,0,0,1,31.4-26A106,106,0,0,0,96,56,104.11,104.11,0,0,0,200,160a106,106,0,0,0,14.92-1.06A89,89,0,0,1,188.9,190.34Z");

  const root = document.documentElement;
  const current = () => (root.classList.contains("light") ? "light" : "dark");

  const button = document.createElement("button");
  button.id = "theme-toggle";
  button.type = "button";

  const render = () => {
    const next = current() === "dark" ? "light" : "dark";
    button.innerHTML = next === "light" ? SUN : MOON;
    button.setAttribute("aria-label", `Switch to ${next} theme`);
    button.title = `Switch to ${next} theme`;
  };

  button.addEventListener("click", () => {
    const native = document.querySelector("#theme svg.cursor-pointer");
    if (native) {
      native.dispatchEvent(new MouseEvent("click", { bubbles: true }));
      return;
    }
    const next = current() === "dark" ? "light" : "dark";
    root.classList.remove(current());
    root.classList.add(next);
    try {
      localStorage.setItem("theme-mode", next);
    } catch {
      // Private windows throw; the toggle still works for this page view.
    }
  });

  // React re-renders the stats row; re-attach whenever the button drops out.
  const mount = () => {
    const row = document.getElementById("information-widgets-right");
    if (row && button.parentElement !== row) row.appendChild(button);
  };

  new MutationObserver(render).observe(root, { attributes: true, attributeFilter: ["class"] });
  new MutationObserver(mount).observe(document.body, { childList: true, subtree: true });
  render();
  mount();
})();
