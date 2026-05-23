(function () {
  const cfg = window.OpenFlowSiteConfig || {};
  const i18n = window.OpenFlowI18n;
  let locale = i18n ? i18n.detect() : "zh";
  const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  function docsUrlForLocale(loc) {
    if (loc === "en" && cfg.docsEnUrl) return cfg.docsEnUrl;
    return cfg.docsUrl;
  }

  function gettingStartedForLocale(loc) {
    if (loc === "en" && cfg.gettingStartedEnUrl) return cfg.gettingStartedEnUrl;
    return cfg.gettingStartedUrl;
  }

  function operatorsForLocale(loc) {
    if (loc === "en" && cfg.operatorsEnUrl) return cfg.operatorsEnUrl;
    return cfg.operatorsUrl;
  }

  function applyLinks() {
    const links = {
      docs: docsUrlForLocale(locale),
      "getting-started": gettingStartedForLocale(locale),
      operators: operatorsForLocale(locale),
      "getting-started-index": cfg.gettingStartedIndexUrl,
      releases: cfg.releasesUrl,
      repo: cfg.repoUrl,
      login: cfg.appUrl || "#start",
    };

    document.querySelectorAll("[data-link]").forEach((el) => {
      const key = el.getAttribute("data-link");
      const href = links[key];
      if (!href) return;
      el.setAttribute("href", href);
      if (href.startsWith("http")) {
        el.setAttribute("target", "_blank");
        el.setAttribute("rel", "noopener noreferrer");
      } else {
        el.removeAttribute("target");
        el.removeAttribute("rel");
      }
    });
  }

  function applyDemoButton() {
    if (!i18n) return;
    const label = document.querySelector("#hero-cta-demo [data-i18n='hero.cta.demo']");
    if (label) {
      label.textContent = i18n.t(
        locale,
        cfg.demoVideoUrl ? "hero.cta.demoVideo" : "hero.cta.demo"
      );
    }
  }

  function bindLoginFallback() {
    if (cfg.appUrl) return;
    [document.getElementById("nav-login"), document.getElementById("start-web-login")].forEach(
      (el) => {
        if (!el) return;
        el.addEventListener("click", (e) => {
          if (el.getAttribute("href") === "#start") {
            e.preventDefault();
            document.getElementById("start")?.scrollIntoView({ behavior: "smooth" });
          }
        });
      }
    );
  }

  function setLocale(next) {
    locale = next;
    if (i18n) i18n.apply(locale);
    applyLinks();
    applyDemoButton();
    updateMenuAria();
  }

  function updateMenuAria() {
    const toggle = document.getElementById("nav-toggle");
    if (!toggle || !i18n) return;
    const open = document.querySelector(".site-header")?.classList.contains("is-open");
    toggle.setAttribute(
      "aria-label",
      i18n.t(locale, open ? "nav.menuClose" : "nav.menuOpen")
    );
  }

  function markRevealed(el) {
    el.classList.add("is-visible");
    if (!el.classList.contains("reveal")) {
      el.style.opacity = "";
      el.style.transform = "";
      el.style.transition = "";
    }
    if (el.classList.contains("stat-card")) {
      animateStatCard(el);
    }
  }

  function revealInView(el, margin = 80) {
    const r = el.getBoundingClientRect();
    const h = window.innerHeight || document.documentElement.clientHeight;
    if (r.top < h - margin && r.bottom > margin) {
      markRevealed(el);
      return true;
    }
    return false;
  }

  function revealSectionById(id) {
    const section = document.getElementById(id);
    if (!section) return;
    section.querySelectorAll(".reveal, .start-path, .start-verify, .pricing-tier").forEach(markRevealed);
  }

  function initReveal() {
    const targets = document.querySelectorAll(
      ".reveal, .feature-card, .workflow-step, .start-path, .start-verify, .stat-card, .pricing-tier, .pricing-compare, .cta-band .container > *"
    );

    if (prefersReducedMotion) {
      targets.forEach((el) => markRevealed(el));
      return;
    }

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          markRevealed(entry.target);
          observer.unobserve(entry.target);
        });
      },
      { threshold: 0.08, rootMargin: "0px 0px 0px 0px" }
    );

    targets.forEach((el) => {
      if (!el.classList.contains("reveal")) {
        el.style.opacity = "0";
        el.style.transform = "translateY(20px)";
        el.style.transition = "opacity 0.55s ease, transform 0.55s ease";
      }
      if (!revealInView(el)) {
        observer.observe(el);
      }
    });

    // 锚点跳转（#start / #pricing）时立即展示该区块，避免只看到空卡片壳
    const revealFromHash = () => {
      const id = (location.hash || "").replace(/^#/, "");
      if (id === "start" || id === "pricing") {
        revealSectionById(id);
      }
    };
    revealFromHash();
    window.addEventListener("hashchange", revealFromHash);
    document.querySelectorAll('a[href^="#"]').forEach((link) => {
      link.addEventListener("click", () => {
        const id = (link.getAttribute("href") || "").replace(/^#/, "");
        if (id === "start" || id === "pricing") {
          requestAnimationFrame(() => revealSectionById(id));
        }
      });
    });
  }

  function animateStatCard(card) {
    if (prefersReducedMotion) return;
    const valueEl = card.querySelector(".stat-value");
    if (!valueEl) return;
    if (valueEl.hasAttribute("data-count-static")) return;

    const target = Number(valueEl.getAttribute("data-count"));
    const suffix = valueEl.getAttribute("data-suffix") || "";
    if (!Number.isFinite(target)) return;

    const duration = 1200;
    const start = performance.now();

    function tick(now) {
      const t = Math.min(1, (now - start) / duration);
      const eased = 1 - (1 - t) ** 3;
      const current = Math.round(target * eased);
      valueEl.textContent = `${current}${suffix}`;
      if (t < 1) requestAnimationFrame(tick);
    }

    requestAnimationFrame(tick);
  }

  function initHeaderScroll() {
    const header = document.querySelector(".site-header");
    if (!header) return;

    const onScroll = () => {
      header.classList.toggle("is-scrolled", window.scrollY > 24);
    };
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
  }

  function initDemoModal() {
    const modal = document.getElementById("demo-modal");
    const slidesRoot = document.getElementById("demo-modal-slides");
    const dotsRoot = document.getElementById("demo-modal-dots");
    const videoWrap = document.getElementById("demo-modal-video");
    const closeBtn = document.getElementById("demo-modal-close");
    const prevBtn = document.getElementById("demo-prev");
    const nextBtn = document.getElementById("demo-next");
    if (!modal || !slidesRoot) return;

    const slides = Array.isArray(cfg.demoSlides) ? cfg.demoSlides : [];
    let index = 0;
    let autoplayTimer = null;

    function t(key) {
      return i18n ? i18n.t(locale, key) : key;
    }

    function renderSlides() {
      slidesRoot.innerHTML = "";
      dotsRoot.innerHTML = "";
      slides.forEach((slide, i) => {
        const panel = document.createElement("div");
        panel.className = `demo-modal__slide${i === 0 ? " is-active" : ""}`;
        const img = document.createElement("img");
        img.src = slide.src;
        img.alt = t(slide.captionKey);
        img.loading = i === 0 ? "eager" : "lazy";
        const cap = document.createElement("span");
        cap.className = "demo-modal__caption";
        cap.setAttribute("data-caption-key", slide.captionKey);
        cap.textContent = t(slide.captionKey);
        panel.append(img, cap);
        slidesRoot.appendChild(panel);

        const dot = document.createElement("button");
        dot.type = "button";
        dot.className = `demo-modal__dot${i === 0 ? " is-active" : ""}`;
        dot.setAttribute("aria-label", t(slide.captionKey));
        dot.addEventListener("click", () => goTo(i));
        dotsRoot.appendChild(dot);
      });
    }

    function goTo(next) {
      if (!slides.length) return;
      index = (next + slides.length) % slides.length;
      slidesRoot.querySelectorAll(".demo-modal__slide").forEach((el, i) => {
        el.classList.toggle("is-active", i === index);
      });
      dotsRoot.querySelectorAll(".demo-modal__dot").forEach((el, i) => {
        el.classList.toggle("is-active", i === index);
      });
    }

    function stopAutoplay() {
      if (autoplayTimer) clearInterval(autoplayTimer);
      autoplayTimer = null;
    }

    function startAutoplay() {
      stopAutoplay();
      if (prefersReducedMotion || slides.length < 2) return;
      autoplayTimer = setInterval(() => goTo(index + 1), 4500);
    }

    function openModal() {
      if (cfg.demoVideoUrl && videoWrap) {
        videoWrap.hidden = false;
        slidesRoot.hidden = true;
        dotsRoot.parentElement.style.visibility = "hidden";
        videoWrap.innerHTML = `<iframe class="demo-modal__video" src="${cfg.demoVideoUrl}" title="${t("demo.title")}" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>`;
      } else {
        if (!slidesRoot.childElementCount) renderSlides();
        videoWrap.hidden = true;
        slidesRoot.hidden = false;
        if (dotsRoot.parentElement) dotsRoot.parentElement.style.visibility = "";
        index = 0;
        goTo(0);
        startAutoplay();
      }
      modal.hidden = false;
      modal.classList.add("is-open");
      document.body.style.overflow = "hidden";
      closeBtn?.focus();
    }

    function closeModal() {
      modal.classList.remove("is-open");
      modal.hidden = true;
      document.body.style.overflow = "";
      stopAutoplay();
      if (videoWrap) {
        videoWrap.innerHTML = "";
        videoWrap.hidden = true;
      }
      slidesRoot.hidden = false;
      if (dotsRoot.parentElement) dotsRoot.parentElement.style.visibility = "";
    }

    renderSlides();

    ["hero-cta-demo", "mobile-cta-demo"].forEach((id) => {
      document.getElementById(id)?.addEventListener("click", openModal);
    });
    closeBtn?.addEventListener("click", closeModal);
    modal.addEventListener("click", (e) => {
      if (e.target === modal) closeModal();
    });
    prevBtn?.addEventListener("click", () => goTo(index - 1));
    nextBtn?.addEventListener("click", () => goTo(index + 1));
    document.addEventListener("keydown", (e) => {
      if (!modal.classList.contains("is-open")) return;
      if (e.key === "Escape") closeModal();
      if (!cfg.demoVideoUrl && e.key === "ArrowLeft") goTo(index - 1);
      if (!cfg.demoVideoUrl && e.key === "ArrowRight") goTo(index + 1);
    });

    document.addEventListener("openflow:locale", () => {
      slidesRoot.querySelectorAll("[data-caption-key]").forEach((cap) => {
        cap.textContent = t(cap.getAttribute("data-caption-key"));
      });
    });
  }

  function initMobileCta() {
    const bar = document.getElementById("mobile-cta-bar");
    const hero = document.querySelector(".hero");
    if (!bar || !hero) return;

    if (window.matchMedia("(max-width: 900px)").matches) {
      document.body.classList.add("has-mobile-cta");
    }

    const observer = new IntersectionObserver(
      ([entry]) => {
        bar.classList.toggle("is-visible", !entry.isIntersecting);
      },
      { threshold: 0, rootMargin: "0px 0px -20% 0px" }
    );
    observer.observe(hero);
  }

  function initNav() {
    const toggle = document.getElementById("nav-toggle");
    const header = document.querySelector(".site-header");
    if (!toggle || !header) return;

    toggle.addEventListener("click", () => {
      header.classList.toggle("is-open");
      toggle.setAttribute("aria-expanded", header.classList.contains("is-open") ? "true" : "false");
      updateMenuAria();
    });

    header.querySelectorAll(".nav-main a, .nav-actions a, .nav-actions button").forEach((el) => {
      el.addEventListener("click", () => {
        if (el.id === "lang-toggle") return;
        header.classList.remove("is-open");
        toggle.setAttribute("aria-expanded", "false");
        updateMenuAria();
      });
    });
  }

  if (i18n) {
    i18n.apply(locale);
    const langBtn = document.getElementById("lang-toggle");
    if (langBtn) {
      langBtn.addEventListener("click", () => {
        setLocale(locale === "zh" ? "en" : "zh");
      });
    }
  }

  applyLinks();
  applyDemoButton();
  bindLoginFallback();
  initReveal();
  initHeaderScroll();
  initNav();
  initDemoModal();
  initMobileCta();
})();
