# postgres-age-vectorscale

A small Docker-based PostgreSQL bundle for Evane that includes useful database extensions in one image:

- PostgreSQL as the base database
- pgvector for vector embeddings and similarity search
- pgvectorscale for scaling vector search workloads
- Apache AGE for graph data and openCypher queries inside PostgreSQL

This enables Evane to work with relational data, vector search, and graph queries from a single PostgreSQL database image.

## Included projects

This project bundles and builds the following open-source projects:

- [PostgreSQL](https://www.postgresql.org/)
- [pgvector](https://github.com/pgvector/pgvector)
- [pgvectorscale](https://github.com/timescale/pgvectorscale)
- [Apache AGE](https://age.apache.org/)

Evane takes no credit for the work behind PostgreSQL, pgvector, pgvectorscale, or Apache AGE. All credit belongs to their respective authors, contributors, communities, and maintainers.

This repository is merely a convenience bundle of useful extensions for the purposes of Evane.

## Build

```sh
docker build -t evane/postgres-age-vectorscale .
```

## Run

```sh
docker run --name evane-postgres \
  -e POSTGRES_PASSWORD=postgres \
  -p 5432:5432 \
  evane/postgres-age-vectorscale
```

## Enable extensions

After connecting to PostgreSQL, enable the extensions you need:

```sql
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS vectorscale;
CREATE EXTENSION IF NOT EXISTS age;

LOAD 'age';
SET search_path = ag_catalog, "$user", public;
```

## License

This repository's own bundle code is licensed under the terms in [LICENSE.md](LICENSE.md).

The included projects remain under their own licenses. See each upstream project for its license terms.
