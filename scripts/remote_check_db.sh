#!/bin/bash
sudo -u postgres psql -d postgres -t -c "SELECT datname FROM pg_database WHERE datname IN ('gdloungedb','imperialdb','postgres','meta') ORDER BY 1;"
