---
title: home
description: Start building and innovating with our APIs
---

<style>
.kongair-home {
  --kongair-ink: #172033;
  --kongair-surface: #ffffff;
  --kongair-raised: #fff8ef;
  --kongair-border: #d9e2ec;
  --kongair-border-strong: #b8c4d2;
  --kongair-text: #172033;
  --kongair-muted: #526273;
  --kongair-faint: #728197;
  --kongair-accent: #f28c28;
  --kongair-accent-dark: #9a4f00;
  --kongair-accent-soft: #fff0dc;
  --kongair-green: #137333;
  --kongair-amber: #9a5b00;
  --kongair-blue: #1d5fd0;
  margin: -2rem auto 0;
  color: var(--kongair-text);
  background:
    radial-gradient(circle at 88% 10%, rgba(242,140,40,.18), transparent 34%),
    linear-gradient(180deg, #ffffff 0%, #f7fafc 58%, #eef3f8 100%);
  border: 1px solid #e4ebf2;
  border-radius: 18px;
  overflow: hidden;
}
.kongair-home ::selection { background: #ffe1bd; color: #111827; }
.kongair-home a { color: inherit; text-decoration: none; }
.kongair-home__wrap { max-width: 1180px; margin: 0 auto; padding: 0 32px; }
.kongair-home__hero {
  max-width: 780px;
  padding: 72px 0 56px;
  border-bottom: 1px solid var(--kongair-border);
}
.kongair-home__eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 18px;
  color: var(--kongair-accent);
  font: 600 12px ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  letter-spacing: .08em;
  text-transform: uppercase;
}
.kongair-home__dot { width: 7px; height: 7px; border-radius: 50%; background: var(--kongair-green); box-shadow: 0 0 0 4px rgba(19,115,51,.13); }
.kongair-home h1 { margin: 0 0 18px; font-size: clamp(2.1rem, 4vw, 3.4rem); line-height: 1.08; letter-spacing: -.03em; }
.kongair-home__lede { max-width: 58ch; margin: 0 0 28px; color: var(--kongair-muted); font-size: 1rem; line-height: 1.7; }
.kongair-home__actions { display: flex; gap: 12px; flex-wrap: wrap; align-items: center; }
.kongair-home__button {
  display: inline-block;
  box-sizing: border-box;
  height: 44px;
  min-width: 118px;
  padding-left: 24px;
  padding-right: 24px;
  border-radius: 12px;
  border: 1px solid var(--kongair-border-strong);
  color: var(--kongair-text);
  background: #ffffff;
  font-weight: 700;
  line-height: 42px;
  text-align: center;
  vertical-align: middle;
  white-space: nowrap;
}
.kongair-home__button--primary { min-width: 178px; background: var(--kongair-accent); border-color: var(--kongair-accent); color: #111827; box-shadow: 0 8px 20px rgba(242,140,40,.22); }
.kongair-home__button:hover { border-color: var(--kongair-accent); background: var(--kongair-accent-soft); color: #111827; text-decoration: none; }
.kongair-home__button--primary:hover { background: #ff9f3d; }
.kongair-home__stats { display: flex; gap: 26px; flex-wrap: wrap; margin-top: 26px; color: var(--kongair-faint); font-size: .85rem; }
.kongair-home__stats strong { display: block; color: var(--kongair-text); font: 500 1.35rem ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
.kongair-home__section { padding: 50px 0 62px; }
.kongair-home__section-head { display: flex; justify-content: space-between; gap: 24px; align-items: end; margin-bottom: 22px; }
.kongair-home__section h2 { margin: 0; font-size: 1.65rem; letter-spacing: -.02em; }
.kongair-home__section p { margin: 6px 0 0; color: var(--kongair-muted); }
.kongair-product-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 16px; }
.kongair-product-card {
  display: flex;
  flex-direction: column;
  min-height: 245px;
  gap: 14px;
  padding: 22px;
  border: 1px solid var(--kongair-border);
  border-radius: 13px;
  background: var(--kongair-surface);
  box-shadow: 0 10px 26px rgba(24,39,75,.07);
  transition: transform .16s ease, background .16s ease, border-color .16s ease, box-shadow .16s ease;
}
.kongair-product-card:hover { transform: translateY(-2px); background: var(--kongair-raised); border-color: var(--kongair-accent); box-shadow: 0 16px 36px rgba(24,39,75,.12); }
.kongair-product-card__top { display: flex; justify-content: space-between; align-items: flex-start; gap: 12px; }
.kongair-product-card__title { margin: 0 0 3px; font-weight: 750; font-size: 1.05rem; }
.kongair-product-card__meta { color: var(--kongair-faint); font: 600 11px ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; letter-spacing: .08em; text-transform: uppercase; }
.kongair-pill { border-radius: 999px; padding: 4px 9px; font: 600 10px ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; white-space: nowrap; }
.kongair-pill--stable { color: var(--kongair-green); background: rgba(19,115,51,.10); }
.kongair-pill--beta { color: var(--kongair-amber); background: rgba(154,91,0,.12); }
.kongair-pill--new { color: var(--kongair-blue); background: rgba(29,95,208,.12); }
.kongair-product-card__desc { flex: 1; margin: 0; color: var(--kongair-muted); font-size: .92rem; line-height: 1.6; }
.kongair-product-card__foot { display: flex; justify-content: space-between; align-items: center; gap: 14px; padding-top: 12px; border-top: 1px solid var(--kongair-border); }
.kongair-product-card__version { color: var(--kongair-faint); font: 500 12px ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; }
.kongair-product-card__links { display: flex; gap: 14px; color: var(--kongair-accent-dark); font-weight: 650; font-size: .88rem; }
.kongair-product-card__links a:hover { color: #6f3900; text-decoration: underline; }
.kongair-version-select {
  min-width: 78px;
  height: 32px;
  padding: 0 26px 0 10px;
  border: 1px solid var(--kongair-border-strong);
  border-radius: 999px;
  background: #fff;
  color: var(--kongair-text);
  font: 700 12px ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
}
.kongair-version-select:hover,
.kongair-version-select:focus { border-color: var(--kongair-accent); outline: none; }
.kongair-home__catalog { padding: 36px 0 62px; border-top: 1px solid var(--kongair-border); }
.kongair-home__catalog-box { border: 1px solid var(--kongair-border); border-radius: 14px; padding: 24px; background: rgba(255,255,255,.82); }
@media (max-width: 880px) {
  .kongair-home__wrap { padding: 0 20px; }
  .kongair-home__hero { padding-top: 44px; }
  .kongair-home__section-head { display: block; }
}
</style>

<div class="kongair-home">
  <div class="kongair-home__wrap">
    <section class="kongair-home__hero">
      <div>
        <div class="kongair-home__eyebrow"><span class="kongair-home__dot"></span> KongAir API platform</div>
        <h1>The developer portal for KongAir's flight &amp; booking APIs.</h1>
        <p class="kongair-home__lede">KongAir is a global airline. Build against our published flight schedules and customer booking APIs &mdash; reference docs, onboarding guides, and API key access from a single Kong Developer Portal.</p>
        <div class="kongair-home__actions">
          <a class="kongair-home__button kongair-home__button--primary" href="/apis">Explore API catalog</a>
          <a class="kongair-home__button" href="/getting-started">Get started</a>
        </div>
        <div class="kongair-home__stats">
          <div><strong>2</strong>API products</div>
          <div><strong>REST</strong>OpenAPI</div>
        </div>
      </div>
    </section>
    <section class="kongair-home__section">
      <div class="kongair-home__section-head">
        <div>
          <h2>Featured API products</h2>
          <p>KongAir's REST APIs, reference docs, and access paths for partners and integrators.</p>
        </div>
        <a class="kongair-home__button" href="/apis">View all APIs</a>
      </div>
      <div class="kongair-product-grid">
        <article class="kongair-product-card">
          <div class="kongair-product-card__top">
            <div>
              <h3 class="kongair-product-card__title">Flights API</h3>
              <div class="kongair-product-card__meta">REST · OpenAPI</div>
            </div>
            <span class="kongair-pill kongair-pill--stable">Stable</span>
          </div>
          <p class="kongair-product-card__desc">KongAir's published flight schedule and metadata &mdash; departures, flight lookups, and cabin/aircraft details.</p>
          <div class="kongair-product-card__foot">
            <span class="kongair-product-card__version">v0.1.0</span>
            <span class="kongair-product-card__links"><a href="/apis">Docs</a><a href="/apis">API</a></span>
          </div>
        </article>
        <article class="kongair-product-card">
          <div class="kongair-product-card__top">
            <div>
              <h3 class="kongair-product-card__title">Bookings API</h3>
              <div class="kongair-product-card__meta">REST · OpenAPI</div>
            </div>
            <span class="kongair-pill kongair-pill--stable">Stable</span>
          </div>
          <p class="kongair-product-card__desc">Create and retrieve KongAir customer flight bookings &mdash; digital check-in, travel agency portals, and self-service itinerary changes.</p>
          <div class="kongair-product-card__foot">
            <span class="kongair-product-card__version">v0.1.0</span>
            <span class="kongair-product-card__links"><a href="/apis">Docs</a><a href="/apis">API</a></span>
          </div>
        </article>
      </div>
    </section>
  </div>
</div>

::page-section
---
max-width: "1180px"
---
#title
API catalog

#description
Browse KongAir's published REST APIs and reference documentation.

::apis-list
---
enable-search: true
persist-page-number: true
cta-text: "Documentation"
---
::
::
