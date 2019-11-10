express = require('express')
cors = require('cors');
app = express()
port = 3334

app.use(cors())
app.use(express.json());
app.use(express.static('public'))

app.get '/', (req, res) =>
  res.send 'Hellod World!'

app.post '/reports', (req, res) =>
  console.log req.body
  res.send 'Hellod World!'

app.listen port, () =>
  console.log "Example app listening on port #{port}!"
