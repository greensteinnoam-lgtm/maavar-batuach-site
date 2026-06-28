(function () {
  const script = document.currentScript;
  const qs = (selector, root = document) => root.querySelector(selector);
  const qsa = (selector, root = document) => Array.from(root.querySelectorAll(selector));

  function configUrl() {
    if (!script || !script.src) return "site.config.json";
    return new URL("../../site.config.json", script.src).href;
  }

  async function loadConfig() {
    try {
      const response = await fetch(configUrl(), { cache: "no-cache" });
      if (!response.ok) throw new Error("Config request failed");
      return response.json();
    } catch (error) {
      return {};
    }
  }

  function contactConfig(config) {
    return config.contact || {};
  }

  function existingHref(selector) {
    const link = qs(selector);
    return link ? link.getAttribute("href") || "" : "";
  }

  function updateContactLinks(config) {
    const contact = contactConfig(config);
    const businessName = config.businessName || "";
    const phoneDisplay = contact.phoneDisplay || "";
    const phoneHref = contact.phoneHref || existingHref("[data-call]");
    const whatsappUrl = contact.whatsappUrl || existingHref("[data-whatsapp]");
    const email = contact.email || "";

    if (businessName) {
      qsa("[data-business-name]").forEach((node) => {
        node.textContent = businessName;
      });
    }

    if (phoneDisplay) {
      qsa("[data-phone-text]").forEach((node) => {
        node.textContent = phoneDisplay;
      });
    }

    if (phoneHref) {
      qsa("[data-call]").forEach((link) => {
        link.setAttribute("href", phoneHref);
      });
    }

    if (whatsappUrl) {
      qsa("[data-whatsapp]").forEach((link) => {
        link.setAttribute("href", whatsappUrl);
        link.setAttribute("target", "_blank");
        link.setAttribute("rel", "noopener");
      });
    }

    qsa("[data-email]").forEach((link) => {
      if (!email) {
        link.remove();
        return;
      }

      link.setAttribute("href", `mailto:${email}`);
      link.textContent = email;
    });
  }

  function bindForms(config) {
    const whatsappUrl = contactConfig(config).whatsappUrl || existingHref("[data-whatsapp]");
    qsa("form[data-lead-form]").forEach((form) => {
      form.addEventListener("submit", (event) => {
        event.preventDefault();
        if (whatsappUrl) window.open(whatsappUrl, "_blank", "noopener");
      });
    });
  }

  function bindMenu() {
    const toggle = qs("[data-menu-toggle]");
    const nav = qs("#site-nav");
    if (!toggle || !nav) return;

    toggle.addEventListener("click", () => {
      const expanded = toggle.getAttribute("aria-expanded") === "true";
      toggle.setAttribute("aria-expanded", String(!expanded));
      document.body.classList.toggle("menu-open", !expanded);
    });

    qsa("a", nav).forEach((link) => {
      link.addEventListener("click", () => {
        document.body.classList.remove("menu-open");
        toggle.setAttribute("aria-expanded", "false");
      });
    });
  }

  bindMenu();
  loadConfig().then((config) => {
    updateContactLinks(config);
    bindForms(config);
  });
})();
