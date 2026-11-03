const crypto = require("crypto");
const CAT = require("./catalog.json");
const U = process.env.UPSTASH_REDIS_REST_URL || process.env.KV_REST_API_URL;
const T = process.env.UPSTASH_REDIS_REST_TOKEN || process.env.KV_REST_API_TOKEN;
const ST = ["New", "Processing", "Shipped", "Completed", "Cancelled"];
const PAY = ["Bank card", "Bank transfer", "Cash on delivery"];
const rd = async (cmd) => {
  const r = await fetch(U, { method: "POST", headers: { Authorization: "Bearer " + T }, body: JSON.stringify(cmd) });
  const j = await r.json();
  if (j.error) throw new Error(j.error);
  return j.result;
};
const isAdmin = (req) => {
  const a = Buffer.from(String(req.headers["x-admin-password"] || ""));
  const b = Buffer.from(process.env.ADMIN_PASSWORD || "");
  return b.length > 0 && a.length === b.length && crypto.timingSafeEqual(a, b);
};
const s = (v, n = 200) => String(v ?? "").trim().slice(0, n);

module.exports = async (req, res) => {
  try {
    if (!U || !T) return res.status(500).json({ error: "Storage not configured" });
    const body = req.body || {};

    if (req.method === "POST") {
      const c = body.customer || {};
      const customer = {};
      for (const k of ["name", "email", "phone", "country", "zip", "city", "address", "note"]) customer[k] = s(c[k], k === "note" ? 500 : 200);
      if (!customer.name || !/^\S+@\S+\.\S+$/.test(customer.email) || !customer.address) return res.status(400).json({ error: "Invalid customer data" });
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

    if (!isAdmin(req)) return res.status(401).json({ error: "Unauthorized" });

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
