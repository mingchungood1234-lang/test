require('dotenv').config();
const express = require('express');
const http = require('http');
const path = require('path');
const cors = require('cors');
const pool = require('./db/connection');
const { Server } = require('socket.io');

const authRoutes = require('./routes/auth');

const app = express();
const server = http.createServer(app);
const PORT = process.env.PORT || 3000;

// Socket.IO signaling server
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
});

// Middleware
app.use(cors());
app.use(express.json());

// Serve the web client
app.use('/web', express.static(path.join(__dirname, 'web')));

// Routes
app.use('/api/auth', authRoutes);

// List all users (for contacts & web client)
app.get('/api/users', async (req, res) => {
  try {
    const [rows] = await pool.query(
      'SELECT id, name, email, phone, virtual_number FROM users ORDER BY name ASC LIMIT 100'
    );
    res.json({ users: rows });
  } catch (error) {
    console.error('Error fetching users:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Search users by virtual number or name
app.get('/api/users/search', async (req, res) => {
  try {
    const { q } = req.query;
    if (!q) return res.json({ users: [] });

    const searchTerm = `%${q}%`;
    const [rows] = await pool.query(
      `SELECT id, name, email, phone, virtual_number FROM users 
       WHERE name LIKE ? OR email LIKE ? OR virtual_number LIKE ?
       LIMIT 20`,
      [searchTerm, searchTerm, searchTerm]
    );
    res.json({ users: rows });
  } catch (error) {
    console.error('Error searching users:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', database: 'mysql', timestamp: new Date().toISOString() });
});

// Redirect root to web client
app.get('/', (req, res) => {
  res.redirect('/web');
});

// ========== WebRTC Signaling ==========

// Track connected users: userId -> { socketId, platform }
const connectedUsers = new Map();

io.on('connection', (socket) => {
  console.log('User connected:', socket.id);

  // Register user with their userId
  socket.on('register', (data) => {
    // Support both string and object formats
    const userId = typeof data === 'string' ? data : data.userId;
    const platform = typeof data === 'object' ? (data.platform || 'unknown') : 'unknown';

    connectedUsers.set(userId, { socketId: socket.id, platform });
    socket.data.userId = userId;
    socket.data.platform = platform;
    console.log(`User ${userId} registered (${platform}) with socket ${socket.id}`);

    // Broadcast updated online users list
    const onlineUserIds = Array.from(connectedUsers.keys());
    io.emit('online_users', onlineUserIds);
  });

  // Initiate a call
  socket.on('call_user', (data) => {
    const { callerId, callerName, targetId, callType } = data;
    const target = connectedUsers.get(targetId);

    if (target) {
      io.to(target.socketId).emit('incoming_call', {
        callerId,
        callerName,
        callType,
      });
      console.log(`Call from ${callerId} to ${targetId} (${target.platform})`);
    } else {
      socket.emit('call_rejected', {
        reason: 'User is offline',
      });
    }
  });

  // Accept call
  socket.on('accept_call', (data) => {
    const { callerId, targetId } = data;
    const caller = connectedUsers.get(callerId);

    if (caller) {
      io.to(caller.socketId).emit('call_accepted', { targetId });
      console.log(`Call accepted: ${targetId} accepted from ${callerId}`);
    }
  });

  // Reject call
  socket.on('reject_call', (data) => {
    const { callerId, targetId } = data;
    const caller = connectedUsers.get(callerId);

    if (caller) {
      io.to(caller.socketId).emit('call_rejected', { targetId });
      console.log(`Call rejected: ${targetId} rejected from ${callerId}`);
    }
  });

  // End call
  socket.on('end_call', (data) => {
    const { callerId, targetId } = data;
    const target = connectedUsers.get(targetId);
    const caller = connectedUsers.get(callerId);

    if (target) {
      io.to(target.socketId).emit('call_ended', { callerId });
    }
    if (caller) {
      io.to(caller.socketId).emit('call_ended', { targetId });
    }
    console.log(`Call ended between ${callerId} and ${targetId}`);
  });

  // Relay WebRTC signals (SDP, ICE candidates)
  socket.on('signal', (data) => {
    const { to, signal } = data;
    const target = connectedUsers.get(to);

    if (target) {
      io.to(target.socketId).emit('signal', {
        from: socket.data.userId,
        signal,
      });
    }
  });

  // Handle disconnect
  socket.on('disconnect', () => {
    const userId = socket.data.userId;
    if (userId) {
      connectedUsers.delete(userId);
      console.log(`User ${userId} disconnected`);

      // Broadcast updated online users list
      const onlineUserIds = Array.from(connectedUsers.keys());
      io.emit('online_users', onlineUserIds);
    }
  });
});

// Initialize MySQL and start server
async function start() {
  try {
    // Test database connection
    const conn = await pool.getConnection();
    console.log('Connected to MySQL');

    // Create tables if not exist
    await conn.query(`
      CREATE TABLE IF NOT EXISTS users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        email VARCHAR(255) NOT NULL UNIQUE,
        password VARCHAR(255) NOT NULL,
        phone VARCHAR(20),
        virtual_number VARCHAR(20) NOT NULL UNIQUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        INDEX idx_users_email (email),
        INDEX idx_users_virtual_number (virtual_number)
      )
    `);
    console.log('Users table ready');

    conn.release();

    server.listen(PORT, () => {
      console.log(`Server running on port ${PORT}`);
      console.log(`Web client: http://localhost:${PORT}/web`);
      console.log(`API: http://localhost:${PORT}/api`);
      console.log('Signaling server ready');
    });
  } catch (err) {
    console.error('MySQL connection error:', err.message);
    console.error('Make sure MySQL is running and check .env credentials');
    process.exit(1);
  }
}

start();

module.exports = { app, server, io };
