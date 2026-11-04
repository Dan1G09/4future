const { crypto, U, T, rd, isAdmin, s, RULES, admin } = require("./_lib");
const ST = ["Open", "In progress", "Resolved"];
const TOPICS = ["Order", "Payment", "Product question", "Business / bulk enquiry", "Other"];

module.exports = async (req, res) => {
  try {
    if (req.method !== "POST" && !isAdmin(req)) return res.status(401).json({ error: "Unauthorized" });
    if (!U || !T) return res.status(500).json({ error: "Storage not configured" });
    if (req.method === "POST") {
      const b = req.body || {};
      const t = { name: s(b.name), email: s(b.email), phone: s(b.phone), topic: s(b.topic), order: s(b.order, 20), message: s(b.message, 2000) };
      if (!RULES.name(t.name) || !RULES.email(t.email) || (t.phone && !RULES.phone(t.phone)) || !TOPICS.includes(t.topic) ||
          t.message.length < 10 || (t.order && !/^4F-[A-Z0-9]{4,12}$/i.test(t.order)))
        return res.status(400).json({ error: "Invalid data" });
      const no = "S-" + Date.now().toString(36).toUpperCase().slice(-5) + crypto.randomBytes(2).toString("hex").toUpperCase();
      await rd(["HSET", "tickets", no, JSON.stringify({ no, ts: Date.now(), status: "Open", ...t })]);
      return res.status(200).json({ no });
    }
    return admin(req, res, "tickets", ST);
  } catch (e) {
    return res.status(500).json({ error: "Server error" });
  }
};
