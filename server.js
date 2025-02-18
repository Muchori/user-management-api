const express = require('express')
const bodyParser = require('body-parser')
const jwt = require('jsonwebtoken')
const { Pool } = require('pg')
const app = express()
app.use(bodyParser.json())

const pool = new Pool({
  connectionString:
    process.env.DATABASE_URL ||
    'postgresql://postgres:password@db:5432/mydatabase',
})

function authenticate(req, res, next) {
  const authHeader = req.headers['authorization']
  if (!authHeader) return res.status(401).json({ error: 'No token provided' })
  const token = authHeader.split(' ')[1]
  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET || 'secret')
    next()
  } catch (e) {
    res.status(401).json({ error: 'Invalid token' })
  }
}

app.post('/users', authenticate, async (req, res) => {
  const { name, email, role } = req.body
  try {
    const result = await pool.query(
      'INSERT INTO users(name,email,role) VALUES($1,$2,$3) RETURNING id,name,email,role',
      [name, email, role],
    )
    res.status(201).json(result.rows[0])
  } catch (e) {
    res.status(400).json({ error: e.message })
  }
})

app.get('/users/:id', authenticate, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id,name,email,role FROM users WHERE id=$1',
      [req.params.id],
    )
    if (result.rows.length < 1)
      return res.status(404).json({ error: 'User not found' })
    res.json(result.rows[0])
  } catch (e) {
    res.status(400).json({ error: e.message })
  }
})

app.put('/users/:id', authenticate, async (req, res) => {
  const { name, email, role } = req.body
  try {
    const result = await pool.query(
      'UPDATE users SET name=$1,email=$2,role=$3 WHERE id=$4 RETURNING id,name,email,role',
      [name, email, role, req.params.id],
    )
    if (result.rows.length < 1)
      return res.status(404).json({ error: 'User not found' })
    res.json(result.rows[0])
  } catch (e) {
    res.status(400).json({ error: e.message })
  }
})

app.delete('/users/:id', authenticate, async (req, res) => {
  try {
    const result = await pool.query(
      'DELETE FROM users WHERE id=$1 RETURNING id',
      [req.params.id],
    )
    if (result.rows.length < 1)
      return res.status(404).json({ error: 'User not found' })
    res.json({ message: 'User deleted' })
  } catch (e) {
    res.status(400).json({ error: e.message })
  }
})

const port = process.env.PORT || 3000
app.listen(port, () => console.log(`Running on port ${port}`))
