// Loads web/images/manifest.json and replaces any <img data-img="section.key"> src
(async function(){
  try{
    const res = await fetch('images/manifest.json');
    if(!res.ok) throw new Error('manifest not found');
    const manifest = await res.json();
    function lookup(key){
      const parts = key.split('.');
      let obj = manifest;
      for(const p of parts){ if(obj && p in obj) obj = obj[p]; else return null }
      return obj;
    }
    document.querySelectorAll('img[data-img]').forEach(img=>{
      const key = img.getAttribute('data-img');
      const file = lookup(key);
      if(typeof file === 'string') img.src = 'images/' + file;
    });
  }catch(e){ console.warn('manifest-loader error', e) }
})();
