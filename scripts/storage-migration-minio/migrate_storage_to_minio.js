/**
 * Migrate Supabase Cloud Storage objects to MinIO (Pigsty).
 * One run = one source bucket → one target bucket.
 *
 * Env:
 *   OLD_PROJECT_URL, OLD_PROJECT_SERVICE_KEY - Supabase Cloud (source)
 *   MINIO_ENDPOINT (e.g. http://104.223.25.234:9000)
 *   MINIO_ACCESS_KEY, MINIO_SECRET_KEY - MinIO user for TARGET_BUCKET
 *   SOURCE_BUCKET - Supabase bucket name (e.g. assets, product-images)
 *   TARGET_BUCKET - MinIO bucket name (e.g. gd-lounge-assets, imperial-product-images)
 *
 * Example (GD-lounge assets):
 *   SOURCE_BUCKET=assets TARGET_BUCKET=gd-lounge-assets \
 *   MINIO_ACCESS_KEY=s3user_gdlounge MINIO_SECRET_KEY=GdLoungeStorage7xKp2mNqR \
 *   node migrate_storage_to_minio.js
 *
 * See docs/STORAGE-MIGRATION-SUPABASE-TO-MINIO.md for bucket mapping and .env.example.
 */
require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');
const { S3Client, PutObjectCommand, ListObjectsV2Command } = require('@aws-sdk/client-s3');

const OLD_PROJECT_URL = process.env.OLD_PROJECT_URL;
const OLD_PROJECT_SERVICE_KEY = process.env.OLD_PROJECT_SERVICE_KEY;
const MINIO_ENDPOINT = process.env.MINIO_ENDPOINT;
const MINIO_ACCESS_KEY = process.env.MINIO_ACCESS_KEY;
const MINIO_SECRET_KEY = process.env.MINIO_SECRET_KEY;
const SOURCE_BUCKET = process.env.SOURCE_BUCKET;
const TARGET_BUCKET = process.env.TARGET_BUCKET;
const BATCH_SIZE = parseInt(process.env.BATCH_SIZE || '500', 10);

function checkEnv() {
  const missing = [];
  if (!OLD_PROJECT_URL) missing.push('OLD_PROJECT_URL');
  if (!OLD_PROJECT_SERVICE_KEY) missing.push('OLD_PROJECT_SERVICE_KEY');
  if (!MINIO_ENDPOINT) missing.push('MINIO_ENDPOINT');
  if (!MINIO_ACCESS_KEY) missing.push('MINIO_ACCESS_KEY');
  if (!MINIO_SECRET_KEY) missing.push('MINIO_SECRET_KEY');
  if (!SOURCE_BUCKET) missing.push('SOURCE_BUCKET');
  if (!TARGET_BUCKET) missing.push('TARGET_BUCKET');
  if (missing.length) {
    console.error('Missing env:', missing.join(', '));
    process.exit(1);
  }
}

const supabase = createClient(OLD_PROJECT_URL, OLD_PROJECT_SERVICE_KEY);

const s3 = new S3Client({
  region: 'us-east-1',
  endpoint: MINIO_ENDPOINT,
  forcePathStyle: true,
  credentials: {
    accessKeyId: MINIO_ACCESS_KEY,
    secretAccessKey: MINIO_SECRET_KEY,
  },
});

/** List all file paths in the bucket recursively via Storage API (no storage schema needed). */
async function listAllSourcePaths(prefix = '') {
  const { data, error } = await supabase.storage.from(SOURCE_BUCKET).list(prefix || '', { limit: 1000 });
  if (error) throw error;
  const paths = [];
  for (const item of data || []) {
    const fullPath = prefix ? `${prefix}/${item.name}` : item.name;
    if (item.id == null && item.metadata == null) {
      const nested = await listAllSourcePaths(fullPath);
      paths.push(...nested);
    } else {
      paths.push({ name: fullPath, metadata: item.metadata || {} });
    }
  }
  return paths;
}

async function downloadFromSupabase(name) {
  const { data, error } = await supabase.storage.from(SOURCE_BUCKET).download(name);
  if (error) throw error;
  return data;
}

async function uploadToMinio(name, body, contentType) {
  await s3.send(
    new PutObjectCommand({
      Bucket: TARGET_BUCKET,
      Key: name,
      Body: Buffer.from(await body.arrayBuffer()),
      ContentType: contentType || 'application/octet-stream',
    })
  );
}

async function countMinioObjects() {
  let count = 0;
  let token;
  do {
    const out = await s3.send(
      new ListObjectsV2Command({
        Bucket: TARGET_BUCKET,
        MaxKeys: 1000,
        ContinuationToken: token,
      })
    );
    count += (out.Contents || []).length;
    token = out.NextContinuationToken;
  } while (token);
  return count;
}

function formatProgress(current, total, path) {
  const pct = total ? Math.round((current / total) * 100) : 0;
  const short = path.length > 60 ? '...' + path.slice(-57) : path;
  return `[${current}/${total}] (${pct}%) ${short}`;
}

async function migrate() {
  checkEnv();
  console.log(`\n--- ${SOURCE_BUCKET} → ${TARGET_BUCKET} ---`);
  console.log('Listing source...');

  const objects = await listAllSourcePaths();
  const totalFiles = objects.length;
  console.log(`Source: ${totalFiles} files to copy.\n`);

  let totalMoved = 0;
  let totalErrors = 0;
  const errors = [];

  for (let i = 0; i < objects.length; i++) {
    const obj = objects[i];
    const num = i + 1;
    try {
      const fileData = await downloadFromSupabase(obj.name);
      const contentType = obj.metadata?.mimetype || 'application/octet-stream';
      await uploadToMinio(obj.name, fileData, contentType);
      totalMoved++;
      if (num % 10 === 0 || num === totalFiles) {
        console.log(formatProgress(num, totalFiles, obj.name));
      } else if (num % 5 === 0) {
        process.stdout.write('.');
      }
    } catch (err) {
      totalErrors++;
      errors.push({ name: obj.name, message: err.message });
      console.log(`\n  FAIL [${num}/${totalFiles}] ${obj.name}: ${err.message}`);
    }
  }

  if (totalFiles > 0 && totalFiles % 5 !== 0 && totalErrors === 0) process.stdout.write('\n');

  console.log(`\nCopy: ${totalMoved} ok, ${totalErrors} errors.`);
  if (errors.length > 0) {
    console.log('Failed files:');
    errors.forEach((e) => console.log('  -', e.name, ':', e.message));
  }

  console.log('Verifying MinIO...');
  const minioCount = await countMinioObjects();
  const ok = minioCount === totalFiles && totalErrors === 0;
  if (ok) {
    console.log(`VERIFICATION OK: source=${totalFiles} minio=${minioCount}`);
  } else {
    console.log(`VERIFICATION MISMATCH: source=${totalFiles} copied=${totalMoved} errors=${totalErrors} minio=${minioCount}`);
  }
  console.log(`--- end ${SOURCE_BUCKET} ---\n`);
}

migrate().catch((e) => {
  console.error(e);
  process.exit(1);
});
