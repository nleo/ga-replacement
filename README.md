# Replace GA with JS

Replacement for Google Analytics with CoffeeScript, ClickHouse and ExpressJS

Create tables:

    clickhouse-client < create_table_pings.sql
    clickhouse-client < create_table_visits.sql

Compile:

    coffee -w -o public/analytics.js -c analytics.coffee
    coffee -w -c server.coffee

Run:

    nodemon server.js

Include JS script to your page:

```html
<% if current_user.present? %>
  <script type="module">
    import {Analytics} from 'http://localhost:3334/analytics.js';
    if (gon.user){
      let content_id;
      if (gon.place === 'content')
        content_id = 1
      else
        content_id = 2

      let analytics = new Analytics('http://localhost:3334/reports', gon.user.id, content_id)
    }
  </script>
<% end %>
```
