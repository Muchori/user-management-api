-- schema.sql

-- Enable UUID extension for better distributed systems compatibility
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create enum for user roles
CREATE TYPE user_role AS ENUM ('admin', 'editor', 'author', 'user');

-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    role user_role NOT NULL DEFAULT 'user',
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT email_valid CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- Articles table
CREATE TABLE articles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    slug VARCHAR(255) NOT NULL UNIQUE,
    content TEXT NOT NULL,
    author_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    status VARCHAR(20) DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    published_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT title_length CHECK (char_length(title) >= 3)
);

-- Comments table
CREATE TABLE comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    article_id UUID NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    comment_text TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    parent_comment_id UUID REFERENCES comments(id) ON DELETE CASCADE,
    CONSTRAINT comment_length CHECK (char_length(comment_text) >= 1)
);

-- Tags table for article categorization
CREATE TABLE tags (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(50) NOT NULL UNIQUE,
    slug VARCHAR(50) NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Article-Tags junction table
CREATE TABLE article_tags (
    article_id UUID REFERENCES articles(id) ON DELETE CASCADE,
    tag_id UUID REFERENCES tags(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (article_id, tag_id)
);

-- Create indexes for better query performance
CREATE INDEX idx_articles_author_id ON articles(author_id);
CREATE INDEX idx_articles_created_at ON articles(created_at);
CREATE INDEX idx_articles_status ON articles(status);
CREATE INDEX idx_comments_article_id ON comments(article_id);
CREATE INDEX idx_comments_user_id ON comments(user_id);
CREATE INDEX idx_article_tags_tag_id ON article_tags(tag_id);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_articles_updated_at
    BEFORE UPDATE ON articles
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_comments_updated_at
    BEFORE UPDATE ON comments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Sample data insertion
INSERT INTO users (name, email, role, password_hash) VALUES
('John Admin', 'admin@example.com', 'admin', 'hashed_password_1'),
('Jane Editor', 'editor@example.com', 'editor', 'hashed_password_2'),
('Bob Author', 'author@example.com', 'author', 'hashed_password_3');

INSERT INTO articles (title, slug, content, author_id, status, published_at) VALUES
('First Article', 'first-article', 'Content of first article', (SELECT id FROM users WHERE email = 'author@example.com'), 'published', CURRENT_TIMESTAMP),
('Second Article', 'second-article', 'Content of second article', (SELECT id FROM users WHERE email = 'editor@example.com'), 'published', CURRENT_TIMESTAMP);

INSERT INTO comments (article_id, user_id, comment_text) VALUES
((SELECT id FROM articles WHERE slug = 'first-article'), 
 (SELECT id FROM users WHERE email = 'editor@example.com'),
 'Great article!');

-- Required queries

-- 1. Retrieve all articles with their authors
SELECT 
    a.id,
    a.title,
    a.content,
    a.created_at,
    a.updated_at,
    a.status,
    u.id as author_id,
    u.name as author_name,
    u.email as author_email
FROM articles a
JOIN users u ON a.author_id = u.id
WHERE a.status = 'published'
ORDER BY a.created_at DESC;

-- 2. Count the number of comments per article
SELECT 
    a.id as article_id,
    a.title,
    COUNT(c.id) as comment_count
FROM articles a
LEFT JOIN comments c ON a.id = c.article_id
GROUP BY a.id, a.title
ORDER BY comment_count DESC;

-- 3. Fetch the latest 5 articles
SELECT 
    a.id,
    a.title,
    a.content,
    a.created_at,
    u.name as author_name,
    (SELECT COUNT(*) FROM comments c WHERE c.article_id = a.id) as comment_count
FROM articles a
JOIN users u ON a.author_id = u.id
WHERE a.status = 'published'
ORDER BY a.created_at DESC
LIMIT 5;

-- Additional useful queries

-- Get articles with their tags
SELECT 
    a.id,
    a.title,
    STRING_AGG(t.name, ', ') as tags
FROM articles a
LEFT JOIN article_tags at ON a.id = at.article_id
LEFT JOIN tags t ON at.tag_id = t.id
GROUP BY a.id, a.title;

-- Get popular articles based on comment count
SELECT 
    a.id,
    a.title,
    COUNT(c.id) as comment_count
FROM articles a
LEFT JOIN comments c ON a.id = c.article_id
WHERE a.status = 'published'
GROUP BY a.id, a.title
HAVING COUNT(c.id) > 0
ORDER BY comment_count DESC
LIMIT 10;

-- Get user activity summary
SELECT 
    u.id,
    u.name,
    u.email,
    COUNT(DISTINCT a.id) as articles_written,
    COUNT(DISTINCT c.id) as comments_made
FROM users u
LEFT JOIN articles a ON u.id = a.author_id
LEFT JOIN comments c ON u.id = c.user_id
GROUP BY u.id, u.name, u.email;