const pool = require('../db/connection');

class User {
  /**
   * Generate a unique virtual phone number: +1-555-XXXX format
   */
  static async generateVirtualNumber() {
    let attempts = 0;
    while (attempts < 100) {
      // Generate: +1-555-XXXX where XXXX is random
      const lastFour = String(Math.floor(1000 + Math.random() * 9000));
      const virtualNumber = `+1-555-${lastFour}`;

      const [existing] = await pool.query(
        'SELECT id FROM users WHERE virtual_number = ?',
        [virtualNumber]
      );

      if (existing.length === 0) {
        return virtualNumber;
      }
      attempts++;
    }
    throw new Error('Could not generate unique virtual number');
  }

  /**
   * Create a new user
   */
  static async create({ name, email, password, phone }) {
    const virtualNumber = await this.generateVirtualNumber();

    const [result] = await pool.query(
      'INSERT INTO users (name, email, password, phone, virtual_number) VALUES (?, ?, ?, ?, ?)',
      [name, email, password, phone || null, virtualNumber]
    );

    return this.findById(result.insertId);
  }

  /**
   * Find user by ID (without password)
   */
  static async findById(id) {
    const [rows] = await pool.query(
      'SELECT id, name, email, phone, virtual_number, created_at FROM users WHERE id = ?',
      [id]
    );
    return rows[0] || null;
  }

  /**
   * Find user by email (with password for auth)
   */
  static async findByEmail(email) {
    const [rows] = await pool.query(
      'SELECT id, name, email, password, phone, virtual_number FROM users WHERE email = ?',
      [email]
    );
    return rows[0] || null;
  }

  /**
   * Find user by virtual number
   */
  static async findByVirtualNumber(virtualNumber) {
    const [rows] = await pool.query(
      'SELECT id, name, email, phone, virtual_number FROM users WHERE virtual_number = ?',
      [virtualNumber]
    );
    return rows[0] || null;
  }

  /**
   * Search users by name, email, or virtual number
   */
  static async search(query) {
    const searchTerm = `%${query}%`;
    const [rows] = await pool.query(
      `SELECT id, name, email, phone, virtual_number FROM users 
       WHERE name LIKE ? OR email LIKE ? OR virtual_number LIKE ?
       LIMIT 20`,
      [searchTerm, searchTerm, searchTerm]
    );
    return rows;
  }

  /**
   * Get all users (for contact list)
   */
  static async findAll(limit = 50) {
    const [rows] = await pool.query(
      'SELECT id, name, email, phone, virtual_number FROM users ORDER BY name ASC LIMIT ?',
      [limit]
    );
    return rows;
  }
}

module.exports = User;
