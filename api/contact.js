'use strict';
const { createContactService } = require('../lib/contact-service');
const handle = createContactService();

module.exports = async function contact(req, res) {
  const result = await handle({ method: req.method, headers: req.headers, body: req.body, ip: req.headers['x-vercel-forwarded-for'] || req.socket?.remoteAddress || '' });
  for (const [key, value] of Object.entries(result.headers)) res.setHeader(key, value);
  return res.status(result.status).json(result.data);
};
