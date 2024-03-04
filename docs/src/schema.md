# HTTP API

```@raw html

<style>
  .swagger-ui .information-container {
    display: none !important;
  }

  .swagger-ui #operations-tag-default {
    display: none !important;
  }

</style>


<div id="swagger-ui"></div>
<script>

  window.onload = () => {

    var pathArray = window.location.pathname.split('/');
    pathArray.pop();
    pathArray.pop();
    pathArray.push('assets', 'schema.json');
    var relativePath = pathArray.join('/');
    console.log(relativePath);

      window.ui = SwaggerUIBundle({
          url: relativePath,
          dom_id: '#swagger-ui',
      });
  };
</script>
```
