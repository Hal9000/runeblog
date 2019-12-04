  function callout(d, id, src) {
     var js, fjs = d.getElementsByTagName('script')[0];
     p=/^http:/.test(d.location)?'http':'https';
     if (d.getElementById(id)) {return;}
     js = d.createElement('script'); 
     js.id = id;
     js.src = p + src;
     fjs.parentNode.insertBefore(js, fjs);
  }

