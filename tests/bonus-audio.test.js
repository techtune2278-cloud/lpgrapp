const test=require('node:test'),assert=require('node:assert/strict');
const {validateSection}=require('../lib/content-validation');
const row={slug:'moliere',author:'Molière',title:'Lecture',type:'audio',url:'/audio/orthographe-moliere.mp3'};
test('Audio local, anciens liens audio et vidéos externes restent publiables',()=>{
 for(const bonus of [row,{...row,url:'/audio/lecture%20Moli%C3%A8re.mp3'},{...row,url:'https://example.org/ancienne-page'},{...row,type:'video',url:'https://www.ina.fr/ina-eclaire-actu/video/abc'}]){
  assert.deepEqual(validateSection('bonuses',[bonus]),[bonus]);
 }
});
test('Les bonus refusent chemins hors audio, fichiers non audio et schémas dangereux',()=>{
 for(const url of ['/audio/../private.mp3','/audio/%2e%2e%2fprivate.mp3','/audio/test.mp3?x=1','/assets/test.mp3','/audio/test.html','javascript:alert(1)','//evil.test/test.mp3','/audio/bad%00.mp3']){
  assert.throws(()=>validateSection('bonuses',[{...row,url}]));
 }
 assert.throws(()=>validateSection('bonuses',[{...row,type:'video'}]));
 assert.throws(()=>validateSection('bonuses',[{...row,url:'https://user:password@example.org/'}]));
});
