(function () {
  const config = {
    businessName: "מעבר בטוח",
    phoneDisplay: "050-000-0000",
    phoneHref: "0500000000",
    whatsappNumber: "972500000000",
    email: "leads@example.com",
    defaultMessage:
      "שלום, אני צריך הצעת מחיר להובלה. עיר איסוף: __ עיר יעד: __ מה מובילים: __ תאריך רצוי: __",
  };

  const qs = (selector, root = document) => root.querySelector(selector);
  const qsa = (selector, root = document) => Array.from(root.querySelectorAll(selector));

  function whatsappUrl(message) {
    return `https://wa.me/${config.whatsappNumber}?text=${encodeURIComponent(message || config.defaultMessage)}`;
  }

  function updateContactLinks() {
    qsa("[data-business-name]").forEach((node) => {
      node.textContent = config.businessName;
    });

    qsa("[data-phone-text]").forEach((node) => {
      node.textContent = config.phoneDisplay;
    });

    qsa("[data-call]").forEach((link) => {
      link.setAttribute("href", `tel:${config.phoneHref}`);
    });

    qsa("[data-whatsapp]").forEach((link) => {
      link.setAttribute("href", whatsappUrl(link.dataset.whatsappMessage));
      link.setAttribute("target", "_blank");
      link.setAttribute("rel", "noopener");
    });

    qsa("[data-email]").forEach((link) => {
      link.setAttribute("href", `mailto:${config.email}`);
      link.textContent = config.email;
    });
  }

  function formMessage(form) {
    const data = new FormData(form);
    const parts = [
      "שלום, אני צריך הצעת מחיר להובלה.",
      `שם: ${data.get("name") || ""}`,
      `טלפון: ${data.get("phone") || ""}`,
      `עיר איסוף: ${data.get("pickup") || ""}`,
      `עיר יעד: ${data.get("destination") || ""}`,
      `מה מובילים: ${data.get("items") || ""}`,
      `תאריך רצוי: ${data.get("date") || ""}`,
      `יש מעלית: ${data.get("elevator") || ""}`,
      `צריך פירוק והרכבה: ${data.get("assembly") || ""}`,
    ];

    return parts.join("\n");
  }

  function bindForms() {
    qsa("form[data-lead-form]").forEach((form) => {
      form.addEventListener("submit", (event) => {
        event.preventDefault();
        window.open(whatsappUrl(formMessage(form)), "_blank", "noopener");
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

  updateContactLinks();
  bindForms();
  bindMenu();
})();
