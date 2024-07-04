# HTTP API

```@raw html
<div style="display: flex; justify-content: flex-end; margin-bottom: 20px; margin-top: -52px; margin-right: 0px;">
   <input type="text" class="input" style="width: 250px" id="base-url-input" placeholder="http://" value="http://0.0.0.0:4584" />
   <button id="load-schema-button">Set</button>
</div>

<style>
  .swagger-ui .information-container {
    display: none !important;
  }
  
  .swagger-ui .scheme-container {
    display: none !important;
  }

  .swagger-ui #operations-tag-default {
    display: none !important;
  }

</style>

<div id="swagger-ui"></div>
<script>

var pathArray = window.location.pathname.split('/');
pathArray.pop();
pathArray.pop();
pathArray.push('assets', 'schema.json');
const schemaURL = pathArray.join('/');
console.log(schemaURL);

function loadSchema(baseURL) {

    fetch(schemaURL)
        .then(response => response.json())
        .then(schema => {
            // Modify the servers array in the schema to set the base URL
            schema.servers = [
                {
                    url: baseURL  // Base URL for API requests
                }
            ];

            // Initialize Swagger UI
            window.ui = SwaggerUIBundle({
                spec: schema,
                dom_id: '#swagger-ui',
            });
        })
        .catch(error => console.error("Error loading schema:", error));
}

window.onload = () => {
    const customBaseURL = document.getElementById('base-url-input').value;
    loadSchema(customBaseURL);
};

document.getElementById('load-schema-button').addEventListener('click', () => {

    // Get the custom base URL from the input field
    const customBaseURL = document.getElementById('base-url-input').value;

    if (!customBaseURL) {
        alert("Please enter a valid base URL.");
        return;
    }
    // Load schema with the custom base URL
    loadSchema(customBaseURL);
});

</script>
```
