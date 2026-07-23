(function () {
  "use strict";

  var storageKey = "wowtranSearchTheme";
  var modes = ["auto", "light", "dark"];
  var labels = {
    auto: "自动",
    light: "浅色",
    dark: "深色"
  };
  var symbols = {
    auto: "◐",
    light: "☀",
    dark: "☾"
  };

  function readMode() {
    try {
      var stored = localStorage.getItem(storageKey);
      if (modes.indexOf(stored) !== -1) return stored;
    } catch (error) {
      // Storage can be blocked in hardened browsers; auto remains safe.
    }
    return "auto";
  }

  function setDocumentMode(mode) {
    if (modes.indexOf(mode) === -1) mode = "auto";

    var root = document.documentElement;
    root.classList.remove("theme-auto", "theme-light", "theme-dark", "theme-black");
    root.classList.add("theme-" + mode);
    root.setAttribute("data-theme-mode", mode);
  }

  function updateControls(mode) {
    var trigger = document.getElementById("sxng-theme-trigger");
    if (trigger) {
      var symbol = trigger.querySelector(".sxng-theme-symbol");
      var label = trigger.querySelector(".sxng-theme-label");
      if (symbol) symbol.textContent = symbols[mode];
      if (label) label.textContent = labels[mode];
      trigger.setAttribute("aria-label", "主题颜色：" + labels[mode]);
      trigger.setAttribute("title", "主题颜色：" + labels[mode]);
    }

    document.querySelectorAll("[data-theme-mode-option]").forEach(function (option) {
      option.setAttribute(
        "aria-selected",
        option.getAttribute("data-theme-mode-option") === mode ? "true" : "false"
      );
    });
  }

  function applyMode(mode, persist) {
    if (modes.indexOf(mode) === -1) mode = "auto";

    if (persist) {
      try {
        localStorage.setItem(storageKey, mode);
      } catch (error) {
        // The selected mode still applies for this page view.
      }
    }

    setDocumentMode(mode);
    updateControls(mode);
  }

  function closeMenu() {
    var trigger = document.getElementById("sxng-theme-trigger");
    var menu = document.getElementById("sxng-theme-menu");
    if (!trigger || !menu) return;
    menu.hidden = true;
    trigger.setAttribute("aria-expanded", "false");
  }

  function on(target, eventName, handler) {
    if (target.addEventListener) {
      target.addEventListener(eventName, handler);
    } else {
      target["on" + eventName] = handler;
    }
  }

  window.wowtranThemeToggle = function (event) {
    var trigger = document.getElementById("sxng-theme-trigger");
    var menu = document.getElementById("sxng-theme-menu");
    if (!trigger || !menu) return false;
    if (event && event.stopPropagation) event.stopPropagation();
    var willOpen = menu.hidden;
    menu.hidden = !willOpen;
    trigger.setAttribute("aria-expanded", willOpen ? "true" : "false");
    return false;
  };

  window.wowtranThemeSelect = function (mode, event) {
    if (event && event.stopPropagation) event.stopPropagation();
    applyMode(mode, true);
    closeMenu();
    var trigger = document.getElementById("sxng-theme-trigger");
    if (trigger && trigger.focus) trigger.focus();
    return false;
  };

  function initialize() {
    var trigger = document.getElementById("sxng-theme-trigger");
    var menu = document.getElementById("sxng-theme-menu");
    if (!trigger || !menu) return;

    applyMode(readMode(), false);

    on(document, "click", function (event) {
      if (!event.target.closest(".sxng-theme-switcher")) closeMenu();
    });

    on(document, "keydown", function (event) {
      if (event.key === "Escape") {
        closeMenu();
        trigger.focus();
      }
    });

    var media = window.matchMedia("(prefers-color-scheme: dark)");
    var syncAutoLabel = function () {
      if (readMode() === "auto") updateControls("auto");
    };
    if (media.addEventListener) media.addEventListener("change", syncAutoLabel);
    else if (media.addListener) media.addListener(syncAutoLabel);
  }

  if (document.readyState === "loading") {
    on(document, "DOMContentLoaded", initialize);
  } else {
    initialize();
  }
})();
