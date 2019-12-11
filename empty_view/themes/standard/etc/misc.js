<!-- Miscellaneous local JS pieces are defined here -->
.nopara

<script>
  function open_main(url) {
      var site = url+'?toolbar=0&amp;navpanes=0&amp;scrollbar=0';
      document.getElementById('main').src = site;
  }

  function callout(d, id, src) {
     var js, fjs = d.getElementsByTagName('script')[0];
     p=/^http:/.test(d.location)?'http':'https';
     if (d.getElementById(id)) {return;}
     js = d.createElement('script'); 
     js.id = id;
     js.src = p + src;
     fjs.parentNode.insertBefore(js, fjs);
  }

</script>
