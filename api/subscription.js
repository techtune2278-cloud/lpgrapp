'use strict';
const {readFileSync}=require('node:fs');const {join}=require('node:path');const data=require('../dist/content.json');
const legalText=readFileSync(join(__dirname,'../dist/assets/documents/cgv-et-retractation.txt'),'utf8');
const {createSubscriptionService}=require('../lib/subscription-service');const handle=createSubscriptionService({catalog:data.books,config:data.subscription,legalText});
module.exports=async(req,res)=>{const result=await handle({method:req.method,headers:req.headers,body:req.body,ip:req.headers['x-vercel-forwarded-for']||req.socket?.remoteAddress||''});for(const [key,value] of Object.entries(result.headers))res.setHeader(key,value);return res.status(result.status).json(result.data);};
