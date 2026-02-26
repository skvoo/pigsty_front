/**
 * Exact verification: compare object counts in Supabase (source) vs MinIO (target) for all migration buckets.
 * Run after run_storage_migration.ps1. Reads same env (or set OLD_PROJECT_URL, OLD_PROJECT_SERVICE_KEY per project).
 *
 * Usage from repo root (env from supabase-credentials.env):
 *   Set env vars for both projects and MINIO_*, then: node scripts/storage-migration-minio/verify_storage_migration.js
 * Or run verify_run.ps1 which loads env and calls this.
 */
require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');
const { S3Client, ListObjectsV2Command } = require('@aws-sdk/client-s3');

const MINIO_ENDPOINT = process.env.MINIO_ENDPOINT || 'http://104.223.25.234:9000';

const jobs = [
  {
    name: 'GD-lounge assets',
    projectUrl: process.env.SUPABASE_GDLOUNGE_URL || (process.env.SUPABASE_GDLOUNGE_REF ? `https://${process.env.SUPABASE_GDLOUNGE_REF}.supabase.co` : null),
    serviceKey: process.env.SUPABASE_GDLOUNGE_SERVICE_KEY,
    sourceBucket: 'assets',
    targetBucket: 'gd-lounge-assets',
    accessKey: 's3user_gdlounge',
    secretKey: 'GdLoungeStorage7xKp2mNqR',
  },
  {
    name: 'imperial event-images',
    projectUrl: process.env.SUPABASE_IMPERIAL_URL || (process.env.SUPABASE_IMPERIAL_REF ? `https://${process.env.SUPABASE_IMPERIAL_REF}.supabase.co` : null),
    serviceKey: process.env.SUPABASE_IMPERIAL_SERVICE_KEY,
    sourceBucket: 'event-images',
    targetBucket: 'imperial-event-images',
    accessKey: 's3user_imperial_ev',
    secretKey: 'ImperialStorage7xKp2mNqR',
  },
  {
    name: 'imperial furniture-images',
    projectUrl: process.env.SUPABASE_IMPERIAL_URL || (process.env.SUPABASE_IMPERIAL_REF ? `https://${process.env.SUPABASE_IMPERIAL_REF}.supabase.co` : null),
    serviceKey: process.env.SUPABASE_IMPERIAL_SERVICE_KEY,
    sourceBucket: 'furniture-images',
    targetBucket: 'imperial-furniture-images',
    accessKey: 's3user_imperial_fu',
    secretKey: 'ImperialStorage7xKp2mNqR',
  },
  {
    name: 'imperial news-images',
    projectUrl: process.env.SUPABASE_IMPERIAL_URL || (process.env.SUPABASE_IMPERIAL_REF ? `https://${process.env.SUPABASE_IMPERIAL_REF}.supabase.co` : null),
    serviceKey: process.env.SUPABASE_IMPERIAL_SERVICE_KEY,
    sourceBucket: 'news-images',
    targetBucket: 'imperial-news-images',
    accessKey: 's3user_imperial_nw',
    secretKey: 'ImperialStorage7xKp2mNqR',
  },
  {
    name: 'imperial product-images',
    projectUrl: process.env.SUPABASE_IMPERIAL_URL || (process.env.SUPABASE_IMPERIAL_REF ? `https://${process.env.SUPABASE_IMPERIAL_REF}.supabase.co` : null),
    serviceKey: process.env.SUPABASE_IMPERIAL_SERVICE_KEY,
    sourceBucket: 'product-images',
    targetBucket: 'imperial-product-images',
    accessKey: 's3user_imperial_pr',
    secretKey: 'ImperialStorage7xKp2mNqR',
  },
  {
    name: 'imperial site-images',
    projectUrl: process.env.SUPABASE_IMPERIAL_URL || (process.env.SUPABASE_IMPERIAL_REF ? `https://${process.env.SUPABASE_IMPERIAL_REF}.supabase.co` : null),
    serviceKey: process.env.SUPABASE_IMPERIAL_SERVICE_KEY,
    sourceBucket: 'site-images',
    targetBucket: 'imperial-site-images',
    accessKey: 's3user_imperial_si',
    secretKey: 'ImperialStorage7xKp2mNqR',
  },
];

async function listAllPaths(supabase, bucket, prefix = '') {
  const { data, error } = await supabase.storage.from(bucket).list(prefix || '', { limit: 1000 });
  if (error) throw error;
  let count = 0;
  for (const item of data || []) {
    const fullPath = prefix ? `${prefix}/${item.name}` : item.name;
    if (item.id == null && item.metadata == null) {
      count += await listAllPaths(supabase, bucket, fullPath);
    } else {
      count++;
    }
  }
  return count;
}

async function countMinio(s3, bucket) {
  let count = 0;
  let token;
  do {
    const out = await s3.send(
      new ListObjectsV2Command({ Bucket: bucket, MaxKeys: 1000, ContinuationToken: token })
    );
    count += (out.Contents || []).length;
    token = out.NextContinuationToken;
  } while (token);
  return count;
}

function pad(s, n) {
  return String(s).padEnd(n);
}

async function main() {
  console.log('\n=== Storage migration verification (Supabase vs MinIO) ===\n');

  const rows = [];
  let allOk = true;

  for (const job of jobs) {
    let sourceCount = null;
    let minioCount = null;
    let err = null;

    if (job.projectUrl && job.serviceKey) {
      try {
        const supabase = createClient(job.projectUrl, job.serviceKey);
        sourceCount = await listAllPaths(supabase, job.sourceBucket);
      } catch (e) {
        err = e.message;
      }
    } else {
      err = 'missing URL or service key';
    }

    try {
      const s3 = new S3Client({
        region: 'us-east-1',
        endpoint: MINIO_ENDPOINT,
        forcePathStyle: true,
        credentials: { accessKeyId: job.accessKey, secretAccessKey: job.secretKey },
      });
      minioCount = await countMinio(s3, job.targetBucket);
    } catch (e) {
      if (!err) err = e.message;
    }

    const match = sourceCount !== null && minioCount !== null && sourceCount === minioCount;
    if (!match && err === null) allOk = false;
    if (err) allOk = false;

    rows.push({
      name: job.name,
      source: sourceCount,
      minio: minioCount,
      status: err || (match ? 'OK' : 'MISMATCH'),
    });
  }

  const w = 28;
  console.log(pad('Bucket', w) + pad('Supabase', 10) + pad('MinIO', 10) + 'Status');
  console.log('-'.repeat(w + 10 + 10 + 20));
  for (const r of rows) {
    const src = r.source != null ? r.source : '-';
    const min = r.minio != null ? r.minio : '-';
    console.log(pad(r.name, w) + pad(src, 10) + pad(min, 10) + r.status);
  }

  console.log('\n' + (allOk ? 'VERIFICATION PASSED: all buckets match.' : 'VERIFICATION FAILED: see mismatches above.') + '\n');
  process.exit(allOk ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
