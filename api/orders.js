const crypto = require("crypto");
const CAT = require("./catalog.json");
const U = process.env.UPSTASH_REDIS_REST_URL || process.env.KV_REST_API_URL;
const T = process.env.UPSTASH_REDIS_REST_TOKEN || process.env.KV_REST_API_TOKEN;
// Admin password: set ADMIN_PASSWORD in Vercel. Falls back to "mokus" if it is not set.
const PW = (process.env.ADMIN_PASSWORD || "mokus").trim();
const ST = ["New", "Processing", "Shipped", "Completed", "Cancelled"];
const PAY = ["Bank card", "Bank transfer", "Cash on delivery"];
const NM = /^[\p{L}][\p{L} .'’\-]{1,79}$/u;
const RULES = {
  name: (v) => NM.test(v) && /\s/.test(v),
  email: (v) => /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(v),
  phone: (v) => /^\+?\d{7,15}$/.test(v),
  country: (v) => NM.test(v),
  zip: (v) => /^[A-Za-z0-9][A-Za-z0-9 \-]{2,9}$/.test(v),
  city: (v) => NM.test(v),
  address: (v) => /^(?=.*\p{L})(?=.*\d).{5,120}$/u.test(v),
};
const rd = async (cmd) => {
  const r = await fetch(U, { method: "POST", headers: { Authorization: "Bearer " + T }, body: JSON.stringify(cmd) });
  const j = await r.json();
  if (j.error) throw new Error(j.error);
  return j.result;
};
const isAdmin = (req) => {
  const a = Buffer.from(String(req.headers["x-admin-password"] || "").trim());
  const b = Buffer.from(PW);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
};
const s = (v, n = 200) => String(v ?? "").trim().slice(0, n);

module.exports = async (req, res) => {
  try {
    const body = req.body || {};
    if (req.method !== "POST" && !isAdmin(req)) return res.status(401).json({ error: "Unauthorized" });
    if (!U || !T) return res.status(500).json({ error: "Storage not configured" });

    if (req.method === "POST") {
      const c = body.customer || {};
      const customer = {};
      for (const k of Object.keys(RULES)) {
        customer[k] = s(c[k]);
        if (!RULES[k](customer[k])) return res.status(400).json({ error: "Invalid " + k });
      }
      customer.note = s(c.note, 500);
      if (!PAY.includes(body.pay)) return res.status(400).json({ error: "Invalid payment method" });
      if (!Array.isArray(body.items) || !body.items.length || body.items.length > 50) return res.status(400).json({ error: "Invalid items" });
      const items = [];
      for (const i of body.items) {
        const p = CAT[i.id], q = Number(i.q);
        if (!p || !Number.isInteger(q) || q < 1 || q > 99) return res.status(400).json({ error: "Invalid item" });
        items.push({ id: i.id, n: p.n, p: p.p, q });
      }
      const card = body.pay === "Bank card" && body.card && /^\d{4}$/.test(String(body.card.last4))
        ? { brand: s(body.card.brand, 20), last4: String(body.card.last4) } : null;
      const no = "4F-" + Date.now().toString(36).toUpperCase().slice(-5) + crypto.randomBytes(2).toString("hex").toUpperCase();
      const total = items.reduce((t, i) => t + i.p * i.q, 0);
      await rd(["HSET", "orders", no, JSON.stringify({ no, ts: Date.now(), customer, pay: body.pay, card, status: "New", total, items })]);
      return res.status(200).json({ no, total });
    }
    if (req.method === "GET") {
      const a = (await rd(["HGETALL", "orders"])) || [];
      const out = [];
      for (let i = 1; i < a.length; i += 2) out.push(JSON.parse(a[i]));
      out.sort((x, y) => y.ts - x.ts);
      return res.status(200).json(out);
    }
    if (req.method === "PATCH") {
      if (!ST.includes(body.status)) return res.status(400).json({ error: "Invalid status" });
      const v = await rd(["HGET", "orders", s(body.no, 40)]);
      if (!v) return res.status(404).json({ error: "Not found" });
      const o = JSON.parse(v);
      o.status = body.status;
      await rd(["HSET", "orders", o.no, JSON.stringify(o)]);
      return res.status(200).json({ ok: true });
    }
    if (req.method === "DELETE") {
      await rd(["HDEL", "orders", s(body.no, 40)]);
      return res.status(200).json({ ok: true });
    }
    return res.status(405).json({ error: "Method not allowed" });
  } catch (e) {
    return res.status(500).json({ error: "Server error" });
  }
};
