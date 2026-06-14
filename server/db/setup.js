/**
 * Database setup script
 * Run: node db/setup.js
 * This will create the 'phonecall' database and users table
 */
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const mysql = require('mysql2/promise');

async function setup() {
  const connection = await mysql.createConnection({
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '3306'),
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
  });

  console.log('Connected to MySQL');

  // Create database
  await connection.query(`CREATE DATABASE IF NOT EXISTS ${process.env.DB_NAME || 'phonecall'}`);
  console.log('Database "phonecall" created/verified');

  // Use the database
  await connection.query(`USE ${process.env.DB_NAME || 'phonecall'}`);

  // Create users table
  await connection.query(`
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
  console.log('Users table created/verified');

  await connection.end();
  console.log('Setup complete!');
}

setup().catch((err) => {
  console.error('Setup failed:', err.message);
  console.error('Make sure MySQL is running and check your .env credentials');
  process.exit(1);
});
