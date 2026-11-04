const crypto = require("crypto");
// Finds the Redis REST credentials whatever prefix the Vercel integration used.
const pick = (re) => {
  const k = Object.keys(process.env).find((k) => re.test(k) && !/READ_ONLY/.test(k));
  return k ? process.env[k] : undefined;
};
const U = pick(/(KV_REST_API_URL|UPSTASH_REDIS_REST_URL)$/);
const T = pick(/(KV_REST_API_TOKEN|UPSTASH_REDIS_REST_TOKEN)$/);
// Admin password: ADMIN_PASSWORD in Vercel, or "Ficko" if it is not set.
const PW = (process.env.ADMIN_PASSWORD || "Ficko").trim();
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
  const a = Buffer.from(String(req.headers["x-admin-password"] || "").trim().toLowerCase());
  const b = Buffer.from(PW.toLowerCase());
  return a.length === b.length && crypto.timingSafeEqual(a, b);
};
const s = (v, n = 200) => String(v ?? "").trim().slice(0, n);
// Admin operations shared by orders and tickets (hash `key`).
const admin = async (req, res, key, ST) => {
  const b = req.body || {};
  if (req.method === "GET") {
    const a = (await rd(["HGETALL", key])) || [];
    const out = [];
    for (let i = 1; i < a.length; i += 2) out.push(JSON.parse(a[i]));
    out.sort((x, y) => y.ts - x.ts);
    return res.status(200).json(out);
  }
  if (req.method === "PATCH") {
    if (!ST.includes(b.status)) return res.status(400).json({ error: "Invalid status" });
    const v = await rd(["HGET", key, s(b.no, 40)]);
    if (!v) return res.status(404).json({ error: "Not found" });
    const o = JSON.parse(v);
    o.status = b.status;
    await rd(["HSET", key, o.no, JSON.stringify(o)]);
    return res.status(200).json({ ok: true });
  }
  if (req.method === "DELETE") {
    await rd(["HDEL", key, s(b.no, 40)]);
    return res.status(200).json({ ok: true });
  }
  return res.status(405).json({ error: "Method not allowed" });
};
module.exports = { crypto, U, T, rd, isAdmin, s, RULES, admin };
