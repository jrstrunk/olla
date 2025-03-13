document.addEventListener("DOMContentLoaded", function () {
  const container = document.querySelector("#tree-grid");
  const resizer1 = document.querySelector("#tree-resizer");
  const resizer2 = document.querySelector("#panel-resizer");

  let isResizing = false;
  let currentResizer = null;
  let initialX = 0;
  let initialFirstWidth = 0;
  let initialMiddleWidth = 0;
  let initialLastWidth = 0;

  function startResize(e, resizer) {
    isResizing = true;
    currentResizer = resizer;
    initialX = e.clientX;

    // Get initial widths
    const gridColumns =
      getComputedStyle(container).gridTemplateColumns.split(" ");
    initialFirstWidth = parseFloat(gridColumns[0]);
    initialMiddleWidth = parseFloat(gridColumns[2]);
    initialLastWidth = parseFloat(gridColumns[4]);

    document.addEventListener("mousemove", resize);
    document.addEventListener("mouseup", stopResize);
  }

  function resize(e) {
    if (!isResizing) return;

    const diff = e.clientX - initialX;
    const gridColumns =
      getComputedStyle(container).gridTemplateColumns.split(" ");

    if (currentResizer === resizer1) {
      // Adjust first and middle columns, keeping last column fixed
      const newFirstWidth = Math.max(0, initialFirstWidth + diff);
      const newMiddleWidth = Math.max(0, initialMiddleWidth - diff);

      container.style.gridTemplateColumns = `
        ${newFirstWidth}px 4px ${newMiddleWidth}px 4px ${initialLastWidth}px
      `;
    } else if (currentResizer === resizer2) {
      // Adjust middle and last columns, keeping first column fixed
      const newMiddleWidth = Math.max(0, initialMiddleWidth + diff);
      const newLastWidth = Math.max(0, initialLastWidth - diff);

      container.style.gridTemplateColumns = `
        ${initialFirstWidth}px 4px ${newMiddleWidth}px 4px ${newLastWidth}px
      `;
    }
  }

  function stopResize() {
    isResizing = false;
    currentResizer = null;

    document.removeEventListener("mousemove", resize);
    document.removeEventListener("mouseup", stopResize);
  }

  // Add event listeners for both resizer columns
  [resizer1, resizer2].forEach((resizer) => {
    resizer.addEventListener("mousedown", (e) => startResize(e, resizer));
  });
});
