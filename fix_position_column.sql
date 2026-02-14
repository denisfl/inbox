-- Fix position column to allow NULL and remove default

PRAGMA foreign_keys = OFF;

-- Create new table with correct schema
CREATE TABLE blocks_new (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  document_id INTEGER NOT NULL,
  block_type VARCHAR NOT NULL,
  position INTEGER,  -- NULL allowed, no default
  content TEXT,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL,
  FOREIGN KEY (document_id) REFERENCES documents(id)
);

-- Copy all data
INSERT INTO blocks_new SELECT * FROM blocks;

-- Drop old table
DROP TABLE blocks;

-- Rename new table
ALTER TABLE blocks_new RENAME TO blocks;

-- Recreate index
CREATE INDEX index_blocks_on_document_id_and_position ON blocks(document_id, position);
CREATE INDEX index_blocks_on_document_id ON blocks(document_id);

PRAGMA foreign_keys = ON;
