(function () {
  function toDatasetKey(key) {
    return "sort" + key.charAt(0).toUpperCase() + key.slice(1);
  }

  function normalizeText(value) {
    return String(value || "").trim().toLowerCase();
  }

  function normalizeNumber(value) {
    var parsed = Number(String(value || "").replace(/,/g, ""));
    return isNaN(parsed) ? Number.NEGATIVE_INFINITY : parsed;
  }

  function updateSortState(buttons, activeButton, direction) {
    buttons.forEach(function (button) {
      var isActive = button === activeButton;
      button.classList.toggle("is-active", isActive);
      button.classList.toggle("asc", isActive && direction === "asc");
      button.classList.toggle("desc", isActive && direction === "desc");
      button.setAttribute("aria-sort", isActive ? (direction === "asc" ? "ascending" : "descending") : "none");
    });
  }

  function sortRows(tbody, rows, key, type, direction) {
    var dataKey = toDatasetKey(key);
    var factor = direction === "asc" ? 1 : -1;
    var sortedRows = rows.slice().sort(function (left, right) {
      var leftValue = left.element.dataset[dataKey];
      var rightValue = right.element.dataset[dataKey];
      var compared;

      if (type === "number") {
        compared = normalizeNumber(leftValue) - normalizeNumber(rightValue);
      } else {
        compared = normalizeText(leftValue).localeCompare(normalizeText(rightValue));
      }

      if (compared === 0) {
        return left.index - right.index;
      }

      return compared * factor;
    });

    sortedRows.forEach(function (row) {
      tbody.appendChild(row.element);
    });
  }

  function initTable(table) {
    var tbody = table.querySelector("tbody");
    var buttons = Array.from(table.querySelectorAll(".sort-button"));

    if (!tbody || buttons.length === 0) {
      return;
    }

    var rows = Array.from(tbody.querySelectorAll("tr")).map(function (row, index) {
      return { element: row, index: index };
    });

    buttons.forEach(function (button) {
      button.addEventListener("click", function () {
        var key = button.dataset.sortKey;
        var type = button.dataset.sortType || "text";
        var direction = button.classList.contains("is-active") && button.classList.contains("asc") ? "desc" : "asc";

        sortRows(tbody, rows, key, type, direction);
        updateSortState(buttons, button, direction);
      });
    });
  }

  function blankZeroFields() {
    var el = document.getElementById("sfndcustno");
    if (el && el.value.trim() === "0") {
      el.value = "";
    }
  }

  function init() {
    blankZeroFields();
    Array.from(document.querySelectorAll("[data-sortable-table]")).forEach(initTable);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
}());
