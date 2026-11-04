const { crypto, U, T, rd, isAdmin, s, RULES, admin } = require("./_lib");
const CAT = require("./catalog.json");
const ST = ["New", "Processing", "Shipped", "Completed", "Cancelled"];
const PAY = ["Bank card", "Bank transfer", "Cash on delivery"];

module.exports = async (req, res) => {
  try {
    if (req.method === "GET" && req.query && req.query.status)
      return res.status(200).json({
        v: 3,
        storage: !!(U && T),
        customPassword: !!process.env.ADMIN_PASSWORD,
        vars: Object.keys(process.env).filter((k) => /KV_|UPSTASH|REDIS/.test(k)),
      });
    if (req.method !== "POST" && !isAdmin(req)) return res.status(401).json({ error: "Unauthorized" });
    if (!U || !T) return res.status(500).json({ error: "Storage not configured" });

    if (req.method === "POST") {
      const body = req.body || {};
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
    return admin(req, res, "orders", ST);
  } catch (e) {
    return res.status(500).json({ error: "Server error" });
  }
};

