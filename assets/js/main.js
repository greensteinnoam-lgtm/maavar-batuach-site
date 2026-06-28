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

  function baseWhatsappUrl(config) {
    const contact = contactConfig(config);
    const href = contact.whatsappUrl || existingHref("[data-whatsapp]");
    return href ? href.split("?")[0] : "";
  }

  function whatsappHref(config, message) {
    const baseUrl = baseWhatsappUrl(config);
    const text = message || contactConfig(config).whatsappMessage || "";
    if (!baseUrl) return "";
    if (!text) return baseUrl;
    return `${baseUrl}?text=${encodeURIComponent(text)}`;
  }

  function formMessage(form) {
    const data = new FormData(form);
    const value = (name) => String(data.get(name) || "").trim();

    return [
      "שלום, אני צריך הצעת מחיר להובלה.",
      `עיר איסוף: ${value("pickup")}`,
      `עיר יעד: ${value("destination")}`,
      `מה מובילים: ${value("items")}`,
      `תאריך רצוי: ${value("date")}`,
      `האם יש מעלית: ${value("elevator")}`,
    ].join("\n");
  }

  function updateContactLinks(config) {
    const contact = contactConfig(config);
    const businessName = config.businessName || "";
    const phoneDisplay = contact.phoneDisplay || "";
    const phoneHref = contact.phoneHref || existingHref("[data-call]");
    const whatsappUrl = whatsappHref(config);
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
    qsa("form[data-lead-form]").forEach((form) => {
      form.addEventListener("submit", (event) => {
        event.preventDefault();
        const href = whatsappHref(config, formMessage(form));
        if (href) window.open(href, "_blank", "noopener");
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
