# Replace GA with JS

Replacement for Google Analytics with CoffeeScript, ClickHouse and ExpressJS

Create tables:

    awk '{print $0"\0"}' RS= create_tables.sql  | xargs -0 -n1 clickhouse-client


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
      let pageTypeId;
      if (gon.place === 'content')
        pageTypeId = 1
      else
        pageTypeId = 2

      let analytics = new Analytics('http://localhost:3334', gon.user.id, pageTypeId)
    }
  </script>
<% end %>
```

## Get user statistics

```
GET /time_spend/:user_id/:from/:to/:type

/time_spend/2/2019-01-01 00:00:00/2019-12-31 23:59:59/2
```

Returns time in seconds: `{"time":0}`
