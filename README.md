# CMS Database Setup

This repository contains a PostgreSQL schema and sample data for a basic Content Management System (CMS). It defines three tables:

- **users** (id, name, email, role)
- **articles** (id, title, content, author_id, created_at, updated_at)
- **comments** (id, article_id, user_id, comment_text, created_at)

It also includes example queries to retrieve articles with authors, count comments per article, and fetch the latest 5 articles.

## Prerequisites

- PostgreSQL installed locally **or** Docker with a PostgreSQL image.
- Access to a PostgreSQL database (e.g., `mydatabase`).
- A valid database user with privileges to create tables.

## Quick Start Using Docker

1. Run `docker pull postgres:13`.
2. Start a Postgres container, for example:
   ```
   docker run --name my-db -e POSTGRES_PASSWORD=password -p 5432:5432 -d postgres:13
   ```
3. (Optional) Create a dedicated database if desired:
   ```
   docker exec -it my-db psql -U postgres -c "CREATE DATABASE mydatabase;"
   ```
4. Copy or mount `schema.sql` into the container, then run:
   ```
   docker cp schema.sql my-db:/schema.sql
   docker exec -it my-db psql -U postgres -d mydatabase -f /schema.sql
   ```
5. Verify the tables:
   ```
   docker exec -it my-db psql -U postgres -d mydatabase
   \dt
   ```

## Quick Start Without Docker

1. Make sure PostgreSQL is running locally.
2. Create a database, for example:
   ```
   createdb mydatabase
   ```
3. Run the SQL script:
   ```
   psql -U <your_db_user> -d mydatabase -f schema.sql
   ```
4. To verify:
   ```
   psql -U <your_db_user> -d mydatabase
   \dt
   ```

## Example Queries

In `schema.sql`, there are some example queries (commented out at the bottom) that demonstrate how to:

- Retrieve all articles with their authors.
- Count the number of comments per article.
- Fetch the latest 5 articles.

To run them, just copy/paste in `psql`:

```sql
SELECT a.id, a.title, u.name AS author_name
FROM articles a
JOIN users u ON a.author_id = u.id;

SELECT a.title, COUNT(c.id) AS comment_count
FROM articles a
LEFT JOIN comments c ON a.id = c.article_id
GROUP BY a.id, a.title;

SELECT *
FROM articles
ORDER BY created_at DESC
LIMIT 5;
```

## Contact

If you have any questions or run into any issues, please open an issue in this repository.
