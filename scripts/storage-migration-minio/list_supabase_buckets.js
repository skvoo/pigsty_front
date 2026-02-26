/**
 * List file counts in Supabase Storage buckets (to check if source has files).
 * Usage: OLD_PROJECT_URL=https://REF.supabase.co OLD_PROJECT_SERVICE_KEY=... BUCKETS=furniture-images,site-images node list_supabase_buckets.js
 */
const { createClient } = require('@supabase/supabase-js');

const OLD_PROJECT_URL = process.env.OLD_PROJECT_URL;
const OLD_PROJECT_SERVICE_KEY = process.env.OLD_PROJECT_SERVICE_KEY;
const BUCKETS = (process.env.BUCKETS || process.env.SOURCE_BUCKET || '').split(',').map((b) => b.trim()).filter(Boolean);

if (!OLD_PROJECT_URL || !OLD_PROJECT_SERVICE_KEY) {
  console.error('Set OLD_PROJECT_URL and OLD_PROJECT_SERVICE_KEY');
  process.exit(1);
}
if (BUCKETS.length === 0) {
  console.error('Set BUCKETS=name1,name2 or SOURCE_BUCKET=name');
  process.exit(1);
}

const supabase = createClient(OLD_PROJECT_URL, OLD_PROJECT_SERVICE_KEY);

async function listAllPaths(bucket, prefix = '') {
  const { data, error } = await supabase.storage.from(bucket).list(prefix || '', { limit: 1000 });
  if (error) throw error;
  const paths = [];
  for (const item of data || []) {
    const fullPath = prefix ? `${prefix}/${item.name}` : item.name;
    if (item.id == null && item.metadata == null) {
      const nested = await listAllPaths(bucket, fullPath);
      paths.push(...nested);
    } else {
      paths.push(fullPath);
    }
  }
  return paths;
}

async function main() {
  for (const bucket of BUCKETS) {
    try {
      const paths = await listAllPaths(bucket);
      console.log(`${bucket}: ${paths.length} files`);
      if (paths.length > 0 && paths.length <= 10) console.log('  ', paths.join(', '));
      else if (paths.length > 10) console.log('  ', paths.slice(0, 5).join(', '), '...');
    } catch (e) {
      console.log(`${bucket}: error - ${e.message}`);
    }
  }
}

main().catch(console.error);
