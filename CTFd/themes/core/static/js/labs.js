(function () {
  "use strict";

  var selectors = {
    openButtons: "[data-labs-open]",
    closeButtons: "[data-labs-close]",
    modal: "#labs-modal",
    backdrop: "#labs-modal-backdrop",
    dragHandle: "[data-labs-drag-handle]",
    launchButton: "#labs-launch-button",
    subtitle: "#labs-modal-subtitle",
    emptyState: "#labs-empty-state",
    loadingState: "#labs-loading-state",
    errorState: "#labs-error-state",
    terminalShell: "#labs-terminal-shell",
    terminalFrame: "#labs-terminal-frame",
    terminalHost: "#labs-terminal-host",
    terminalExpiry: "#labs-terminal-expiry",
    terminalStatus: "#labs-terminal-status"
  };

  var state = {
    isOpen: false,
    isDragging: false,
    dragOffsetX: 0,
    dragOffsetY: 0,
    activeLab: null
  };

  function ready(callback) {
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", callback);
      return;
    }

    callback();
  }

  function find(selector) {
    return document.querySelector(selector);
  }

  function findAll(selector) {
    return Array.prototype.slice.call(document.querySelectorAll(selector));
  }

  function setHidden(element, hidden) {
    if (!element) {
      return;
    }

    element.hidden = hidden;
  }

  function setText(element, text) {
    if (!element) {
      return;
    }

    element.textContent = text || "";
  }

  function centerModal(modal) {
    var width = modal.offsetWidth || Math.min(960, window.innerWidth - 32);
    var height = modal.offsetHeight || Math.min(680, window.innerHeight - 32);
    var left = Math.max(16, (window.innerWidth - width) / 2);
    var top = Math.max(16, (window.innerHeight - height) / 2);

    modal.style.left = left + "px";
    modal.style.top = top + "px";
  }

  function constrainModal(modal) {
    var rect = modal.getBoundingClientRect();
    var left = Math.min(Math.max(rect.left, 8), Math.max(8, window.innerWidth - 80));
    var top = Math.min(Math.max(rect.top, 8), Math.max(8, window.innerHeight - 80));

    modal.style.left = left + "px";
    modal.style.top = top + "px";
  }

  function openModal() {
    var modal = find(selectors.modal);
    var backdrop = find(selectors.backdrop);

    if (!modal) {
      return;
    }

    setHidden(backdrop, false);
    setHidden(modal, false);
    document.body.classList.add("labs-modal-open");

    if (!state.isOpen) {
      centerModal(modal);
    }

    state.isOpen = true;

    var launchButton = find(selectors.launchButton);
    if (launchButton) {
      launchButton.focus();
    }
  }

  function closeModal() {
    var modal = find(selectors.modal);
    var backdrop = find(selectors.backdrop);

    setHidden(backdrop, true);
    setHidden(modal, true);
    document.body.classList.remove("labs-modal-open");
    state.isOpen = false;
  }

  function showIdle() {
    setHidden(find(selectors.emptyState), false);
    setHidden(find(selectors.loadingState), true);
    setHidden(find(selectors.errorState), true);
    setHidden(find(selectors.terminalShell), true);
    setText(find(selectors.subtitle), "Temporary Linux workspace");

    var launchButton = find(selectors.launchButton);
    if (launchButton) {
      launchButton.disabled = false;
      launchButton.textContent = "Launch Lab";
    }
  }

  function showLoading() {
    setHidden(find(selectors.emptyState), true);
    setHidden(find(selectors.loadingState), false);
    setHidden(find(selectors.errorState), true);
    setHidden(find(selectors.terminalShell), true);
    setText(find(selectors.subtitle), "Provisioning lab environment");

    var launchButton = find(selectors.launchButton);
    if (launchButton) {
      launchButton.disabled = true;
      launchButton.textContent = "Launching...";
    }
  }

  function showError(message) {
    var errorState = find(selectors.errorState);

    setHidden(find(selectors.emptyState), true);
    setHidden(find(selectors.loadingState), true);
    setHidden(find(selectors.terminalShell), true);
    setHidden(errorState, false);
    setText(errorState, message);
    setText(find(selectors.subtitle), "Unable to launch lab");

    var launchButton = find(selectors.launchButton);
    if (launchButton) {
      launchButton.disabled = false;
      launchButton.textContent = "Try Again";
    }
  }

  function showTerminal(lab) {
    var frame = find(selectors.terminalFrame);
    var terminalStatus = find(selectors.terminalStatus);

    state.activeLab = lab;

    setHidden(find(selectors.emptyState), true);
    setHidden(find(selectors.loadingState), true);
    setHidden(find(selectors.errorState), true);
    setHidden(find(selectors.terminalShell), false);

    setText(find(selectors.subtitle), "Lab " + (lab.ctid || "") + " is ready");
    setText(find(selectors.terminalHost), lab.ip_address ? lab.ip_address + ":7681" : "Terminal");
    setText(find(selectors.terminalExpiry), lab.expires_in ? "Expires in " + lab.expires_in : "");
    setText(terminalStatus, "Connected");

    if (frame && lab.terminal_url && frame.src !== lab.terminal_url) {
      frame.src = lab.terminal_url;
    }

    var launchButton = find(selectors.launchButton);
    if (launchButton) {
      launchButton.disabled = false;
      launchButton.textContent = "Reconnect";
    }
  }

  function parseSpawnResponse(response) {
    if (!response.ok) {
      throw new Error("The lab service returned HTTP " + response.status + ".");
    }

    return response.json();
  }

  function validateLabPayload(payload) {
    if (!payload || !payload.terminal_url) {
      throw new Error("The lab service did not return a terminal URL.");
    }

    return payload;
  }

  function launchLab() {
    showLoading();

    return fetch("/spawn", {
      method: "GET",
      credentials: "same-origin",
      headers: {
        Accept: "application/json"
      }
    })
      .then(parseSpawnResponse)
      .then(validateLabPayload)
      .then(showTerminal)
      .catch(function (error) {
        showError(error.message || "Unable to launch lab. Please try again.");
      });
  }

  function beginDrag(event) {
    var modal = find(selectors.modal);
    var target = event.target;

    if (!modal || target.closest("button, a, input, iframe")) {
      return;
    }

    var rect = modal.getBoundingClientRect();
    state.isDragging = true;
    state.dragOffsetX = event.clientX - rect.left;
    state.dragOffsetY = event.clientY - rect.top;

    modal.classList.add("is-dragging");
    document.body.classList.add("labs-dragging");
    event.preventDefault();
  }

  function drag(event) {
    var modal = find(selectors.modal);

    if (!state.isDragging || !modal) {
      return;
    }

    var nextLeft = event.clientX - state.dragOffsetX;
    var nextTop = event.clientY - state.dragOffsetY;

    modal.style.left = nextLeft + "px";
    modal.style.top = nextTop + "px";
    constrainModal(modal);
  }

  function endDrag() {
    var modal = find(selectors.modal);

    state.isDragging = false;
    document.body.classList.remove("labs-dragging");

    if (modal) {
      modal.classList.remove("is-dragging");
    }
  }

  function bindEvents() {
    var launchButton = find(selectors.launchButton);
    var dragHandle = find(selectors.dragHandle);

    findAll(selectors.openButtons).forEach(function (button) {
      button.addEventListener("click", openModal);
    });

    findAll(selectors.closeButtons).forEach(function (button) {
      button.addEventListener("click", closeModal);
    });

    if (launchButton) {
      launchButton.addEventListener("click", launchLab);
    }

    if (dragHandle) {
      dragHandle.addEventListener("mousedown", beginDrag);
    }

    document.addEventListener("mousemove", drag);
    document.addEventListener("mouseup", endDrag);
    document.addEventListener("keydown", function (event) {
      if (event.key === "Escape" && state.isOpen) {
        closeModal();
      }
    });

    window.addEventListener("resize", function () {
      var modal = find(selectors.modal);
      if (modal && state.isOpen) {
        constrainModal(modal);
      }
    });
  }

  ready(function () {
    bindEvents();
    showIdle();
  });
})();
