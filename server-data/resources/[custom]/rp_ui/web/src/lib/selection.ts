// Keep text editing intact. Do not cancel dragstart: inventory slots use HTML drag/drop.
export function installSelectionGuard() {
  document.addEventListener(
    "keydown",
    (event) => {
      if (!(event.ctrlKey || event.metaKey) || event.key.toLowerCase() !== "a")
        return;
      const target = event.target;
      if (
        target instanceof HTMLTextAreaElement ||
        (target instanceof HTMLElement && target.isContentEditable)
      )
        return;
      if (
        target instanceof HTMLInputElement &&
        [
          "text",
          "search",
          "email",
          "url",
          "tel",
          "password",
          "number",
        ].includes(target.type)
      )
        return;
      event.preventDefault();
      window.getSelection()?.removeAllRanges();
    },
    true,
  );
}
