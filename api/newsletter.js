'use strict';
const {createNewsletterService}=require('../lib/newsletter-service');
const handle=createNewsletterService();
module.exports=async(req,res)=>{const result=await handle({method:req.method,headers:req.headers,body:req.body,ip:req.headers['x-vercel-forwarded-for']||req.socket?.remoteAddress||''});for(const [k,v] of Object.entries(result.headers))res.setHeader(k,v);return res.status(result.status).json(result.data);};
